import SwiftUI

enum Palette {
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.72, green: 0.68, blue: 1, alpha: 1)
        : UIColor(red: 0.36, green: 0.30, blue: 0.70, alpha: 1) })
    static let button = Color(red: 0.36, green: 0.30, blue: 0.70)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let line = Color(uiColor: .separator).opacity(0.3)
}

struct AizuBrand: View {
    var size: CGFloat = 40
    var body: some View {
        Image("AizuLogo").resizable().scaledToFit().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22)).accessibilityHidden(true)
    }
}

struct AppIconView: View {
    let application: PresenceApp
    var size: CGFloat = 44
    var onDarkBackground = false
    var body: some View {
        Group {
            if application.artworkURL == nil, let data = application.localArtwork, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
            AsyncImage(url: application.artworkURL) { image in image.resizable().scaledToFill() } placeholder: {
                ZStack {
                    (onDarkBackground ? Color.white : Palette.accent).opacity(onDarkBackground ? 0.12 : 0.09)
                    Text(String(application.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.43, weight: .semibold))
                        .foregroundStyle(onDarkBackground ? .white : Palette.accent)
                }
            }
            }
        }.frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.23))
            .overlay(RoundedRectangle(cornerRadius: size * 0.23).strokeBorder(Palette.line, lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}

struct StatusPill: View {
    let text: String
    var active = false
    var body: some View {
        Label {
            Text(L(text)).font(.caption.weight(.medium))
        } icon: {
            Circle().fill(active ? Color.green : Color.secondary).frame(width: 6, height: 6)
        }.foregroundStyle(.secondary)
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16).padding(.vertical, 12)
            .foregroundStyle(.white).background(Palette.button, in: RoundedRectangle(cornerRadius: 10))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
    }
}

struct DiscordPreviewCard: View {
    let application: PresenceApp?
    let session: PresenceSession?
    var delivery: DeliveryState = .idle
    var isBusy = false
    var needsRemoteClear = false
    var runtimeStatus: String?
    var runtimeRunning = false
    var stop: () -> Void = {}
    var retry: () -> Void = {}
    private let secondaryText = Color.white.opacity(0.78)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("DISCORD").font(.caption2.weight(.bold)).tracking(2.3)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 8)
                Text(L("표시 미리보기")).font(.caption2).foregroundStyle(secondaryText)
            }
            Rectangle().fill(.white.opacity(0.15)).frame(height: 1).padding(.top, 18)

            HStack(alignment: .center, spacing: 16) {
                if let application, let session {
                    AppIconView(application: application, size: 50, onDarkBackground: true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(application.name).font(.headline).foregroundStyle(.white)
                        if application.artworkURL == nil && application.localArtwork != nil {
                            Text(L("이미지는 이 기기에만 표시됩니다")).font(.caption2).foregroundStyle(secondaryText)
                        }
                        if !application.details.isEmpty {
                            Text(application.details).font(.subheadline).foregroundStyle(secondaryText)
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { activityMetadata(application, session: session) }
                            VStack(alignment: .leading, spacing: 5) { activityMetadata(application, session: session) }
                        }.font(.caption).foregroundStyle(secondaryText)
                    }
                } else {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 29, weight: .light))
                        .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.79))
                        .frame(width: 36).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(L("지금은 쉬는 중")).font(.headline).foregroundStyle(.white)
                        Text(L("아래에서 앱을 골라 공유를 시작하세요."))
                            .font(.subheadline).foregroundStyle(secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 76, alignment: .center)
            .padding(.vertical, 21)

            Text(L("실제 표시 형태는 Discord 설정과 클라이언트에 따라 달라집니다."))
                .font(.caption2).foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
            if session != nil || needsRemoteClear || isFailure {
                Rectangle().fill(.white.opacity(0.15)).frame(height: 1).padding(.vertical, 16)
                HStack(spacing: 12) {
                    Label(L(delivery.title), systemImage: delivery == .submitted ? "checkmark.circle" : "circle.dotted")
                        .font(.caption).foregroundStyle(secondaryText)
                    Spacer(minLength: 8)
                    if session != nil {
                        Button(action: stop) { Text(L("공유 종료")).font(.subheadline.weight(.semibold)) }
                            .buttonStyle(.bordered).tint(.white)
                            .accessibilityIdentifier("stopCurrent")
                    }
                }
                if let runtimeStatus, session != nil {
                    Label(L(runtimeStatus), systemImage: runtimeRunning ? "waveform" : "exclamationmark.circle")
                        .font(.caption).foregroundStyle(secondaryText)
                        .padding(.top, 10).accessibilityIdentifier("runtimeStatus")
                    if !runtimeRunning {
                        Button(L("연결 유지 다시 시도"), action: retry)
                            .font(.caption.weight(.semibold)).buttonStyle(.bordered).tint(.white)
                            .disabled(isBusy).padding(.top, 8)
                    }
                }
                if case .failed(let message) = delivery {
                    Text(L(message)).font(.caption).foregroundStyle(Color(red: 1, green: 0.86, blue: 0.79))
                        .padding(.top, 10)
                }
                if isFailure || (session == nil && needsRemoteClear) {
                    Button(needsRemoteClear && session == nil ? L("이전 활동 정리 다시 시도") : L("전송 다시 시도"), action: retry)
                        .font(.subheadline).buttonStyle(.bordered).tint(.white)
                        .disabled(isBusy).padding(.top, 10)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.22, green: 0.29, blue: 0.47),
                                               Color(red: 0.14, green: 0.18, blue: 0.32)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("discordPreview")
    }

    private var isFailure: Bool { if case .failed = delivery { true } else { false } }

    @ViewBuilder
    private func activityMetadata(_ application: PresenceApp, session: PresenceSession) -> some View {
        Text(L(application.activityKind.title))
        if application.showElapsedTime {
            Text(session.startedAt, style: .timer).monospacedDigit()
                .fixedSize().accessibilityLabel(L("경과 시간"))
        }
    }
}

struct AppActivityRow: View {
    let application: PresenceApp
    @Bindable var controller: PresenceController
    var body: some View {
        HStack(spacing: 12) {
            AppIconView(application: application)
            VStack(alignment: .leading, spacing: 3) {
                Text(application.name).font(.body.weight(.medium)).lineLimit(2)
                Text(application.enabled ? L(application.activityKind.title) : L("공유 비활성화"))
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if controller.state.session?.appID == application.id {
                if application.opensAfterSharing {
                    Button(L("열기")) { Task { await controller.shareAndLaunch(application.id) } }
                        .font(.subheadline.weight(.semibold)).buttonStyle(.bordered)
                        .disabled(controller.launchingAppID == application.id)
                        .accessibilityIdentifier("open.\(application.name)")
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accent)
                        .accessibilityLabel(L("현재 선택한 앱"))
                }
            } else {
                Button(application.opensAfterSharing ? L("공유하고 열기") : L("공유")) { Task { await controller.shareAndLaunch(application.id) } }
                    .font(.subheadline.weight(.semibold)).buttonStyle(.bordered)
                    .disabled(!controller.state.sharingEnabled || !application.enabled || controller.launchingAppID == application.id)
                    .accessibilityLabel(L("\(application.name) 공유"))
                    .accessibilityIdentifier("start.\(application.name)")
            }
        }.padding(.vertical, 4)
    }
}
