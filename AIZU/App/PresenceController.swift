import Foundation
import Observation
import UIKit

@MainActor @Observable
final class PresenceController {
    static let shared = PresenceController(runtime: AudioConnectionRuntime(), forceLiveMode: true, launcher: SystemActivityLauncher())
    private(set) var state: PresenceState
    private(set) var delivery: DeliveryState = .idle
    private(set) var errorMessage: String?
    private(set) var storageHealthy = true
    private(set) var isBusy = false
    private(set) var isBackgrounded = false
    private let launcher: (any ActivityLauncher)?
    private var launchGeneration: UInt64 = 0
    private(set) var launchingAppID: UUID?
    let runtime: any ConnectionRuntime
    let auth: DiscordAuth
    private let repository: any StateRepository
    private let realTransport: any PresenceTransport
    private let previewTransport: any PresenceTransport
    private var worker: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var recoveryFailures = 0
    private var requestedRevision: UInt64 = 0
    private var lease: UIBackgroundTaskIdentifier = .invalid

    init(repository: (any StateRepository)? = nil, transport: (any PresenceTransport)? = nil,
         previewTransport: (any PresenceTransport)? = nil, auth: DiscordAuth? = nil,
         runtime: (any ConnectionRuntime)? = nil, forceLiveMode: Bool = false,
         launcher: (any ActivityLauncher)? = nil) {
        let auth = auth ?? DiscordAuth()
        self.launcher = launcher
        self.runtime = runtime ?? InactiveConnectionRuntime()
        self.auth = auth
        self.repository = repository ?? FileStateRepository()
        self.realTransport = transport ?? DiscordTransport(auth: auth)
        self.previewTransport = previewTransport ?? PreviewTransport()
        do {
            var loaded = try self.repository.load()
            let oldLogCount = loaded.logs.count
            loaded.logs.removeAll { $0.message == "백그라운드 전환 · Discord 표시 유지 여부 미확인" }
            if loaded.logs.count != oldLogCount { try self.repository.save(loaded) }
            if forceLiveMode && loaded.previewMode {
                loaded.previewMode = false
                try self.repository.save(loaded)
            }
            // A persisted session cannot establish that a game is still in the foreground.
            if loaded.session != nil {
                loaded.session = nil
                loaded.generation &+= 1
                loaded.log("앱 재시작 · 이전 세션 자동 재개 안 함")
                try self.repository.save(loaded)
            }
            self.state = loaded
        } catch {
            self.state = PresenceState()
            self.storageHealthy = false
            self.errorMessage = "저장 데이터를 열 수 없습니다. 원본은 보존됩니다. \(error.localizedDescription)"
        }
        self.runtime.onChange = { [weak self] in
            guard let self else { return }
            if !self.runtime.running && self.isBackgrounded && self.state.session != nil { self.delivery = .unverified }
            self.scheduleRecovery()
        }
    }

    var currentApp: PresenceApp? { state.currentApp }
    var canConfigureTransport: Bool { !isBusy && state.session == nil && !state.needsRemoteClear }

    @discardableResult
    private func commit(_ change: (inout PresenceState) -> Void) -> Bool {
        guard storageHealthy else { return false }
        var next = state
        change(&next)
        do {
            try repository.save(next); state = next
            return true
        }
        catch { errorMessage = "변경을 저장하지 못했습니다. \(error.localizedDescription)"; return false }
    }

    func setSharing(_ enabled: Bool) {
        guard commit({ $0.setSharing(enabled) }) else { return }
        requestSync()
    }
    func start(_ appID: UUID, fromAutomation: Bool = false) {
        let oldGeneration = state.generation
        guard commit({ $0.openApp(appID, fromAutomation: fromAutomation) }) else { return }
        if oldGeneration != state.generation || (state.needsRemoteClear && state.session == nil) || (state.desiredActivity != nil && !runtime.running) { requestSync() }
    }
    /// Only direct UI actions launch another app. Automation and reconnect never call this.
    func shareAndLaunch(_ appID: UUID) async {
        guard let application = state.apps.first(where: { $0.id == appID }),
              state.sharingEnabled, application.enabled, storageHealthy else { return }
        launchGeneration &+= 1
        let generation = launchGeneration
        launchingAppID = appID
        defer { if launchGeneration == generation { launchingAppID = nil } }
        let destination: URL?
        do { destination = try ActivityLaunch.destination(method: application.launchMethod, value: application.launchValue) }
        catch { errorMessage = error.localizedDescription; return }
        start(appID)
        let sessionID = state.session?.id
        await waitForSync()
        guard !Task.isCancelled, generation == launchGeneration, !isBackgrounded,
              state.session?.id == sessionID, state.session?.appID == appID,
              state.sharingEnabled, !state.previewMode, delivery == .submitted,
              state.currentApp?.launchMethod == application.launchMethod,
              state.currentApp?.launchValue == application.launchValue,
              let destination, let launcher else { return }
        let opened = await launcher.open(destination)
        guard generation == launchGeneration, state.session?.id == sessionID else { return }
        if !opened {
            errorMessage = "공유는 시작됐지만 앱을 열지 못했습니다. 설치 여부와 활동 설정의 실행 URL 또는 단축어 이름을 확인해 주세요."
        }
    }

    func close(_ appID: UUID) {
        let oldGeneration = state.generation
        guard commit({ $0.closeApp(appID) }) else { return }
        if oldGeneration != state.generation || (state.needsRemoteClear && state.session == nil) { requestSync() }
    }
    func stop() {
        guard commit({ $0.stop() }) else { return }
        requestSync()
    }
    @discardableResult
    func saveApp(_ application: PresenceApp) -> Bool {
        let previous = state.generation
        guard commit({ $0.saveApp(application) }) else { return false }
        if state.generation != previous { requestSync() }
        return true
    }
    func removeApp(_ id: UUID) {
        let previous = state.generation
        guard commit({ $0.removeApp(id) }) else { return }
        if state.generation != previous { requestSync() }
    }
    func setPreviewMode(_ enabled: Bool) {
        guard canConfigureTransport else {
            errorMessage = "현재 활동을 종료하고 이전 활동 해제를 처리한 뒤 모드를 변경해 주세요."
            return
        }
        realTransport.disconnect()
        previewTransport.disconnect()
        guard commit({ $0.previewMode = enabled; $0.generation &+= 1 }) else { return }
        runtime.stop()
        delivery = .idle
    }
    func dismissError() { errorMessage = nil }
    func clearLogs() { commit { $0.logs = [] } }

    func requestSync() {
        recoveryTask?.cancel()
        recoveryTask = nil
        requestedRevision &+= 1
        beginLease()
        if state.desiredActivity != nil && !state.previewMode { runtime.start() }
        else { runtime.stop() }
        guard worker == nil else { return }
        isBusy = true
        worker = Task { [weak self] in await self?.drain() }
    }

    // A single writer serializes side effects. OFF arriving during a publish always
    // runs clear after that publish, rather than merely dropping its completion.
    private func drain() async {
        while !Task.isCancelled {
            let revision = requestedRevision
            let activity = state.desiredActivity
            let isPreview = state.previewMode
            let transport = isPreview ? previewTransport : realTransport
            delivery = .sending
            do {
                if let activity {
                    try await transport.prepare()
                    try Task.checkCancellation()
                    if revision != requestedRevision { continue }
                    if !isPreview {
                        guard commit({ $0.needsRemoteClear = true }) else {
                            throw PresenceFailure.message("상태를 저장하지 못해 전송하지 않았습니다.")
                        }
                    }
                    try await transport.publish(activity)
                    try Task.checkCancellation()
                    if revision == requestedRevision {
                        recoveryFailures = 0
                        delivery = isPreview ? .preview : (isBackgrounded ? .unverified : .submitted)
                    }
                } else {
                    if isPreview || state.needsRemoteClear {
                        try await transport.clear()
                        if !isPreview { commit { $0.needsRemoteClear = false } }
                        delivery = isPreview ? .idle : .clearRequested
                    } else { delivery = .idle }
                    transport.disconnect()
                }
            } catch {
                if Task.isCancelled { delivery = .unverified }
                else if revision == requestedRevision {
                    recoveryFailures = min(recoveryFailures + 1, 4)
                    delivery = .failed(error.localizedDescription)
                    commit { $0.log(error.localizedDescription) }
                }
                transport.disconnect()
                if !isPreview && !auth.isLinked { runtime.stop() }
            }
            if revision == requestedRevision { break }
        }
        worker = nil
        isBusy = false
        endLease()
        scheduleRecovery()
    }

    func waitForSync() async { while let worker { await worker.value } }

    func enteredBackground() {
        isBackgrounded = true
        recoveryTask?.cancel()
        recoveryTask = nil
        if state.session != nil && !state.previewMode {
            delivery = .unverified
        }
        scheduleRecovery()
    }
    func enteredForeground() {
        isBackgrounded = false
        // Only an in-memory session may resume; init still discards persisted sessions.
        if state.desiredActivity != nil || state.needsRemoteClear { requestSync() }
    }

    private var mayCheckConnection: Bool { !isBackgrounded || runtime.running }

    func checkConnectionHealth() {
        guard mayCheckConnection, !isBusy, !state.previewMode else { return }
        guard state.desiredActivity != nil || state.needsRemoteClear else { return }
        if let issue = realTransport.connectionIssue {
            delivery = .unverified
            commit { $0.log(issue) }
            requestSync()
        } else {
            scheduleRecovery()
        }
    }

    private func scheduleRecovery() {
        recoveryTask?.cancel()
        recoveryTask = nil
        guard mayCheckConnection, !state.previewMode,
              state.desiredActivity != nil || state.needsRemoteClear else { return }
        // Audio runtime may allow background checks; the timer itself grants no execution time.
        // This local status check sends no heartbeat requests when healthy.
        let seconds = min(300, 30 * (1 << recoveryFailures))
        recoveryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.checkConnectionHealth()
        }
    }

    private func beginLease() {
        guard lease == .invalid else { return }
        lease = UIApplication.shared.beginBackgroundTask(withName: "FinishPresenceUpdate") { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.worker?.cancel()
                self.realTransport.disconnect()
                self.delivery = .unverified
                self.endLease()
            }
        }
    }
    private func endLease() {
        guard lease != .invalid else { return }
        UIApplication.shared.endBackgroundTask(lease)
        lease = .invalid
    }
}
