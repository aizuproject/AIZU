import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ArtworkEditor: View {
    @Binding var localImage: Data?
    @Binding var imageURL: String
    @State private var photo: PhotosPickerItem?
    @State private var selectingFile = false
    @State private var loading = false
    @State private var failure: String?

    var body: some View {
        Section {
            HStack(spacing: 14) {
                AppIconView(application: PresenceApp(name: "A", artworkURL: try? ArtworkImage.remoteURL(imageURL), localArtwork: localImage), size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("활동 이미지")).font(.subheadline.weight(.medium))
                    Text(localImage == nil ? L("이름 옆에 표시할 아이콘") : L("기기에 저장된 이미지"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if loading { Spacer(); ProgressView() }
            }
            PhotosPicker(selection: $photo, matching: .images) {
                Label(L("사진에서 선택"), systemImage: "photo")
            }.disabled(loading).accessibilityIdentifier("chooseArtworkPhoto")
            Button { selectingFile = true } label: {
                Label(L("파일에서 선택"), systemImage: "folder")
            }.disabled(loading).accessibilityIdentifier("chooseArtworkFile")
            TextField(L("Discord 이미지 URL"), text: $imageURL)
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityLabel(L("Discord 이미지 URL")).accessibilityIdentifier("artworkURL")
            if localImage != nil {
                Button(L("기기 이미지 제거"), role: .destructive) { localImage = nil; photo = nil }
            }
            if !imageURL.isEmpty {
                Button(L("이미지 URL 제거"), role: .destructive) { imageURL = "" }
            }
            if let failure { Text(L(failure)).font(.caption).foregroundStyle(.red) }
        } header: { Text(L("이미지")) }
        footer: {
            Text(L("기기 이미지는 AIZU에 저장됩니다. Discord에도 이미지를 표시하려면 로그인 없이 열리는 HTTPS 이미지 URL을 입력하세요. URL이 있으면 미리보기에도 해당 이미지를 사용합니다."))
        }
        .fileImporter(isPresented: $selectingFile, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 20 * 1024 * 1024 else { throw PresenceFailure.message(L("20MB 이하의 이미지를 선택하세요.")) }
                localImage = try ArtworkImage.normalized(Data(contentsOf: url)); failure = nil
            } catch { failure = error.localizedDescription }
        }
        .task(id: photo) {
            guard let photo else { return }
            loading = true; failure = nil
            defer { loading = false }
            do {
                guard let data = try await photo.loadTransferable(type: Data.self) else {
                    throw PresenceFailure.message(L("사진을 읽지 못했습니다."))
                }
                try Task.checkCancellation()
                localImage = try ArtworkImage.normalized(data)
            } catch is CancellationError { }
            catch { failure = error.localizedDescription }
        }
    }
}
