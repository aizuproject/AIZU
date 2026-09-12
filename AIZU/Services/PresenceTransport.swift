import Foundation

@MainActor
protocol PresenceTransport: AnyObject {
    var connectionIssue: String? { get }
    func prepare() async throws
    func publish(_ activity: ActivityPayload) async throws
    func clear() async throws
    func disconnect()
}

extension PresenceTransport {
    var connectionIssue: String? { nil }
    func prepare() async throws {}
}

@MainActor
final class PreviewTransport: PresenceTransport {
    private(set) var current: ActivityPayload?
    func publish(_ activity: ActivityPayload) async throws { current = activity }
    func clear() async throws { current = nil }
    func disconnect() { current = nil }
}

enum DeliveryState: Equatable {
    case idle, sending, preview, submitted, clearRequested, needsSetup, unverified, failed(String)
    var title: String {
        switch self {
        case .idle: "대기 중"
        case .sending: "반영 중"
        case .preview: "미리보기"
        case .submitted: "Discord에 전송됨"
        case .clearRequested: "활동 해제 요청됨"
        case .needsSetup: "Discord 연결 필요"
        case .unverified: "유지 여부 미확인"
        case .failed: "다시 확인 필요"
        }
    }
}
