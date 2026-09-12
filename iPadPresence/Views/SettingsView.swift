import SwiftUI

struct SettingsView: View {
    @Bindable var controller: PresenceController
    @AppStorage(Localization.preferenceKey) private var language = AppLanguage.system.rawValue
    @State private var confirmUnlink = false
    var body: some View {
        Form {
            Section {
                Picker(L("언어"), selection: $language) {
                    ForEach(AppLanguage.allCases) { choice in
                        Text(L(choice.nativeName)).tag(choice.rawValue)
                    }
                }.accessibilityIdentifier("languagePicker")
            } header: { Text(L("언어 및 지역")) }
            footer: { Text(L("자동 설정은 기기의 선호 언어를 따릅니다. 지원하지 않는 언어는 영어로 표시합니다. 시스템 창과 단축어 앱의 언어는 기기 설정을 따릅니다.")) }

            Section {
                HStack {
                    Label("Discord", systemImage: "person.crop.circle")
                    Spacer()
                    StatusPill(text: controller.auth.isLinked ? L("연결됨") : L("연결 안 됨"), active: controller.auth.isLinked)
                }
                if controller.auth.isLinked {
                    Button(L("다시 인증")) { Task { await controller.auth.login() } }
                        .disabled(controller.isBusy || controller.auth.isAuthorizing)
                    Button(L("계정 연결 해제"), role: .destructive) { confirmUnlink = true }
                        .disabled(controller.isBusy)
                } else {
                    Button {
                        Task { await controller.auth.login() }
                    } label: {
                        HStack {
                            Text(L("Discord 계정 연결"))
                            if controller.auth.isAuthorizing { Spacer(); ProgressView() }
                        }
                    }.disabled(controller.auth.isAuthorizing || !controller.auth.isConfigured)
                        .accessibilityIdentifier("connectDiscord")
                }
                if let error = controller.auth.errorMessage { Text(L(error)).font(.caption).foregroundStyle(.red) }
            } header: { Text(L("계정")) }
            footer: { Text(L("공유한 앱 이름, 설명, 이미지와 시작 시각을 Discord에 전달합니다. 로그인 정보는 기기의 Keychain에 저장합니다.")) }

            Section {
                LabeledContent(L("연결 유지"), value: L(controller.runtime.status))
                    .accessibilityIdentifier("settingsRuntimeStatus")
                Text(L("활동을 공유하면 자동으로 시작하고, 공유를 종료하면 함께 멈춥니다."))
                    .font(.subheadline).foregroundStyle(.secondary)
            } header: { Text(L("백그라운드")) }

            Section(L("사용 안내")) {
                NavigationLink { RuntimeHelpView() } label: {
                    Label(L("백그라운드 및 앱 종료"), systemImage: "info.circle")
                }.accessibilityIdentifier("runtimeHelp")
                DisclosureGroup(L("Discord 승인 버튼이 눌리지 않을 때")) {
                    Text(L("권한 안내 안쪽을 끝까지 스크롤하면 승인 버튼이 활성화됩니다.")).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            Section(L("연결 진단")) {
                LabeledContent(L("전송 상태"), value: L(controller.delivery.title))
                if controller.state.needsRemoteClear && controller.state.session == nil {
                    Label(L("이전 활동 정리가 필요합니다"), systemImage: "exclamationmark.circle").foregroundStyle(.orange)
                }
                Button(L("전송 다시 시도")) { controller.requestSync() }.disabled(controller.isBusy)
                DisclosureGroup(L("이벤트 기록")) {
                    ForEach(controller.state.logs.prefix(20)) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L(log.message)).font(.caption)
                            Text(log.date, format: .dateTime.hour().minute().second())
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }.padding(.vertical, 3)
                    }
                    if controller.state.logs.isEmpty { Text(L("기록 없음")).foregroundStyle(.secondary) }
                    Button(L("기록 지우기")) { controller.clearLogs() }
                }
                if !DiscordBridge.available || !controller.auth.isConfigured {
                    Text(L("이 빌드에 Discord 연결 구성이 필요합니다. 프로젝트 README의 연결 설정을 확인하세요."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                HStack(spacing: 12) {
                    AizuBrand(size: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("AIZU").font(.subheadline.weight(.semibold))
                        Text(L("iPhone · iPad 활동 공유")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text((Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0") + " Beta")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .confirmationDialog(L("Discord 계정 연결을 해제하시겠습니까?"), isPresented: $confirmUnlink, titleVisibility: .visible) {
            Button(L("연결 해제"), role: .destructive) {
                Task {
                    controller.setSharing(false)
                    await controller.waitForSync()
                    if !controller.state.needsRemoteClear { controller.auth.unlink() }
                }
            }
        } message: {
            Text(L("현재 활동을 정리한 뒤 이 기기의 로그인 정보를 삭제합니다."))
        }
    }
}

struct RuntimeHelpView: View {
    var body: some View {
        List {
            Section(L("홈 화면이나 다른 앱으로 이동")) {
                Text(L("공유 중에는 무음 오디오로 연결을 유지합니다. 별도 실행 버튼 없이 활동 공유와 함께 시작·종료됩니다. 다른 앱의 오디오나 네트워크 상태에 따라 중단될 수 있습니다."))
            }
            Section(L("앱을 밀어서 완전히 종료")) {
                Text(L("종료한 뒤에는 연결을 유지할 수 없습니다. 앱을 닫기 전에 ‘공유 종료’를 누르고 전송 상태를 확인하세요."))
            }
            Section(L("사용법 유도")) {
                Text(L("사용법 유도 중 활동 공유")).font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("guidedAccessHelp")
                Text(L("AIZU에서 공유를 시작한 뒤 대상 앱의 사용법 유도를 켜세요. 일부 기기·게임에서 유지 동작을 확인했으며 모든 환경을 보장하지는 않습니다. 종료할 때는 공유 종료 또는 앱 닫힘 자동화를 사용하세요."))
                    .foregroundStyle(.secondary)
            }
            Section(L("무음 오디오 안내")) {
                Text(L("마이크나 화면을 사용하지 않습니다. 공유 중 추가 전력을 사용하며 다른 앱의 음악 재생과 충돌할 수 있습니다."))
                Text(L("이 연결 유지 방식이 포함된 버전은 개인 설치용입니다. App Store 배포용으로 제공하지 않습니다."))
                    .foregroundStyle(.secondary)
            }
            Section(L("활동 정보")) {
                Text(L("공유는 직접 선택하거나 단축어 자동화로 시작합니다. 다른 앱의 화면, 문서 내용, 영상 제목은 읽지 않습니다."))
            }
        }.font(.subheadline).listStyle(.insetGrouped)
            .scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle(L("백그라운드 및 앱 종료")).navigationBarTitleDisplayMode(.inline)
    }
}
