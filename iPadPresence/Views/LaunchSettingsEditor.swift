import SwiftUI

struct LaunchSettingsEditor: View {
    @Binding var method: String
    @Binding var value: String
    var body: some View {
        Section {
            Picker(L("공유 후 실행"), selection: $method) {
                ForEach(LaunchMethod.allCases) { item in Text(L(item.title)).tag(item.rawValue) }
            }.accessibilityIdentifier("launchMethod")
            if method == LaunchMethod.appURL.rawValue {
                TextField(L("앱 URL"), text: $value)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("launchValue")
            } else if method == LaunchMethod.shortcut.rawValue {
                TextField(L("단축어 이름"), text: $value)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("launchValue")
                Text(L("단축어 앱에서 ‘앱 열기’ 동작을 만들고, 그 단축어의 이름을 그대로 입력하세요."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: { Text(L("앱 실행")) }
        footer: {
            Text(method == LaunchMethod.none.rawValue
                 ? L("공유 버튼으로 활동만 시작합니다. 앱도 함께 열려면 실행 방법을 선택하세요.")
                 : L("Discord 전송이 끝나면 실행합니다. HTTPS 링크는 웹페이지로 열릴 수 있습니다. 단축어에는 대상 앱을 여는 동작만 넣고 AIZU 공유 시작을 다시 추가하지 마세요."))
        }
        .onChange(of: method) { _, _ in value = "" }
    }
}
