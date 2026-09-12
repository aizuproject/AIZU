import Foundation
import UIKit
import ImageIO

/// Bounded, metadata-free thumbnails keep user images small in the atomic state file.
enum ArtworkImage {
    static let maximumStoredBytes = 131_072

    static func normalized(_ data: Data) throws -> Data {
        guard data.count <= 20 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 256
              ] as CFDictionary) else {
            throw PresenceFailure.message("20MB 이하의 이미지 파일을 선택하세요.")
        }
        let image = UIImage(cgImage: thumbnail)
        if let png = image.pngData(), png.count <= maximumStoredBytes { return png }
        guard let jpeg = image.jpegData(compressionQuality: 0.8), jpeg.count <= maximumStoredBytes else {
            throw PresenceFailure.message("이미지를 줄이지 못했습니다. 다른 이미지를 선택하세요.")
        }
        return jpeg
    }

    static func remoteURL(_ value: String) throws -> URL? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        guard let url = URL(string: text), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else {
            throw PresenceFailure.message("공개 HTTPS 이미지 주소를 입력하세요.")
        }
        return url
    }
}
