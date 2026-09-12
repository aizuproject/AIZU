import XCTest
import UIKit
@testable import iPadPresence

final class PresenceStateTests: XCTestCase {
    func testCustomArtworkStaysLocalAndRemoteURLReachesPayload() throws {
        var state = PresenceState()
        let local = Data([1, 2, 3])
        let app = PresenceApp(name: "adb", localArtwork: local, details: "ADB로 디버깅 중")
        state.apps = [app]; state.setSharing(true); state.openApp(app.id)
        let restored = try JSONDecoder().decode(PresenceState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.apps.first?.localArtwork, local)
        XCTAssertNil(restored.desiredActivity?.imageURL)
        let remote = try ArtworkImage.remoteURL(" https://example.com/icon.png ")
        state.apps[0].artworkURL = remote
        XCTAssertEqual(state.desiredActivity?.imageURL, remote)
    }
    func testArtworkURLRejectsLocalAndCredentialURLs() throws {
        XCTAssertNil(try ArtworkImage.remoteURL(" "))
        for value in ["file:///tmp/a.png", "data:image/png;base64,a", "http://example.com/a.png", "https://user:pass@example.com/a.png", "invalid"] {
            XCTAssertThrowsError(try ArtworkImage.remoteURL(value))
        }
    }
    @MainActor
    func testImageImportDownsamplesAndRejectsNonImages() throws {
        let input = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 800)).pngData { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1600, height: 800))
        }
        let data = try ArtworkImage.normalized(input)
        let image = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(image.size.width, 256)
        XCTAssertLessThanOrEqual(data.count, ArtworkImage.maximumStoredBytes)
        XCTAssertThrowsError(try ArtworkImage.normalized(Data("not an image".utf8)))
    }

    func testLegacyLibraryAndShortcutIDsSurviveAppRename() throws {
        let old = #"{"schemaVersion":1,"games":[{"id":"0B565954-18CD-4119-8E14-675142C10670","name":"Existing game","developer":"Studio","storefront":"jp","enabled":true,"details":"My custom description","showElapsedTime":true}],"sharingEnabled":true,"previewMode":false,"session":{"id":"0B565954-18CD-4119-8E14-675142C10671","gameID":"0B565954-18CD-4119-8E14-675142C10670","startedAt":1000},"generation":2,"needsRemoteClear":true,"logs":[]}"#
        let state = try JSONDecoder().decode(PresenceState.self, from: Data(old.utf8))
        XCTAssertEqual(state.currentApp?.name, "Existing game")
        XCTAssertEqual(state.currentApp?.details, "My custom description")
        XCTAssertEqual(state.currentApp?.activityKind, .standard)
        XCTAssertEqual(state.session?.appID, state.apps.first?.id)
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        XCTAssertNotNil(encoded["games"])
        XCTAssertNil(encoded["apps"])
        let session = try XCTUnwrap(encoded["session"] as? [String: Any])
        XCTAssertEqual(session["gameID"] as? String, "0B565954-18CD-4119-8E14-675142C10670")
    }

    func testApplicationActivityKindsSurvivePersistenceAndReachPayload() throws {
        for kind in PresenceActivityKind.allCases {
            var application = PresenceApp(name: "YouTube", details: "Selected description")
            application.activityKind = kind
            var state = PresenceState(); state.apps = [application]
            state.setSharing(true); state.openApp(application.id)
            let restored = try JSONDecoder().decode(PresenceState.self, from: JSONEncoder().encode(state))
            XCTAssertEqual(restored.desiredActivity?.kind, kind)
            XCTAssertEqual(restored.desiredActivity?.details, "Selected description")
            XCTAssertEqual(restored.session?.startedAt, state.session?.startedAt)
        }
        let future = PresenceApp(name: "App", activityType: 999)
        XCTAssertEqual(future.activityKind, .standard)
    }

    func testDisabledSharingDoesNotStart() {
        var state = PresenceState(); let game = PresenceApp(name: "A"); state.apps = [game]
        state.openApp(game.id)
        XCTAssertNil(state.session)
        XCTAssertNotNil(state.apps[0].lastOpened)
    }
    func testDuplicateOpenKeepsOriginalStart() {
        var state = PresenceState(); let game = PresenceApp(name: "A"); state.apps = [game]
        state.setSharing(true); let time = Date(timeIntervalSince1970: 12345)
        state.openApp(game.id, at: time); let session = state.session
        state.openApp(game.id, at: time.addingTimeInterval(50))
        XCTAssertEqual(state.session, session)
    }
    func testLateCloseOfOtherGameDoesNotClearCurrent() {
        var state = PresenceState(); let a = PresenceApp(name: "A"), b = PresenceApp(name: "B"); state.apps = [a, b]
        state.setSharing(true); state.openApp(a.id); state.openApp(b.id); state.closeApp(a.id)
        XCTAssertEqual(state.session?.appID, b.id)
    }
    func testOffThenOnRequiresNewOpen() {
        var state = PresenceState(); let game = PresenceApp(name: "A"); state.apps = [game]
        state.setSharing(true); state.openApp(game.id); state.setSharing(false); state.openApp(game.id); state.setSharing(true)
        XCTAssertNil(state.desiredActivity)
        state.openApp(game.id)
        XCTAssertEqual(state.desiredActivity?.name, "A")
    }
    func testDisableOrRemoveCurrentGameEndsSession() {
        var state = PresenceState(); var game = PresenceApp(name: "A"); state.apps = [game]
        state.setSharing(true); state.openApp(game.id); game.enabled = false; state.saveApp(game)
        XCTAssertNil(state.session)
        game.enabled = true; state.saveApp(game); state.openApp(game.id); state.removeApp(game.id)
        XCTAssertNil(state.desiredActivity); XCTAssertTrue(state.apps.isEmpty)
    }
    func testHideTimeRemovesTimestamp() {
        var state = PresenceState(); let game = PresenceApp(name: "A", showElapsedTime: false); state.apps = [game]
        state.setSharing(true); state.openApp(game.id)
        XCTAssertNotNil(state.desiredActivity); XCTAssertNil(state.desiredActivity?.startedAt)
    }
    func testRealKeychainCreateUpdateReadDelete() throws {
        let account = "unit-test.\(UUID().uuidString)"
        defer { try? TokenKeychain.delete(account: account) }
        try TokenKeychain.verifyStorage()
        XCTAssertNil(try TokenKeychain.read(account: account))
        let initial = OAuthTokens(accessToken: "test-access", refreshToken: "test-refresh",
                                  expiresAt: Date(timeIntervalSince1970: 12345), applicationID: "123")
        try TokenKeychain.write(initial, account: account)
        XCTAssertEqual(try TokenKeychain.read(account: account), initial)
        let updated = OAuthTokens(accessToken: "updated-access", refreshToken: "updated-refresh",
                                  expiresAt: Date(timeIntervalSince1970: 23456), applicationID: "123")
        try TokenKeychain.write(updated, account: account)
        XCTAssertEqual(try TokenKeychain.read(account: account), updated)
        try TokenKeychain.delete(account: account)
        XCTAssertNil(try TokenKeychain.read(account: account))
    }
    func testPKCEAgainstRFC7636Example() {
        XCTAssertEqual(OAuthPKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }
    func testOAuthRejectsWrongStateAndScheme() throws {
        let valid = URL(string: "discord-123:/authorize/callback?state=expected&code=abc")!
        XCTAssertEqual(try OAuthPKCE.validateCallback(valid, expectedState: "expected", scheme: "discord-123"), "abc")
        XCTAssertThrowsError(try OAuthPKCE.validateCallback(valid, expectedState: "wrong", scheme: "discord-123"))
        XCTAssertThrowsError(try OAuthPKCE.validateCallback(valid, expectedState: "expected", scheme: "discord-999"))
        let duplicate = URL(string: "discord-123:/authorize/callback?state=expected&state=evil&code=abc")!
        XCTAssertThrowsError(try OAuthPKCE.validateCallback(duplicate, expectedState: "expected", scheme: "discord-123"))
    }
    func testOAuthExplainsRejectedScopeWithoutExposingCallbackContents() {
        let url = URL(string: "discord-123:/authorize/callback?state=expected&error=invalid_scope&error_description=private-value")!
        XCTAssertThrowsError(try OAuthPKCE.validateCallback(url, expectedState: "expected", scheme: "discord-123")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Social SDK"))
            XCTAssertFalse(error.localizedDescription.contains("private-value"))
        }
    }
    func testOAuthErrorCannotOverrideStateValidation() {
        let url = URL(string: "discord-123:/authorize/callback?state=wrong&error=invalid_scope")!
        XCTAssertThrowsError(try OAuthPKCE.validateCallback(url, expectedState: "expected", scheme: "discord-123")) { error in
            XCTAssertTrue(error.localizedDescription.contains("응답을 확인할 수 없습니다"))
        }
    }
    func testOAuthRejectsDuplicateCode() {
        let url = URL(string: "discord-123:/authorize/callback?state=expected&code=first&code=second")!
        XCTAssertThrowsError(try OAuthPKCE.validateCallback(url, expectedState: "expected", scheme: "discord-123"))
    }
    func testStoreResponseMapsCorrectRegionAndIcon() throws {
        let data = Data(#"{"trackId":123,"trackName":"PresenceApp","artistName":"Developer","artworkUrl512":"https://example.com/icon.png"}"#.utf8)
        let game = try JSONDecoder().decode(StoreApp.self, from: data).application(country: "jp")
        XCTAssertEqual(game.storefront, "jp"); XCTAssertEqual(game.appStoreID, 123)
        XCTAssertEqual(game.artworkURL?.host, "example.com")
    }
}

@MainActor
final class SlowTransport: PresenceTransport {
    var calls: [String] = []
    var continuation: CheckedContinuation<Void, Never>?
    var failClear = false
    var failPublish = false
    var connectionIssue: String?
    func publish(_ activity: ActivityPayload) async throws {
        calls.append("publish:\(activity.name)")
        if failPublish { throw PresenceFailure.message("Authentication unavailable") }
        await withCheckedContinuation { continuation = $0 }
    }
    func clear() async throws {
        calls.append("clear")
        if failClear { throw PresenceFailure.message("offline") }
    }
    func disconnect() { calls.append("disconnect") }
    func finishPublish() { continuation?.resume(); continuation = nil }
}

@MainActor
final class ControllerTests: XCTestCase {
    func testFailedAppSaveDoesNotReportSuccess() {
        let controller = PresenceController(repository: FailingSaveRepository(), transport: SlowTransport())
        XCTAssertFalse(controller.saveApp(PresenceApp(name: "My Studio")))
        XCTAssertTrue(controller.state.apps.isEmpty)
        XCTAssertNotNil(controller.errorMessage)
    }
    func testConnectionLossRepublishesWithoutResettingStart() async {
        let game = PresenceApp(name: "A"); var state = PresenceState()
        state.apps = [game]; state.sharingEnabled = true
        let transport = SlowTransport()
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport)
        controller.start(game.id)
        while transport.continuation == nil { await Task.yield() }
        transport.finishPublish(); await controller.waitForSync()
        let original = controller.state.session
        transport.connectionIssue = "test connection lost"
        controller.checkConnectionHealth()
        while transport.continuation == nil { await Task.yield() }
        transport.connectionIssue = nil
        transport.finishPublish(); await controller.waitForSync()
        XCTAssertEqual(controller.state.session, original)
        XCTAssertEqual(transport.calls.filter { $0 == "publish:A" }.count, 2)
        XCTAssertEqual(controller.delivery, .submitted)
        controller.enteredBackground()
    }
    func testBackgroundDoesNotRetryAndForegroundRestoresActivity() async {
        let game = PresenceApp(name: "A"); var state = PresenceState()
        state.apps = [game]; state.sharingEnabled = true
        let transport = SlowTransport()
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport)
        controller.start(game.id)
        while transport.continuation == nil { await Task.yield() }
        transport.finishPublish(); await controller.waitForSync()
        controller.enteredBackground()
        transport.connectionIssue = "offline"
        controller.checkConnectionHealth()
        XCTAssertFalse(controller.isBusy)
        controller.enteredForeground()
        while transport.continuation == nil { await Task.yield() }
        transport.finishPublish(); await controller.waitForSync()
        XCTAssertEqual(transport.calls.filter { $0 == "publish:A" }.count, 2)
        controller.setSharing(false); await controller.waitForSync()
        let count = transport.calls.count
        controller.checkConnectionHealth()
        controller.enteredForeground()
        await controller.waitForSync()
        XCTAssertEqual(transport.calls.count, count)
        XCTAssertNil(controller.state.session)
    }
    func testOffWinsOverInFlightPublish() async {
        let game = PresenceApp(name: "A"); var state = PresenceState(); state.apps = [game]; state.sharingEnabled = true
        let transport = SlowTransport()
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport)
        controller.start(game.id)
        while transport.continuation == nil { await Task.yield() }
        controller.setSharing(false)
        transport.finishPublish()
        await controller.waitForSync()
        XCTAssertEqual(transport.calls, ["publish:A", "clear", "disconnect"])
        XCTAssertNil(controller.state.session)
        XCTAssertFalse(controller.state.needsRemoteClear)
    }
    func testFailedClearPersistsAndCanRetry() async {
        var state = PresenceState(); state.needsRemoteClear = true
        let repo = MemoryStateRepository(state); let transport = SlowTransport(); transport.failClear = true
        let controller = PresenceController(repository: repo, transport: transport)
        controller.requestSync(); await controller.waitForSync()
        XCTAssertTrue(repo.value.needsRemoteClear)
        transport.failClear = false
        controller.requestSync(); await controller.waitForSync()
        XCTAssertFalse(repo.value.needsRemoteClear)
    }
    func testRelaunchDoesNotResumePersistedSession() {
        var state = PresenceState(); let game = PresenceApp(name: "A"); state.apps = [game]; state.sharingEnabled = true
        state.openApp(game.id); state.needsRemoteClear = true
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: SlowTransport())
        XCTAssertNil(controller.state.session)
        XCTAssertTrue(controller.state.needsRemoteClear)
    }
    func testColdStartCloseStillClearsPreviousRemoteActivity() async {
        var state = PresenceState(); let game = PresenceApp(name: "A"); state.apps = [game]; state.sharingEnabled = true
        state.openApp(game.id); state.needsRemoteClear = true
        let transport = SlowTransport()
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport)
        controller.close(game.id); await controller.waitForSync()
        XCTAssertEqual(transport.calls, ["clear", "disconnect"])
        XCTAssertFalse(controller.state.needsRemoteClear)
    }
    func testManualStartDoesNotMarkAutomationReceived() async {
        var state = PresenceState(); let game = PresenceApp(name: "A"); state.apps = [game]; state.sharingEnabled = true
        state.previewMode = true
        let controller = PresenceController(repository: MemoryStateRepository(state))
        controller.start(game.id); await controller.waitForSync()
        XCTAssertNil(controller.state.apps[0].lastOpened)
        controller.start(game.id, fromAutomation: true)
        XCTAssertNotNil(controller.state.apps[0].lastOpened)
    }
    func testPublishCompletingInBackgroundRemainsUnverified() async {
        var state = PresenceState(); let game = PresenceApp(name: "A"); state.apps = [game]; state.sharingEnabled = true
        let transport = SlowTransport()
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport)
        controller.start(game.id)
        while transport.continuation == nil { await Task.yield() }
        controller.enteredBackground()
        transport.finishPublish(); await controller.waitForSync()
        XCTAssertEqual(controller.delivery, .unverified)
    }
    func testFileRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = FileStateRepository(file: directory.appending(path: "state.json"))
        var state = PresenceState(); state.apps = [PresenceApp(name: "테스트")]; state.sharingEnabled = true
        try repo.save(state)
        XCTAssertEqual(try repo.load(), state)
    }
    func testCorruptFileIsPreserved() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "state.json"); let bytes = Data("broken".utf8); try bytes.write(to: file)
        let controller = PresenceController(repository: FileStateRepository(file: file), transport: SlowTransport())
        controller.setSharing(true)
        XCTAssertFalse(controller.storageHealthy)
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }
}

@MainActor
private final class FailingSaveRepository: StateRepository {
    func load() throws -> PresenceState { PresenceState() }
    func save(_ state: PresenceState) throws { throw PresenceFailure.message("Test storage failure") }
}

@MainActor
private final class TestRuntime: ConnectionRuntime {
    var running = false
    var status: String { running ? "백그라운드 연결 유지 중" : "대기 중" }
    var onChange: (() -> Void)?
    var starts = 0
    func start() { if !running { starts += 1 }; running = true; onChange?() }
    func stop() { running = false; onChange?() }
}

@MainActor
final class RuntimeIntegrationTests: XCTestCase {
    func testStartAndOffDuringPublishStopRuntimeImmediately() async {
        let app = PresenceApp(name: "A"); var state = PresenceState()
        state.apps = [app]; state.sharingEnabled = true
        let runtime = TestRuntime(); let transport = SlowTransport()
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport, runtime: runtime)
        controller.start(app.id, fromAutomation: true)
        XCTAssertTrue(runtime.running)
        while transport.continuation == nil { await Task.yield() }
        controller.setSharing(false)
        XCTAssertFalse(runtime.running)
        transport.finishPublish(); await controller.waitForSync()
        XCTAssertFalse(runtime.running)
        XCTAssertEqual(transport.calls, ["publish:A", "clear", "disconnect"])
        controller.setSharing(true); await controller.waitForSync()
        XCTAssertFalse(runtime.running)
    }

    func testUnrelatedCloseKeepsRuntimeAndFailedClearStillStopsIt() async {
        let a = PresenceApp(name: "A"), b = PresenceApp(name: "B")
        var state = PresenceState(); state.apps = [a,b]; state.sharingEnabled = true
        let runtime = TestRuntime(); let transport = SlowTransport(); transport.failClear = true
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport, runtime: runtime)
        controller.start(b.id, fromAutomation: true)
        while transport.continuation == nil { await Task.yield() }
        transport.finishPublish(); await controller.waitForSync()
        controller.close(a.id)
        XCTAssertTrue(runtime.running)
        XCTAssertEqual(controller.state.currentApp?.id, b.id)
        controller.close(b.id); await controller.waitForSync()
        XCTAssertFalse(runtime.running)
        XCTAssertTrue(controller.state.needsRemoteClear)
    }

    func testFailedPublishWithoutLinkedAccountReleasesAudio() async {
        let app = PresenceApp(name: "A"); var state = PresenceState()
        state.apps = [app]; state.sharingEnabled = true
        let runtime = TestRuntime(); let transport = SlowTransport(); transport.failPublish = true
        let controller = PresenceController(repository: MemoryStateRepository(state), transport: transport, runtime: runtime)
        controller.start(app.id)
        await controller.waitForSync()
        XCTAssertFalse(runtime.running)
        if case .failed = controller.delivery {} else { XCTFail("Expected failed delivery") }
        controller.stop(); await controller.waitForSync()
    }

    func testPreviewAndColdLaunchDoNotPlayAudio() async {
        let app = PresenceApp(name: "A"); var state = PresenceState()
        state.apps = [app]; state.sharingEnabled = true; state.previewMode = true
        let runtime = TestRuntime()
        let controller = PresenceController(repository: MemoryStateRepository(state), runtime: runtime)
        controller.start(app.id); await controller.waitForSync()
        XCTAssertEqual(runtime.starts, 0)
        state.previewMode = false; state.openApp(app.id)
        let restarted = PresenceController(repository: MemoryStateRepository(state), runtime: runtime)
        XCTAssertNil(restarted.state.session); XCTAssertFalse(runtime.running)
    }
}
