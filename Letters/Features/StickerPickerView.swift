// Session-local sticker selection/import. Image limits protect memory; encrypted delivery and persistent packs are not connected.

import SwiftUI
import UniformTypeIdentifiers
import ImageIO
import UIKit

struct PreviewSticker: Identifiable {
    let id: String
    let name: String
    let symbol: String?
    let imageData: Data?

    static let orbitPack: [PreviewSticker] = [
        .init(id: "orbit.hello", name: "Cosmic hello", symbol: "hand.wave.fill", imageData: nil),
        .init(id: "orbit.love", name: "Stellar love", symbol: "heart.fill", imageData: nil),
        .init(id: "orbit.moon", name: "Over the moon", symbol: "moon.stars.fill", imageData: nil),
        .init(id: "orbit.sparkle", name: "Stardust", symbol: "sparkles", imageData: nil),
        .init(id: "orbit.world", name: "My whole world", symbol: "globe.americas.fill", imageData: nil),
        .init(id: "orbit.star", name: "You're a star", symbol: "star.fill", imageData: nil)
    ]
}

struct StickerArtwork: View {
    let sticker: PreviewSticker
    var body: some View {
        Group {
            if let data = sticker.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ZStack {
                    Circle().fill(LettersTheme.violet.opacity(0.16))
                    Ellipse().stroke(LettersTheme.violet, lineWidth: 2)
                        .rotationEffect(.degrees(-30)).padding(6)
                    Image(systemName: sticker.symbol ?? "star.fill")
                        .font(.system(size: 34)).foregroundStyle(LettersTheme.accent)
                }.padding(6)
            }
        }.accessibilityLabel("Sticker: \(sticker.name)")
    }
}

struct StickerPickerView: View {
    let select: (PreviewSticker) -> Void
    @EnvironmentObject private var store: PreviewStore
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var importError: String?
    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("A little more you. A little more universe.")
                        .font(.headline).foregroundStyle(LettersTheme.secondary)
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(store.stickers) { sticker in
                            Button { select(sticker) } label: {
                                VStack(spacing: 8) {
                                    StickerArtwork(sticker: sticker).frame(height: 84)
                                    Text(sticker.name).font(.caption).foregroundStyle(.white)
                                }
                            }.accessibilityLabel("Add \(sticker.name) to sample chat")
                        }
                    }
                    Button { importing = true } label: {
                        Label("Add your own sticker", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.bordered)
                        .disabled(store.stickers.count >= 26)
                    Text("PNG or JPEG · up to 2 MB and 2048 × 2048 pixels. Imported stickers stay in this preview session only. Animated stickers and whole-pack imports are planned.")
                        .font(.footnote).foregroundStyle(LettersTheme.secondary)
                }.padding(24)
            }.background(OrbitBackdrop()).navigationTitle("Orbit stickers")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.png, .jpeg]) { result in
                    switch result {
                    case .success(let url): importSticker(url)
                    case .failure(let error):
                        if (error as NSError).code != NSUserCancelledError { importError = error.localizedDescription }
                    }
                }
                .alert("Couldn't add that sticker", isPresented: Binding(
                    get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                        Button("OK") { importError = nil }
                    } message: { Text(importError ?? "Choose another image.") }
        }
    }

    private func importSticker(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            guard store.stickers.count < 26 else { throw StickerImportError.limit }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size > 0, size <= 2_000_000 else { throw StickerImportError.size }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 2_000_000,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let type = CGImageSourceGetType(source),
                  [UTType.png.identifier, UTType.jpeg.identifier].contains(type as String),
                  CGImageSourceGetCount(source) == 1,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 2048, height <= 2048,
                  UIImage(data: data) != nil else { throw StickerImportError.format }
            let name = String(url.deletingPathExtension().lastPathComponent.prefix(40))
            store.stickers.append(.init(id: UUID().uuidString, name: name.isEmpty ? "My sticker" : name,
                                        symbol: nil, imageData: data))
        } catch { importError = error.localizedDescription }
    }
}

private enum StickerImportError: LocalizedError {
    case size, format, limit
    var errorDescription: String? {
        switch self {
        case .size: return "Choose a PNG or JPEG smaller than 2 MB."
        case .format: return "Choose a still PNG or JPEG no larger than 2048 × 2048 pixels."
        case .limit: return "This preview supports up to 20 imported stickers per session."
        }
    }
}
