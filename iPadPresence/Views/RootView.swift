import SwiftUI

enum AppPage: String, CaseIterable, Identifiable {
    case activity, library, automation, settings
    var id: String { rawValue }
    var title: String {
        switch self { case .activity: L("활동"); case .library: L("앱"); case .automation: L("자동화"); case .settings: L("설정") }
    }
    var icon: String {
        switch self {
        case .activity: "circle.dotted.circle"
        case .library: "square.grid.2x2"
        case .automation: "bolt"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @Bindable var controller: PresenceController
    @AppStorage(Localization.preferenceKey) private var language = AppLanguage.system.rawValue
    @State private var page: AppPage = .activity
    @State private var addingApp = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .compact {
                TabView(selection: $page) {
                    ForEach(AppPage.allCases) { item in
                        destination(item)
                            .tabItem { Label(L(item.title), systemImage: item.icon) }.tag(item)
                    }
                }
            } else {
                NavigationSplitView {
                    List(selection: Binding<AppPage?>(get: { page }, set: { if let value = $0 { page = value } })) {
                        Section {
                            ForEach(AppPage.allCases) { item in
                                Label(L(item.title), systemImage: item.icon).tag(item)
                                    .padding(.vertical, 4)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("nav.\(item.id)")
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .navigationTitle("AIZU")
                    .safeAreaInset(edge: .bottom) {
                        HStack(spacing: 10) {
                            AizuBrand()
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L("활동 공유")).font(.subheadline.weight(.semibold))
                                Text("iPhone · iPad").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }.padding(20)
                    }
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 270)
                } detail: { destination(page) }
            }
        }
        .id(Localization.resolve(override: language, preferred: Locale.preferredLanguages))
        .sheet(isPresented: $addingApp) { AddAppView(controller: controller) }
        .alert(L("변경을 완료하지 못했습니다"), isPresented: Binding(
            get: { controller.errorMessage != nil },
            set: { if !$0 { controller.dismissError() } })) {
                Button(L("확인")) { controller.dismissError() }
            } message: { Text(L(controller.errorMessage ?? "")) }
        .environment(\.locale, Locale(identifier: Localization.resolve(override: language, preferred: Locale.preferredLanguages)))
    }

    private func destination(_ item: AppPage) -> some View {
        NavigationStack {
            Group {
                switch item {
                case .activity: ActivityView(controller: controller, showSettings: { page = .settings }, showLibrary: { page = .library })
                case .library: LibraryView(controller: controller)
                case .automation: AutomationView(controller: controller)
                case .settings: SettingsView(controller: controller)
                }
            }
            .frame(maxWidth: 900).frame(maxWidth: .infinity)
            .background(Palette.background)
            .navigationTitle(item == .activity && sizeClass == .compact ? "AIZU" : item.title)
            .navigationBarTitleDisplayMode(sizeClass == .compact ? .large : .inline)
            .toolbar {
                if item == .activity || item == .library {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { addingApp = true } label: { Label(L("앱 추가"), systemImage: "plus") }
                            .accessibilityIdentifier("addApp")
                    }
                }
            }
        }
    }
}

struct ActivityView: View {
    @Bindable var controller: PresenceController
    var showSettings: () -> Void
    var showLibrary: () -> Void

    var body: some View {
        List {
            if controller.state.previewMode {
                Section {
                    Label(L("미리보기 · Discord로 전송하지 않습니다"), systemImage: "eye")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle(isOn: Binding(get: { controller.state.sharingEnabled }, set: controller.setSharing)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("활동 공유")).fontWeight(.medium)
                        Text(controller.state.sharingEnabled ? (controller.currentApp == nil ? L("공유할 앱이나 활동을 선택하세요.") : L("선택한 활동을 Discord에 공유하고 있습니다.")) : L("꺼져 있는 동안에는 활동을 보내지 않습니다."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.accessibilityIdentifier("sharingToggle").disabled(!controller.storageHealthy)
            }

            Section {
                DiscordPreviewCard(application: controller.currentApp, session: controller.state.session,
                                   delivery: controller.delivery, isBusy: controller.isBusy,
                                   needsRemoteClear: controller.state.needsRemoteClear,
                                   runtimeStatus: controller.state.previewMode ? nil : controller.runtime.status,
                                   runtimeRunning: controller.runtime.running,
                                   stop: controller.stop, retry: controller.requestSync)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                if controller.state.apps.isEmpty {
                    Text(L("오른쪽 위 + 버튼으로 앱을 추가하세요.")).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(controller.state.apps.prefix(5)) { application in
                        AppActivityRow(application: application, controller: controller)
                    }
                    if controller.state.apps.count > 5 {
                        Button(L("모든 앱 보기"), action: showLibrary)
                    }
                }
            } header: { Text(L("내 활동")) }

            Section {
                Button(action: showSettings) {
                    HStack {
                        Label(L("Discord 계정"), systemImage: "person.crop.circle")
                        Spacer()
                        Text(controller.auth.isLinked ? L("연결됨") : L("연결 필요"))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }.font(.subheadline).foregroundStyle(.primary)
                }.accessibilityIdentifier("accountSettings")
            } footer: {
                Text(L("공유 중에는 백그라운드 연결을 자동으로 유지합니다. 종료할 때는 카드의 공유 종료를 눌러 주세요."))
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
    }
}
