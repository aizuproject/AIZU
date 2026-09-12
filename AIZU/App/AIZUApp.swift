import SwiftUI
import AppIntents

@main
struct AIZUApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller: PresenceController
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--ui-language"),
               ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
                UserDefaults.standard.set(ProcessInfo.processInfo.arguments[index + 1], forKey: Localization.preferenceKey)
            }
            var state = PresenceState()
            state.apps = PresenceApp.examples
            state.previewMode = true
            _controller = State(initialValue: PresenceController(repository: MemoryStateRepository(state), auth: DiscordAuth(preview: true)))
        } else { _controller = State(initialValue: .shared) }
        #else
        _controller = State(initialValue: .shared)
        #endif
    }
    var body: some Scene {
        WindowGroup {
            RootView(controller: controller)
                .tint(Palette.accent)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { controller.enteredBackground() }
                    if phase == .active { controller.enteredForeground() }
                }
                .task {
                    PresenceShortcuts.updateAppShortcutParameters()
                }
        }
    }
}
