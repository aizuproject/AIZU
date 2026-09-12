import XCTest

/// Run explicitly to recreate the documentation media. Uses in-memory preview data.
@MainActor
final class ReadmeCaptureTests: XCTestCase {
    func testCaptureReadme() throws {
        guard ProcessInfo.processInfo.environment["AIZU_CAPTURE_README"] == "1" else {
            throw XCTSkip("Documentation capture is opt-in.")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-language", "ko", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        let sharing = app.switches["sharingToggle"]
        XCTAssertTrue(sharing.waitForExistence(timeout: 10))
        capture("01-idle")
        sharing.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["start.Photoshop"].tap()
        XCTAssertTrue(app.buttons["stopCurrent"].waitForExistence(timeout: 5))
        capture("02-sharing")
        app.buttons["stopCurrent"].tap()
        XCTAssertFalse(app.buttons["stopCurrent"].exists)
        capture("03-stopped")
        try navigate(app, id: "library")
        capture("04-library")
        app.buttons["addApp"].tap()
        app.segmentedControls.buttons["직접 입력"].tap()
        capture("05-custom-activity")
        app.buttons["취소"].tap()
        try navigate(app, id: "settings")
        capture("06-settings")
    }

    private func navigate(_ app: XCUIApplication, id: String) throws {
        let items = app.descendants(matching: .any).matching(identifier: "nav.\(id)")
        try XCTUnwrap(items.allElementsBoundByIndex.first(where: \.isHittable)).tap()
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
