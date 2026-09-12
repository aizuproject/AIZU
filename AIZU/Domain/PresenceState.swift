import Foundation

enum PresenceActivityKind: Int, CaseIterable, Identifiable, Sendable {
    case standard = 0, listening = 2, watching = 3
    var id: Int { rawValue }
    var title: String {
        switch self { case .standard: "기본 활동"; case .listening: "청취 중"; case .watching: "시청 중" }
    }
}

struct PresenceApp: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var developer: String = "직접 등록"
    var appStoreID: Int64?
    var storefront: String = "kr"
    var artworkURL: URL?
    var localArtwork: Data?
    var storeURL: URL?
    var enabled: Bool = true
    var details: String = "앱 사용 중"
    // Optional storage keeps existing v1 entries readable. Unknown future values use the default.
    var activityType: Int?
    var activityKind: PresenceActivityKind {
        get { PresenceActivityKind(rawValue: activityType ?? 0) ?? .standard }
        set { activityType = newValue.rawValue }
    }
    var showElapsedTime: Bool = true
    var launchMethod: String?
    var launchValue: String?
    var opensAfterSharing: Bool { launchMethod != nil && launchMethod != LaunchMethod.none.rawValue }
    var lastOpened: Date?
    var lastClosed: Date?

    static let examples = [PresenceApp(name: "Photoshop", developer: "Adobe", details: "이미지 편집 중"),
                           PresenceApp(name: "Instagram", developer: "Instagram", details: "앱 사용 중"),
                           PresenceApp(name: "YouTube", developer: "Google", details: "영상 시청 중", activityType: 3)]
}

struct PresenceSession: Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var appID: UUID
    var startedAt: Date
    enum CodingKeys: String, CodingKey { case id, appID = "gameID", startedAt }
}

struct ActivityPayload: Equatable, Sendable {
    let name: String
    let details: String
    let startedAt: Date?
    let imageURL: URL?
    var kind: PresenceActivityKind = .standard
}

struct EventLog: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var date: Date
    var message: String
}

struct PresenceState: Codable, Equatable, Sendable {
    // Keep on-disk v1 keys and UUIDs so existing libraries and Shortcuts entities still resolve.
    enum CodingKeys: String, CodingKey {
        case schemaVersion, apps = "games", sharingEnabled, previewMode, session, generation, needsRemoteClear, logs
    }
    var schemaVersion = 1
    var apps: [PresenceApp] = []
    var sharingEnabled = false
    var previewMode = false
    var session: PresenceSession?
    var generation: UInt64 = 0
    // Persist before every real publish, so a failed clear survives process termination.
    var needsRemoteClear = false
    var logs: [EventLog] = []

    var currentApp: PresenceApp? { apps.first { $0.id == session?.appID } }
    var desiredActivity: ActivityPayload? {
        guard sharingEnabled, let session, let game = currentApp, game.enabled else { return nil }
        return ActivityPayload(name: game.name, details: game.details.count >= 2 ? game.details : "",
                               startedAt: game.showElapsedTime ? session.startedAt : nil,
                               imageURL: game.artworkURL, kind: game.activityKind)
    }

    mutating func log(_ message: String, at date: Date = .now) {
        logs.insert(EventLog(date: date, message: message), at: 0)
        if logs.count > 80 { logs.removeLast(logs.count - 80) }
    }

    mutating func setSharing(_ enabled: Bool, at date: Date = .now) {
        guard sharingEnabled != enabled else { return }
        sharingEnabled = enabled
        session = nil // Enabling never resurrects an old game.
        generation &+= 1
        log(enabled ? "공유 켜짐 · 앱 선택 대기" : "공유 꺼짐 · 활동 종료 요청", at: date)
    }

    mutating func openApp(_ id: UUID, at date: Date = .now, fromAutomation: Bool = true) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        if fromAutomation { apps[index].lastOpened = date }
        guard sharingEnabled, apps[index].enabled else {
            log("\(apps[index].name) 열림 · 공유 꺼짐으로 건너뜀", at: date)
            return
        }
        guard session?.appID != id else {
            log("\(apps[index].name) 다시 열림 · 시작 시각 유지", at: date)
            return
        }
        session = PresenceSession(appID: id, startedAt: date)
        generation &+= 1
        log("\(apps[index].name) 세션 시작", at: date)
    }

    mutating func closeApp(_ id: UUID, at date: Date = .now) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        apps[index].lastClosed = date
        guard session?.appID == id else {
            log("\(apps[index].name) 닫힘 · 현재 세션에 영향 없음", at: date)
            return
        }
        stop(at: date)
    }

    mutating func stop(at date: Date = .now) {
        session = nil
        generation &+= 1
        log("현재 활동 종료", at: date)
    }

    mutating func saveApp(_ input: PresenceApp) {
        var game = input
        game.name = String(game.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(128))
        game.details = String(game.details.prefix(128))
        guard !game.name.isEmpty else { return }
        if let index = apps.firstIndex(where: { $0.id == game.id }) { apps[index] = game }
        else { apps.append(game) }
        if session?.appID == game.id {
            if !game.enabled { session = nil }
            generation &+= 1
        }
    }

    mutating func removeApp(_ id: UUID) {
        if session?.appID == id { stop() }
        apps.removeAll { $0.id == id }
    }
}

enum PresenceFailure: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}
