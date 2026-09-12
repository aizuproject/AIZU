import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, korean = "ko", english = "en", japanese = "ja", chinese = "zh-Hans"
    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .system: "기기 설정 따르기"
        case .korean: "한국어"
        case .english: "English"
        case .japanese: "日本語"
        case .chinese: "简体中文"
        }
    }
}

enum Localization {
    static let preferenceKey = "aizu.language"
    static let supported = ["en", "ko", "ja", "zh-Hans"]

    static func resolve(override: String?, preferred: [String]) -> String {
        if let override, supported.contains(override) { return override }
        for tag in preferred {
            let language = tag.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").first
            switch language {
            case "ko": return "ko"
            case "ja": return "ja"
            case "zh": return "zh-Hans"
            case "en": return "en"
            default: continue
            }
        }
        return "en"
    }

    static var currentCode: String {
        resolve(override: UserDefaults.standard.string(forKey: preferenceKey), preferred: Locale.preferredLanguages)
    }

    static func defaultStorefront(region: String? = Locale.current.region?.identifier) -> String {
        switch region?.uppercased() {
        case "KR": "kr"
        case "JP": "jp"
        case "CN": "cn"
        default: "us"
        }
    }

    private static let tables: [String: [String: String]] = {
        Dictionary(uniqueKeysWithValues: supported.map { code in
            guard let url = Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: code),
                  let data = try? Data(contentsOf: url),
                  let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
                return (code, [:])
            }
            return (code, table)
        })
    }()

    private static let patterns: [(String, NSRegularExpression)] = {
        (tables["ko"] ?? [:]).keys.filter { $0.contains("%@") || $0.contains("%d") }.sorted { $0.count > $1.count }.compactMap { key in
            let escaped = NSRegularExpression.escapedPattern(for: key)
            let pattern = "^" + escaped.replacingOccurrences(of: "%@", with: "(.*?)")
                .replacingOccurrences(of: "%d", with: "(-?[0-9]+)") + "$"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return nil }
            return (key, regex)
        }
    }()

    /// Used only for app-authored UI and diagnostics, never names/descriptions entered by the user.
    static func text(_ key: String, language: String? = nil) -> String {
        let code = language ?? currentCode
        if let exact = tables[code]?[key] { return exact }
        if code == "ko" { return key }
        let range = NSRange(key.startIndex..., in: key)
        for (template, regex) in patterns {
            guard let match = regex.firstMatch(in: key, range: range), let translated = tables[code]?[template] else { continue }
            var values: [String] = []
            for index in 1..<match.numberOfRanges {
                guard let captureRange = Range(match.range(at: index), in: key) else { continue }
                let value = String(key[captureRange])
                // Only the SDK diagnostic prefix is another app-authored key; activity names remain verbatim.
                values.append(template == "%@ · 유형 %d / HTTP %d / 코드 %d" && index == 1
                    ? tables[code]?[value] ?? value : value)
            }
            let slots = translated.components(separatedBy: "%@").flatMap { $0.components(separatedBy: "%d") }
            guard slots.count == values.count + 1 else { return key }
            return zip(slots.dropLast(), values).map { $0 + $1 }.joined() + (slots.last ?? "")
        }
        return key
    }
}

func L(_ key: String) -> String { Localization.text(key) }
