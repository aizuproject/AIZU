import AppIntents
import Foundation

// Keep intent/entity type and parameter identifiers for existing Shortcuts.
struct GameEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "등록한 앱")
    static let defaultQuery = GameQuery()
    let id: UUID
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct GameQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [GameEntity] {
        await MainActor.run {
            PresenceController.shared.state.apps.filter { identifiers.contains($0.id) }.map { GameEntity(id: $0.id, name: $0.name) }
        }
    }
    func entities(matching string: String) async throws -> [GameEntity] {
        await MainActor.run {
            PresenceController.shared.state.apps.filter { $0.name.localizedCaseInsensitiveContains(string) }
                .map { GameEntity(id: $0.id, name: $0.name) }
        }
    }
    func suggestedEntities() async throws -> [GameEntity] {
        await MainActor.run { PresenceController.shared.state.apps.map { GameEntity(id: $0.id, name: $0.name) } }
    }
}

struct StartGamePresenceIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "앱 활동 시작"
    static let description = IntentDescription("선택한 앱의 활동을 공유합니다. 전체 공유가 꺼져 있으면 게시하지 않습니다.")
    static var openAppWhenRun: Bool { false }
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @available(iOS 27.0, *) static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Parameter(title: "앱") var game: GameEntity
    static var parameterSummary: some ParameterSummary { Summary("\(\.$game) 활동 시작") }
    @MainActor func perform() async throws -> some IntentResult {
        let controller = PresenceController.shared
        guard controller.state.apps.contains(where: { $0.id == game.id }) else {
            throw intentFailure("등록이 해제된 앱입니다. 자동화에서 앱을 다시 선택해 주세요.")
        }
        controller.start(game.id, fromAutomation: true)
        await controller.waitForSync()
        if let error = controller.errorMessage { throw intentFailure(error) }
        if case .failed(let message) = controller.delivery { throw intentFailure(message) }
        if controller.state.desiredActivity != nil && !controller.state.previewMode && !controller.runtime.running {
            throw intentFailure("활동은 전송했지만 연결 유지를 시작하지 못했습니다. AIZU를 열고 다시 시도해 주세요.")
        }
        return .result()
    }
}

struct StopGamePresenceIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "앱 활동 종료"
    static let description = IntentDescription("해당 앱의 현재 활동을 종료합니다. 다른 앱의 활동은 유지합니다.")
    static var openAppWhenRun: Bool { false }
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @available(iOS 27.0, *) static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Parameter(title: "앱") var game: GameEntity
    static var parameterSummary: some ParameterSummary { Summary("\(\.$game) 활동 종료") }
    @MainActor func perform() async throws -> some IntentResult {
        let controller = PresenceController.shared
        controller.close(game.id)
        await controller.waitForSync()
        if let error = controller.errorMessage { throw intentFailure(error) }
        if case .failed(let message) = controller.delivery { throw intentFailure(message) }
        return .result()
    }
}

struct SetPresenceSharingIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "앱 활동 공유 설정"
    static let description = IntentDescription("공유를 켜거나 끕니다. 끄면 진행 중인 활동도 종료합니다.")
    static var openAppWhenRun: Bool { false }
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @available(iOS 27.0, *) static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Parameter(title: "공유 켜기") var enabled: Bool
    static var parameterSummary: some ParameterSummary { Summary("앱 활동 공유 \(\.$enabled)") }
    @MainActor func perform() async throws -> some IntentResult {
        let controller = PresenceController.shared
        controller.setSharing(enabled)
        await controller.waitForSync()
        if let error = controller.errorMessage { throw intentFailure(error) }
        if case .failed(let message) = controller.delivery { throw intentFailure(message) }
        return .result()
    }
}

struct StopCurrentPresenceIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "현재 활동 종료"
    static var openAppWhenRun: Bool { false }
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @available(iOS 27.0, *) static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @MainActor func perform() async throws -> some IntentResult {
        let controller = PresenceController.shared
        controller.stop()
        await controller.waitForSync()
        if let error = controller.errorMessage { throw intentFailure(error) }
        if case .failed(let message) = controller.delivery { throw intentFailure(message) }
        return .result()
    }
}

struct PresenceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartGamePresenceIntent(), phrases: ["\(.applicationName)에서 \(\.$game) 활동 시작"],
                    shortTitle: "앱 활동 시작", systemImageName: "play.circle")
        AppShortcut(intent: StopGamePresenceIntent(), phrases: ["\(.applicationName)에서 \(\.$game) 활동 종료"],
                    shortTitle: "앱 활동 종료", systemImageName: "stop.circle")
        AppShortcut(intent: SetPresenceSharingIntent(), phrases: ["\(.applicationName) 공유 설정"],
                    shortTitle: "공유 켜기·끄기", systemImageName: "power")
        AppShortcut(intent: StopCurrentPresenceIntent(), phrases: ["\(.applicationName) 현재 활동 종료"],
                    shortTitle: "현재 활동 종료", systemImageName: "pause.circle")
    }
}

// Shortcuts runs outside AIZU's UI, so its errors follow the device language too.
private func intentFailure(_ message: String) -> PresenceFailure {
    .message(Localization.text(message, language: Localization.resolve(override: nil, preferred: Locale.preferredLanguages)))
}
