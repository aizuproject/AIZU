import Foundation

@MainActor
final class DiscordTransport: PresenceTransport {
    var connectionIssue: String? { bridge.connectionIssue }
    let auth: DiscordAuth
    private let bridge = DiscordBridge()
    private var connectionGeneration: UInt64 = 0
    init(auth: DiscordAuth) { self.auth = auth }
    func prepare() async throws {
        guard DiscordBridge.available else {
            throw PresenceFailure.message("Discord Social SDK 파일이 필요합니다. 설정의 연결 준비 안내를 확인해 주세요.")
        }
        let generation = connectionGeneration
        let token = try await auth.accessToken()
        try Task.checkCancellation()
        guard generation == connectionGeneration else { throw CancellationError() }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            bridge.connect(token: token) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }
    func publish(_ activity: ActivityPayload) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            bridge.publish(name: activity.name, details: activity.details, activityType: activity.kind.rawValue,
                           startedAt: activity.startedAt.map { UInt64(max(0, $0.timeIntervalSince1970 * 1000)) } ?? 0,
                           largeImage: activity.imageURL?.absoluteString) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }
    func clear() async throws {
        try await prepare()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            bridge.clear { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }
    func disconnect() { connectionGeneration &+= 1; bridge.disconnect() }
}
