import Foundation

@MainActor
protocol StateRepository {
    func load() throws -> PresenceState
    func save(_ state: PresenceState) throws
}

@MainActor
final class FileStateRepository: StateRepository {
    let file: URL
    init(file: URL? = nil) {
        self.file = file ?? URL.applicationSupportDirectory
            .appending(path: "iPadPresence", directoryHint: .isDirectory)
            .appending(path: "state.json")
    }
    func load() throws -> PresenceState {
        guard FileManager.default.fileExists(atPath: file.path) else { return PresenceState() }
        let result = try JSONDecoder().decode(PresenceState.self, from: Data(contentsOf: file))
        guard result.schemaVersion == 1 else {
            throw PresenceFailure.message("더 새로운 앱에서 저장한 데이터입니다. 앱을 업데이트해 주세요.")
        }
        return result
    }
    func save(_ state: PresenceState) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

@MainActor
final class MemoryStateRepository: StateRepository {
    var value: PresenceState
    init(_ value: PresenceState = PresenceState()) { self.value = value }
    func load() throws -> PresenceState { value }
    func save(_ state: PresenceState) throws { value = state }
}
