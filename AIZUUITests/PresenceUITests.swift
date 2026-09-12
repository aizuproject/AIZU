import XCTest

final class PresenceUITests: XCTestCase {
    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-language", "ko", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        return app
    }

    @MainActor
    private func navigate(_ app: XCUIApplication, id: String, title: String) throws {
        let tab = app.tabBars.buttons[title]
        if tab.exists { tab.tap(); return }
        let item = app.descendants(matching: .any).matching(identifier: "nav.\(id)")
        XCTAssertTrue(item.firstMatch.waitForExistence(timeout: 5))
        try XCTUnwrap(item.allElementsBoundByIndex.first(where: \.isHittable)).tap()
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    @MainActor
    func testLibrarySearchAndClear() throws {
        let app = launch()
        try navigate(app, id: "library", title: "앱")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap()
        for character in "instagram" { search.typeText(String(character)) }
        XCTAssertTrue(app.buttons["edit.Instagram"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["edit.Photoshop"].exists)
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "instagram".count))
        XCTAssertTrue(app.buttons["edit.Photoshop"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRuntimeHelpWithoutExperiments() throws {
        let app = launch()
        try navigate(app, id: "settings", title: "설정")
        XCTAssertFalse(app.buttons["audioExperiment"].exists)
        XCTAssertFalse(app.buttons["continuedSyncExperiment"].exists)
        app.buttons["runtimeHelp"].tap()
        let notice = app.staticTexts["guidedAccessHelp"]
        for _ in 0..<4 {
            if notice.exists && notice.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(notice.exists)
        XCTAssertFalse(app.buttons["startScreenDetection"].exists)
        capture(app, name: "Background limits")
    }

    @MainActor
    func testSharingStartStopAndNoAutomaticResume() throws {
        let app = launch()
        let sharing = app.switches["sharingToggle"]
        XCTAssertTrue(sharing.waitForExistence(timeout: 10))
        sharing.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let start = app.buttons["start.Photoshop"]
        XCTAssertTrue(start.isEnabled)
        start.tap()
        XCTAssertTrue(app.buttons["stopCurrent"].waitForExistence(timeout: 5))
        capture(app, name: "Active presence")
        sharing.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertFalse(app.buttons["stopCurrent"].exists)
        sharing.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertFalse(app.buttons["stopCurrent"].exists)
        capture(app, name: "Activity")
    }

    @MainActor
    func testAddManualApplication() throws {
        let app = launch()
        let add = app.buttons["addApp"]
        XCTAssertTrue(add.waitForExistence(timeout: 10)); add.tap()
        XCTAssertFalse(app.staticTexts["빠른 검색"].exists)
        XCTAssertFalse(app.buttons["Photoshop"].exists)
        app.segmentedControls.buttons["직접 입력"].tap()
        let field = app.textFields["manualAppName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.placeholderValue, "앱 또는 작업 이름")
        XCTAssertEqual(app.textFields["manualAppDetails"].placeholderValue, "하고 있는 일")
        field.tap()
        for character in "adb" { field.typeText(String(character)) }
        XCTAssertEqual(field.value as? String, "adb")
        let details = app.textFields["manualAppDetails"]
        details.tap(); details.typeText("ADB debugging")
        XCTAssertTrue(app.buttons["chooseArtworkPhoto"].exists)
        XCTAssertTrue(app.buttons["chooseArtworkFile"].exists)
        app.swipeUp()
        app.buttons["saveManualApp"].tap()
        XCTAssertTrue(app.buttons["start.adb"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testShortcutLaunchConfigurationPersists() throws {
        let app = launch()
        try navigate(app, id: "library", title: "앱")
        app.buttons["edit.YouTube"].tap()
        let picker = app.descendants(matching: .any).matching(identifier: "launchMethod")
        for _ in 0..<3 {
            if picker.allElementsBoundByIndex.contains(where: \.isHittable) { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.49)))
        }
        try XCTUnwrap(picker.allElementsBoundByIndex.first(where: \.isHittable)).tap()
        app.buttons["단축어 실행"].tap()
        let fields = app.descendants(matching: .any).matching(identifier: "launchValue")
        for _ in 0..<3 {
            if fields.allElementsBoundByIndex.contains(where: \.isHittable) { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.49)))
        }
        let field = try XCTUnwrap(fields.allElementsBoundByIndex.first(where: \.isHittable))
        field.tap(); field.typeText("Open YouTube")
        app.buttons["saveAppSettings"].tap()
        app.buttons["edit.YouTube"].tap()
        let savedFields = app.descendants(matching: .any).matching(identifier: "launchValue")
        for _ in 0..<3 {
            if savedFields.allElementsBoundByIndex.contains(where: \.isHittable) { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.49)))
        }
        let saved = try XCTUnwrap(savedFields.allElementsBoundByIndex.first(where: \.isHittable))
        XCTAssertEqual(saved.value as? String, "Open YouTube")
        capture(app, name: "Share and launch settings")
    }

    @MainActor
    func testActivityTypeCanBeEdited() throws {
        let app = launch()
        try navigate(app, id: "library", title: "앱")
        app.buttons["edit.YouTube"].tap()
        let kind = app.descendants(matching: .any).matching(identifier: "activityKind")
        try XCTUnwrap(kind.allElementsBoundByIndex.first(where: \.isHittable)).tap()
        app.buttons["청취 중"].tap()
        app.buttons["saveAppSettings"].tap()
        XCTAssertTrue(app.staticTexts["청취 중"].waitForExistence(timeout: 5))
        capture(app, name: "Applications")
    }
}

@MainActor
final class LanguageUITests: XCTestCase {
    private func navigate(_ app: XCUIApplication, id: String, title: String) throws {
        let tab = app.tabBars.buttons[title]
        if tab.exists { tab.tap(); return }
        let items = app.descendants(matching: .any).matching(identifier: "nav.\(id)")
        try XCTUnwrap(items.allElementsBoundByIndex.first(where: \.isHittable)).tap()
    }

    func testLanguageSwitchPersistsAndKeepsActivity() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-language", "system", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let sharing = app.switches["sharingToggle"]
        XCTAssertTrue(sharing.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Taking a break"].exists)
        sharing.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["start.Photoshop"].tap()
        XCTAssertTrue(app.buttons["stopCurrent"].waitForExistence(timeout: 5))
        try navigate(app, id: "settings", title: "Settings")
        for (nativeName, heading) in [("한국어", "언어 및 지역"), ("English", "Language and region"), ("日本語", "言語と地域"), ("简体中文", "语言与地区")] {
            let picker = app.descendants(matching: .any).matching(identifier: "languagePicker")
            try XCTUnwrap(picker.allElementsBoundByIndex.first(where: \.isHittable)).tap()
            app.buttons[nativeName].tap()
            XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 5))
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = nativeName; shot.lifetime = .keepAlways; add(shot)
        }
        try navigate(app, id: "activity", title: "活动")
        XCTAssertTrue(app.buttons["stopCurrent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Photoshop"].exists)
        app.terminate()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        try navigate(app, id: "settings", title: "设置")
        XCTAssertTrue(app.staticTexts["语言与地区"].waitForExistence(timeout: 5))
    }
}
