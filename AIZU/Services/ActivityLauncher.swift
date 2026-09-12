import Foundation
import UIKit

enum LaunchMethod: String, CaseIterable, Identifiable {
    case none, appURL, shortcut
    var id: String { rawValue }
    var title: String {
        switch self { case .none: "공유만 시작"; case .appURL: "앱 URL 열기"; case .shortcut: "단축어 실행" }
    }
}

enum ActivityLaunch {
    static func destination(method: String?, value: String?) throws -> URL? {
        guard let raw = method, raw != LaunchMethod.none.rawValue else { return nil }
        guard let method = LaunchMethod(rawValue: raw) else {
            throw PresenceFailure.message("지원하지 않는 실행 방법입니다. 활동 설정에서 다시 선택해 주세요.")
        }
        let text = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 2048 else {
            throw PresenceFailure.message("실행할 앱 URL 또는 단축어 이름을 입력해 주세요.")
        }
        if method == .shortcut {
            var parts = URLComponents()
            parts.scheme = "shortcuts"; parts.host = "run-shortcut"
            parts.queryItems = [URLQueryItem(name: "name", value: text)]
            return parts.url
        }
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              !["file", "data", "javascript", "vbscript", "http", "shortcuts"].contains(scheme),
              !scheme.hasPrefix("discord-"),
              url.user == nil, url.password == nil,
              !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw PresenceFailure.message("앱의 실행 URL 또는 HTTPS 링크를 입력해 주세요. 단축어는 ‘단축어 실행’을 선택하세요.")
        }
        if scheme == "https", url.host?.isEmpty != false {
            throw PresenceFailure.message("올바른 HTTPS 링크를 입력해 주세요.")
        }
        return url
    }
}

@MainActor
protocol ActivityLauncher {
    func open(_ url: URL) async -> Bool
}

@MainActor
struct SystemActivityLauncher: ActivityLauncher {
    func open(_ url: URL) async -> Bool {
        guard UIApplication.shared.applicationState == .active else { return false }
        // Direct open supports user-configured schemes without installation enumeration.
        return await UIApplication.shared.open(url, options: [:])
    }
}
