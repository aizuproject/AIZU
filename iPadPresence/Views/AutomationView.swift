import SwiftUI

struct AutomationView: View {
    @Bindable var controller: PresenceController
    @Environment(\.openURL) private var openURL
    var body: some View {
        List {
            Section {
                Text(L("앱을 열고 닫을 때 공유")).font(.headline)
                Text(L("앱을 열면 공유와 연결 유지를 시작하고, 닫으면 함께 종료합니다."))
                    .font(.subheadline).foregroundStyle(.secondary)
                Button { openURL(URL(string: "shortcuts://")!) } label: {
                    Label(L("단축어 열기"), systemImage: "arrow.up.forward.app")
                }
            }
            Section(L("설정 순서")) {
                instruction(1, title: L("열릴 때 → 공유 시작"), detail: L("자동화 → 앱 → 대상 앱 → 열릴 때 → 즉시 실행. AIZU의 ‘앱 활동 시작’에 같은 앱을 지정하세요."))
                instruction(2, title: L("닫힐 때 → 공유 종료"), detail: L("자동화를 하나 더 만들고 ‘닫힐 때 → 즉시 실행’을 선택한 뒤 ‘앱 활동 종료’를 추가하세요."))
                instruction(3, title: L("시작·종료 확인"), detail: L("AIZU에서 활동 공유를 켜고 대상 앱을 열었다 닫아 보세요. 시작 시 연결 유지가 자동으로 켜집니다. 시작이 거절되면 AIZU를 열어 공유를 시작하세요. 아래에서 전달된 시각을 확인할 수 있습니다."))
            }
            Section {
                ForEach(controller.state.apps) { application in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(application.name).font(.subheadline.weight(.semibold))
                        event(L("열림"), date: application.lastOpened)
                        event(L("닫힘"), date: application.lastClosed)
                    }.padding(.vertical, 4)
                }
                if controller.state.apps.isEmpty {
                    Text(L("앱을 등록하면 수신 기록이 표시됩니다.")).font(.subheadline).foregroundStyle(.secondary)
                }
            } header: { Text(L("자동화 수신 기록")) }
            footer: { Text(L("‘닫힐 때’는 다른 앱으로 전환한 경우도 포함합니다. 닫힘 자동화가 전달되지 않으면 공유가 남을 수 있습니다. 그때는 AIZU에서 직접 종료하세요.")) }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden)
    }
    private func instruction(_ number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                .frame(width: 24, height: 24).background(Palette.accent.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.vertical, 6)
    }
    private func event(_ title: String, date: Date?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let date { Text(date, format: .dateTime.month().day().hour().minute().second()).monospacedDigit() }
            else { Text(L("수신 기록 없음")) }
        }.font(.caption).foregroundStyle(.secondary)
    }
}
