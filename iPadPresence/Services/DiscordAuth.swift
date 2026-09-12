import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security
import UIKit

struct OAuthTokens: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let applicationID: String
}

struct OAuthResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
}

enum OAuthPKCE {
    static func randomString() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw PresenceFailure.message("로그인 보안 코드를 생성하지 못했습니다.")
        }
        return Data(bytes).base64URL
    }
    static func challenge(for verifier: String) -> String { Data(SHA256.hash(data: Data(verifier.utf8))).base64URL }
    static func validateCallback(_ url: URL, expectedState: String, scheme: String) throws -> String {
        guard url.scheme == scheme, url.path == "/authorize/callback",
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.queryItems?.filter({ $0.name == "state" }).count == 1,
              parts.queryItems?.first(where: { $0.name == "state" })?.value == expectedState else {
            throw PresenceFailure.message("로그인 응답을 확인할 수 없습니다. 다시 연결해 주세요.")
        }
        // Only expose known error categories; never echo callback URLs or descriptions.
        if let error = parts.queryItems?.first(where: { $0.name == "error" })?.value {
            let message: String
            switch error {
            case "access_denied": message = "Discord 계정 연결이 승인되지 않았습니다. 승인 화면의 권한 안내를 확인해 주세요."
            case "invalid_scope": message = "Discord가 활동 공유 권한을 허용하지 않았습니다. Developer Portal에서 이 앱의 Social SDK 등록 상태를 확인해 주세요."
            case "unauthorized_client", "invalid_client": message = "Discord 앱의 인증 설정을 확인해야 합니다. Developer Portal의 OAuth2에서 Public Client를 켜고 저장해 주세요."
            case "invalid_request", "unsupported_response_type": message = "Discord가 로그인 요청을 거절했습니다. 앱의 Redirect URI와 OAuth 설정을 확인해 주세요."
            case "server_error", "temporarily_unavailable": message = "Discord 인증 서버에 일시적인 문제가 있습니다. 잠시 후 다시 연결해 주세요."
            default: message = "Discord가 계정 연결을 승인하지 않았습니다. 개발자 포털의 OAuth2·Social SDK 설정을 확인해 주세요."
            }
            throw PresenceFailure.message(message)
        }
        guard parts.queryItems?.filter({ $0.name == "code" }).count == 1,
              let code = parts.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw PresenceFailure.message("Discord가 승인 코드를 반환하지 않았습니다. 다시 연결해 주세요.")
        }
        return code
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

enum TokenKeychain {
    private static let service = "app.aizuproject.aizu.oauth"
    private static func query(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    private static func failure(_ status: OSStatus) -> PresenceFailure {
        switch status {
        case errSecMissingEntitlement:
            .message("앱의 Keychain 저장 권한이 누락되었습니다. 정상 서명된 빌드로 다시 설치해야 합니다. (\(status))")
        case errSecInteractionNotAllowed:
            .message("기기를 잠금 해제한 뒤 Discord 연결을 다시 시도해 주세요. (\(status))")
        default:
            .message("로그인 정보를 Keychain에서 처리하지 못했습니다. 오류 코드: \(status)")
        }
    }
    static func read(account: String = "discord") throws -> OAuthTokens? {
        var query = query(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw failure(status) }
        guard let data = result as? Data else { throw failure(errSecDecode) }
        return try JSONDecoder().decode(OAuthTokens.self, from: data)
    }
    static func write(_ tokens: OAuthTokens, account: String = "discord") throws {
        let data = try JSONEncoder().encode(tokens)
        let query = query(account: account)
        let changes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw failure(status) }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecSuccess else { throw failure(added) }
    }
    static func delete(account: String = "discord") throws {
        let status = SecItemDelete(query(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw failure(status) }
    }
    // Check the same storage policy before asking the user to complete OAuth.
    // The probe uses its own disposable item and never overwrites account tokens.
    static func verifyStorage() throws {
        let account = "storage-probe.\(UUID().uuidString)"
        let probe = OAuthTokens(accessToken: "storage-probe", refreshToken: "storage-probe",
                                expiresAt: Date(timeIntervalSince1970: 0), applicationID: "0")
        defer { try? delete(account: account) }
        try write(probe, account: account)
        guard try read(account: account) == probe else { throw failure(errSecDecode) }
    }
}

@MainActor @Observable
final class DiscordAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    let applicationID: String
    private(set) var isLinked = false
    private(set) var isAuthorizing = false
    private(set) var errorMessage: String?
    private var webSession: ASWebAuthenticationSession?
    private var refreshing: Task<OAuthTokens, Error>?
    var isConfigured: Bool { UInt64(applicationID).map { $0 > 0 } ?? false }
    var redirectURI: String { "discord-\(applicationID):/authorize/callback" }

    override init() {
        self.applicationID = Bundle.main.object(forInfoDictionaryKey: "DiscordApplicationID") as? String ?? "0"
        super.init()
        if let tokens = try? TokenKeychain.read() { isLinked = tokens.applicationID == applicationID }
    }

    #if DEBUG
    /// Documentation and UI tests must never load a saved account.
    init(preview: Bool) {
        self.applicationID = "0"
        super.init()
    }
    #endif

    func login() async {
        guard !isAuthorizing else { return }
        guard isConfigured else { errorMessage = "Discord Application ID를 빌드 설정에 추가해 주세요."; return }
        isAuthorizing = true
        errorMessage = nil
        defer { isAuthorizing = false; webSession = nil }
        do {
            try TokenKeychain.verifyStorage()
            let verifier = try OAuthPKCE.randomString()
            let state = try OAuthPKCE.randomString()
            var url = URLComponents(string: "https://discord.com/oauth2/authorize")!
            url.queryItems = [
                URLQueryItem(name: "client_id", value: applicationID),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "scope", value: "openid sdk.social_layer_presence"),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "code_challenge", value: OAuthPKCE.challenge(for: verifier)),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ]
            let callback = try await authorize(url.url!)
            let code = try OAuthPKCE.validateCallback(callback, expectedState: state, scheme: "discord-\(applicationID)")
            let response = try await exchange(["grant_type": "authorization_code", "code": code,
                                               "redirect_uri": redirectURI, "code_verifier": verifier])
            guard let refresh = response.refresh_token else { throw PresenceFailure.message("갱신용 로그인 정보가 없습니다. 다시 연결해 주세요.") }
            let tokens = OAuthTokens(accessToken: response.access_token, refreshToken: refresh,
                                     expiresAt: .now.addingTimeInterval(Double(response.expires_in)), applicationID: applicationID)
            try TokenKeychain.write(tokens)
            isLinked = true
        } catch { errorMessage = error.localizedDescription }
    }

    func accessToken() async throws -> String {
        guard isConfigured, let tokens = try TokenKeychain.read(), tokens.applicationID == applicationID else {
            throw PresenceFailure.message("설정에서 Discord 계정을 먼저 연결해 주세요.")
        }
        if tokens.expiresAt.timeIntervalSinceNow > 60 { return tokens.accessToken }
        if let refreshing { return try await refreshing.value.accessToken }
        let task = Task<OAuthTokens, Error> {
            let response = try await exchange(["grant_type": "refresh_token", "refresh_token": tokens.refreshToken])
            let updated = OAuthTokens(accessToken: response.access_token, refreshToken: response.refresh_token ?? tokens.refreshToken,
                                      expiresAt: .now.addingTimeInterval(Double(response.expires_in)), applicationID: applicationID)
            try TokenKeychain.write(updated)
            return updated
        }
        refreshing = task
        defer { refreshing = nil }
        do { return try await task.value.accessToken }
        catch { errorMessage = "Discord 로그인을 갱신하지 못했습니다. 연결을 확인해 주세요."; throw error }
    }

    func unlink() {
        guard !isAuthorizing, refreshing == nil else { return }
        do { try TokenKeychain.delete(); isLinked = false; errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    private func authorize(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "discord-\(applicationID)") { url, error in
                if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: error ?? PresenceFailure.message("로그인이 취소되었습니다.")) }
            }
            session.presentationContextProvider = self
            self.webSession = session
            if !session.start() { continuation.resume(throwing: PresenceFailure.message("로그인 창을 열 수 없습니다.")) }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) { return keyWindow }
        guard let scene = scenes.first else { preconditionFailure("OAuth requires an active window scene") }
        return ASPresentationAnchor(windowScene: scene)
    }

    private func exchange(_ fields: [String: String]) async throws -> OAuthResponse {
        var fields = fields
        fields["client_id"] = applicationID
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let body = fields.sorted { $0.key < $1.key }.map {
            "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&")
        var request = URLRequest(url: URL(string: "https://discord.com/api/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            // Never include the response body, authorization code or tokens in logs.
            throw PresenceFailure.message("Discord 인증에 실패했습니다. Public Client·Redirect·Social SDK 설정을 확인해 주세요.")
        }
        return try JSONDecoder().decode(OAuthResponse.self, from: data)
    }
}
