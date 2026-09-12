import SwiftUI
import AppIntents

struct LibraryView: View {
    @Bindable var controller: PresenceController
    @State private var editing: PresenceApp?
    @State private var query = ""
    private var applications: [PresenceApp] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return controller.state.apps.filter { text.isEmpty || $0.name.localizedCaseInsensitiveContains(text) }
    }
    var body: some View {
        List {
            if controller.state.apps.isEmpty {
                ContentUnavailableView(L("등록한 앱 없음"), systemImage: "square.grid.2x2",
                                       description: Text(L("+ 버튼으로 앱을 추가하세요.")))
            } else if applications.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                Section {
                    ForEach(applications) { application in
                        Button { editing = application } label: {
                            HStack(spacing: 12) {
                                AppIconView(application: application)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(application.name).fontWeight(.medium).foregroundStyle(.primary)
                                    Text(application.enabled ? L(application.activityKind.title) : L("공유 비활성화"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                            }.padding(.vertical, 4).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("edit.\(application.name)")
                    }
                } header: { Text(L("\(applications.count)개 앱")) }
                footer: { Text(L("앱을 선택해 표시할 정보와 공유 후 실행할 앱·단축어를 설정하세요.")) }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L("앱 검색"))
        .sheet(item: $editing) { application in EditAppView(controller: controller, application: application) }
    }
}

struct AddAppView: View {
    @Bindable var controller: PresenceController
    @Environment(\.dismiss) private var dismiss
    @State private var method = 0
    @State private var query = ""
    @State private var country = Localization.defaultStorefront()
    @State private var results: [StoreApp] = []
    @State private var loading = false
    @State private var searched = false
    @State private var failure: String?
    @State private var name = ""
    @State private var details = ""
    @State private var localImage: Data?
    @State private var imageURL = ""
    @State private var launchMethod = LaunchMethod.none.rawValue
    @State private var launchValue = ""
    @State private var kind: PresenceActivityKind = .standard
    @State private var saveError: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L("등록 방법"), selection: $method) {
                        Text(L("App Store 검색")).tag(0)
                        Text(L("직접 입력")).tag(1)
                    }.pickerStyle(.segmented).accessibilityIdentifier("addMethod")
                }
                if method == 0 {
                    Section {
                        TextField(L("앱 이름 또는 App Store 링크"), text: $query)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .accessibilityIdentifier("storeSearch")
                        Picker(L("스토어"), selection: $country) {
                            Text(L("대한민국")).tag("kr"); Text(L("일본")).tag("jp"); Text(L("미국")).tag("us"); Text(L("중국")).tag("cn")
                        }
                    } footer: { Text(L("검색 결과는 App Store 정보입니다. 이 기기의 설치 여부를 나타내지 않습니다.")) }
                    if loading { Section { HStack { ProgressView(); Text(L("검색 중")).foregroundStyle(.secondary) } } }
                    if let failure { Section { Text(L(failure)).font(.subheadline).foregroundStyle(.red) } }
                    if !results.isEmpty {
                        Section(L("검색 결과")) {
                            ForEach(results) { result in
                                let application = result.application(country: country)
                                HStack(spacing: 12) {
                                    AppIconView(application: application)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.trackName).font(.subheadline.weight(.medium))
                                        Text(result.artistName ?? "App Store").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    let exists = controller.state.apps.contains { $0.appStoreID == result.trackId && $0.storefront == country }
                                    Button(exists ? L("추가됨") : L("추가")) {
                                        guard controller.saveApp(application) else { saveError = controller.errorMessage; return }
                                        PresenceShortcuts.updateAppShortcutParameters()
                                        dismiss()
                                    }.buttonStyle(.bordered).disabled(exists)
                                }.padding(.vertical, 4)
                            }
                        }
                    } else if searched && !loading && failure == nil {
                        Section { Text(L("결과가 없습니다. 검색어나 스토어를 바꾸거나 직접 입력하세요.")).foregroundStyle(.secondary) }
                    }
                } else {
                    Section {
                        TextField(L("앱 또는 작업 이름"), text: $name).autocorrectionDisabled()
                            .accessibilityIdentifier("manualAppName")
                        TextField(L("하고 있는 일"), text: $details)
                            .accessibilityIdentifier("manualAppDetails")
                        Picker(L("활동 유형"), selection: $kind) {
                            ForEach(PresenceActivityKind.allCases) { item in Text(L(item.title)).tag(item) }
                        }
                    } header: { Text(L("앱 또는 작업")) }
                    footer: { Text(L("기본 활동은 Discord에서 ‘플레이 중’으로 표시될 수 있습니다. 영상이나 음악은 시청·청취 유형을 선택하세요.")) }
                    ArtworkEditor(localImage: $localImage, imageURL: $imageURL)
                    LaunchSettingsEditor(method: $launchMethod, value: $launchValue)
                    Section {
                        Button(L("활동 추가")) {
                            let remote: URL?
                            do {
                                remote = try ArtworkImage.remoteURL(imageURL)
                                _ = try ActivityLaunch.destination(method: launchMethod, value: launchValue)
                            }
                            catch { saveError = error.localizedDescription; return }
                            var application = PresenceApp(name: name, artworkURL: remote, localArtwork: localImage, details: details)
                            application.activityKind = kind
                            application.launchMethod = launchMethod
                            application.launchValue = launchValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard controller.saveApp(application) else { saveError = controller.errorMessage; return }
                            PresenceShortcuts.updateAppShortcutParameters()
                            dismiss()
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("saveManualApp")
                    }
                }
                if let saveError { Section { Text(L(saveError)).font(.caption).foregroundStyle(.red) } }
            }
            .navigationTitle(L("활동 추가")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("취소")) { dismiss() } } }
            .task(id: "\(method):\(country):\(query)") {
                results = []; failure = nil; searched = false
                guard method == 0, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { loading = false; return }
                loading = true
                do {
                    try await Task.sleep(for: .milliseconds(450))
                    let apps = try await AppStoreService.shared.search(query, country: country)
                    try Task.checkCancellation()
                    results = apps; searched = true; loading = false
                } catch is CancellationError { }
                catch {
                    guard !Task.isCancelled else { return }
                    failure = error.localizedDescription; loading = false
                }
            }
        }.presentationDetents([.large])
    }
}

struct EditAppView: View {
    @Bindable var controller: PresenceController
    @Environment(\.dismiss) private var dismiss
    @State var application: PresenceApp
    @State private var imageURL: String
    @State private var launchMethod: String
    @State private var launchValue: String
    init(controller: PresenceController, application: PresenceApp) {
        self.controller = controller
        _application = State(initialValue: application)
        _imageURL = State(initialValue: application.artworkURL?.absoluteString ?? "")
        _launchMethod = State(initialValue: application.launchMethod ?? LaunchMethod.none.rawValue)
        _launchValue = State(initialValue: application.launchValue ?? "")
    }
    @State private var confirmDelete = false
    @State private var saveError: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        AppIconView(application: application, size: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(application.name).font(.headline)
                            Text(application.appStoreID == nil && application.developer == "직접 등록" ? L("직접 등록") : application.developer).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }
                Section {
                    TextField(L("앱 또는 작업 이름"), text: $application.name)
                    TextField(L("표시할 설명"), text: $application.details, axis: .vertical).lineLimit(1...3)
                    Picker(L("활동 유형"), selection: $application.activityKind) {
                        ForEach(PresenceActivityKind.allCases) { item in Text(L(item.title)).tag(item) }
                    }.accessibilityIdentifier("activityKind")
                    Toggle(L("이 앱 공유 허용"), isOn: $application.enabled)
                    Toggle(L("경과 시간 표시"), isOn: $application.showElapsedTime)
                } header: { Text(L("Discord에 표시할 정보")) }
                footer: { Text(L("기본 활동은 Discord에서 ‘플레이 중’으로 표시될 수 있습니다. 설명은 직접 지정하며 문서명이나 영상 제목을 자동으로 읽지 않습니다.")) }
                LaunchSettingsEditor(method: $launchMethod, value: $launchValue)
                ArtworkEditor(localImage: $application.localArtwork, imageURL: $imageURL)
                if let url = application.storeURL { Section { Link(L("App Store에서 보기"), destination: url) } }
                Section {
                    Button(launchMethod == LaunchMethod.none.rawValue ? L("저장하고 공유") : L("저장하고 실행")) {
                        if save() {
                            let id = application.id
                            dismiss()
                            Task { await controller.shareAndLaunch(id) }
                        }
                    }
                        .disabled(!controller.state.sharingEnabled || !application.enabled || application.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button(L("앱 삭제"), role: .destructive) { confirmDelete = true }
                } footer: {
                    if !controller.state.sharingEnabled { Text(L("활동 화면에서 전체 공유를 켜면 바로 공유할 수 있습니다.")) }
                }
                if let saveError { Section { Text(L(saveError)).font(.caption).foregroundStyle(.red) } }
            }
            .navigationTitle(L("활동 설정")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("취소")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("저장")) { if save() { dismiss() } }
                        .disabled(application.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("saveAppSettings")
                }
            }
            .confirmationDialog(L("이 앱을 삭제하시겠습니까?"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(L("앱 삭제"), role: .destructive) {
                    controller.removeApp(application.id)
                    PresenceShortcuts.updateAppShortcutParameters()
                    dismiss()
                }
            } message: { Text(L("공유 중인 활동도 종료됩니다. 연결한 단축어 자동화는 직접 삭제해야 합니다.")) }
        }
    }
    private func save() -> Bool {
        do {
            application.artworkURL = try ArtworkImage.remoteURL(imageURL)
            _ = try ActivityLaunch.destination(method: launchMethod, value: launchValue)
            application.launchMethod = launchMethod
            application.launchValue = launchValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        catch { saveError = error.localizedDescription; return false }
        guard controller.saveApp(application) else { saveError = controller.errorMessage; return false }
        PresenceShortcuts.updateAppShortcutParameters()
        return true
    }
}
