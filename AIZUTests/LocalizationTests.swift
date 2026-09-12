import XCTest
@testable import AIZU

final class LocalizationTests: XCTestCase {
    func testPreferredLanguageOrderAndOverride() {
        XCTAssertEqual(Localization.resolve(override: "system", preferred: ["fr-FR", "ja-JP", "en"]), "ja")
        XCTAssertEqual(Localization.resolve(override: nil, preferred: ["ko-KR", "en-US"]), "ko")
        XCTAssertEqual(Localization.resolve(override: nil, preferred: ["en-KR", "ko"]), "en")
        XCTAssertEqual(Localization.resolve(override: nil, preferred: ["zh-Hant-TW"]), "zh-Hans")
        XCTAssertEqual(Localization.resolve(override: "ko", preferred: ["en-US"]), "ko")
        XCTAssertEqual(Localization.resolve(override: "invalid", preferred: ["de-DE"]), "en")
        XCTAssertEqual(Localization.resolve(override: nil, preferred: []), "en")
    }

    func testStorefrontUsesRegionIndependentlyOfLanguage() {
        XCTAssertEqual(Localization.defaultStorefront(region: "KR"), "kr")
        XCTAssertEqual(Localization.defaultStorefront(region: "JP"), "jp")
        XCTAssertEqual(Localization.defaultStorefront(region: "CN"), "cn")
        XCTAssertEqual(Localization.defaultStorefront(region: "FR"), "us")
    }

    func testBundledTranslationsAndSafeDiagnosticInterpolation() {
        XCTAssertEqual(Localization.text("설정", language: "en"), "Settings")
        XCTAssertEqual(Localization.text("설정", language: "ja"), "設定")
        XCTAssertEqual(Localization.text("설정", language: "zh-Hans"), "设置")
        XCTAssertEqual(Localization.text("설정", language: "ko"), "설정")
        XCTAssertEqual(Localization.text("12개 앱", language: "en"), "12 apps")
        XCTAssertEqual(Localization.text("ADB %@ %d 세션 시작", language: "en"), "ADB %@ %d activity started")
        XCTAssertEqual(Localization.text("SDK · 유형 2 / HTTP 401 / 코드 9", language: "en"), "SDK · type 2 / HTTP 401 / code 9")
        XCTAssertEqual(Localization.text("Discord 활동 게시 실패 · 유형 2 / HTTP 401 / 코드 9", language: "en"), "Couldn't publish the Discord activity · type 2 / HTTP 401 / code 9")
        XCTAssertEqual(Localization.text("User-entered content", language: "ja"), "User-entered content")
    }

    func testEveryLanguageContainsTheSameKeysAndFormatSlots() throws {
        var tables: [String: [String: String]] = [:]
        for code in Localization.supported {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: code))
            tables[code] = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
        }
        let base = try XCTUnwrap(tables["ko"])
        XCTAssertGreaterThan(base.count, 200)
        let regex = try NSRegularExpression(pattern: "%[@d]|\\$\\{[^}]+\\}")
        func slots(_ value: String) -> [String] {
            regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).compactMap { Range($0.range, in: value).map { String(value[$0]) } }.sorted()
        }
        for (code, table) in tables {
            XCTAssertEqual(Set(base.keys), Set(table.keys), code)
            for (key, value) in table {
                XCTAssertFalse(value.isEmpty, "\(code): \(key)")
                XCTAssertEqual(slots(key), slots(value), "\(code): \(key)")
            }
        }
    }
}
