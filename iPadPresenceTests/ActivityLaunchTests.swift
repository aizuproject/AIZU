import XCTest
@testable import iPadPresence

final class ActivityLaunchTests: XCTestCase {
    func testShortcutNameIsEncodedAsSingleQueryValue() throws {
        let name = "Arcaea 실행 & ADB #1 + 테스트"
        let url = try XCTUnwrap(ActivityLaunch.destination(method: "shortcut", value: name))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.scheme, "shortcuts")
        XCTAssertEqual(parts.host, "run-shortcut")
        XCTAssertEqual(parts.queryItems, [URLQueryItem(name: "name", value: name)])
    }
    func testLaunchURLValidationAndOptionalDefaults() throws {
        XCTAssertNil(try ActivityLaunch.destination(method: nil, value: nil))
        XCTAssertNil(try ActivityLaunch.destination(method: "none", value: "ignored"))
        XCTAssertEqual(try ActivityLaunch.destination(method: "appURL", value: " myapp://open ")?.scheme, "myapp")
        for value in ["", "relative", "file:///etc/passwd", "javascript:alert(1)", "http://example.com", "https://u:p@example.com", "shortcuts://run-shortcut?name=x", "discord-123:/authorize/callback"] {
            XCTAssertThrowsError(try ActivityLaunch.destination(method: "appURL", value: value))
        }
    }
    func testStoredLaunchSettingsRoundTrip() throws {
        var app = PresenceApp(name: "ADB")
        app.launchMethod = "shortcut"; app.launchValue = "My workflow"
        let restored = try JSONDecoder().decode(PresenceApp.self, from: JSONEncoder().encode(app))
        XCTAssertEqual(restored, app)
        XCTAssertTrue(restored.opensAfterSharing)
    }
}

@MainActor
private final class RecordingLauncher: ActivityLauncher {
    var urls: [URL] = []
    var result = true
    func open(_ url: URL) async -> Bool { urls.append(url); return result }
}

@MainActor
final class LaunchControllerTests: XCTestCase {
    private func configuredState() -> PresenceState {
        var app = PresenceApp(name: "A")
        app.launchMethod = "shortcut"; app.launchValue = "Open A"
        var state = PresenceState(); state.apps = [app]; state.sharingEnabled = true
        return state
    }
    func testOpensOnlyAfterPublishAndAutomationDoesNotLaunch() async {
        let state = configuredState(), transport = SlowTransport(), launcher = RecordingLauncher()
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport, launcher: launcher)
        let task = Task { await controller.shareAndLaunch(state.apps[0].id) }
        while transport.continuation == nil { await Task.yield() }
        XCTAssertTrue(launcher.urls.isEmpty)
        transport.finishPublish(); await task.value
        XCTAssertEqual(launcher.urls.count, 1)
        controller.start(state.apps[0].id, fromAutomation: true)
        while transport.continuation == nil { await Task.yield() }
        transport.finishPublish(); await controller.waitForSync()
        XCTAssertEqual(launcher.urls.count, 1)
        controller.stop(); await controller.waitForSync()
    }
    func testOffWhilePublishingCancelsAppLaunch() async {
        let state = configuredState(), transport = SlowTransport(), launcher = RecordingLauncher()
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport, launcher: launcher)
        let task = Task { await controller.shareAndLaunch(state.apps[0].id) }
        while transport.continuation == nil { await Task.yield() }
        controller.setSharing(false)
        transport.finishPublish(); await task.value
        XCTAssertTrue(launcher.urls.isEmpty)
        XCTAssertNil(controller.state.session)
    }
    func testFailedPublishAndBackgroundNavigationDoNotLaunch() async {
        for fail in [false, true] {
            let state = configuredState(), transport = SlowTransport(), launcher = RecordingLauncher()
            transport.failPublish = fail
            let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport, launcher: launcher)
            let task = Task { await controller.shareAndLaunch(state.apps[0].id) }
            if !fail {
                while transport.continuation == nil { await Task.yield() }
                controller.enteredBackground()
                transport.finishPublish()
            }
            await task.value
            XCTAssertTrue(launcher.urls.isEmpty)
            controller.stop(); await controller.waitForSync()
        }
    }
    func testOpenFailureKeepsSharedActivityAndExplainsFailure() async {
        let state = configuredState(), transport = SlowTransport(), launcher = RecordingLauncher()
        launcher.result = false
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport, launcher: launcher)
        let task = Task { await controller.shareAndLaunch(state.apps[0].id) }
        while transport.continuation == nil { await Task.yield() }
        transport.finishPublish(); await task.value
        XCTAssertNotNil(controller.state.session)
        XCTAssertTrue(controller.errorMessage?.contains("공유는 시작됐지만") == true)
        controller.stop(); await controller.waitForSync()
    }
    func testRemovesOnlyObsoleteBackgroundLogs() {
        var state = configuredState()
        state.log("실제 연결 오류")
        state.log("백그라운드 전환 · Discord 표시 유지 여부 미확인")
        let repo = MemoryStateRepository(state)
        let controller = PresenceController(repository: repo)
        XCTAssertEqual(controller.state.logs.map(\.message), ["실제 연결 오류"])
        XCTAssertEqual(repo.value.logs.map(\.message), ["실제 연결 오류"])
        controller.enteredBackground()
        XCTAssertEqual(controller.state.logs.map(\.message), ["실제 연결 오류"])
    }
}
