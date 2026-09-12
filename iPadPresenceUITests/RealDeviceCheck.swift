import XCTest

/// Opt-in only: real account and paired device. Normal test runs skip this case.
final class RealDeviceCheck: XCTestCase {
    @MainActor
    func testAutomaticAudioStartsAndStopsWithSharing() throws {
        guard ProcessInfo.processInfo.environment["AIZU_REAL_DEVICE_CHECK"] == "1" else {
            throw XCTSkip("Real-account test requires explicit opt-in.")
        }
        let app = XCUIApplication()
        app.activate()
        try navigate(app, id: "activity")
        if app.buttons["stopCurrent"].exists { app.buttons["stopCurrent"].tap() }
        let start = app.buttons["start.Arcaea"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        defer {
            try? navigate(app, id: "activity")
            if app.buttons["stopCurrent"].exists { app.buttons["stopCurrent"].tap() }
        }
        XCTAssertTrue(app.staticTexts["Discord에 전송됨"].waitForExistence(timeout: 30))
        let runtime = app.staticTexts["runtimeStatus"]
        XCTAssertTrue(runtime.waitForExistence(timeout: 5))
        XCTAssertEqual(runtime.label, "백그라운드 연결 유지 중")
        capture(app, "Automatic background connection")
        app.buttons["stopCurrent"].tap()
        try navigate(app, id: "settings")
        XCTAssertTrue(app.staticTexts["대기 중"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["audioExperiment"].exists)
        XCTAssertFalse(app.buttons["continuedSyncExperiment"].exists)
        capture(app, "Settings without experiments")
    }

    @MainActor private func navigate(_ app: XCUIApplication, id: String) throws {
        let items = app.descendants(matching: .any).matching(identifier: "nav.\(id)")
        XCTAssertTrue(items.firstMatch.waitForExistence(timeout: 5))
        try XCTUnwrap(items.allElementsBoundByIndex.first(where: \.isHittable)).tap()
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
