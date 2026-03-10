import SwiftUI
import UniformTypeIdentifiers

/// A drag-and-drop zone that accepts image files and folders.
struct DropZoneView: View {
    let onDrop: ([URL]) -> Void
    var compact: Bool = false
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 6 : 12)
                .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 6 : 12)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: compact ? 1 : 2, dash: [8, 4])
                        )
                        .foregroundColor(isTargeted ? .accentColor : .gray.opacity(0.3))
                )

            if compact {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Drop more images")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("Drop images here")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("JPEG, PNG, HEIC, TIFF, WebP, BMP, GIF")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        var collectedURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                // If it's a directory, scan for images recursively
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    let imageURLs = Self.findImages(in: url)
                    collectedURLs.append(contentsOf: imageURLs)
                } else if Self.isImageFile(url) {
                    collectedURLs.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            onDrop(collectedURLs)
        }
    }

    /// Supported image file extensions
    private static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "webp", "bmp", "gif"
    ]

    private static func isImageFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Recursively find all image files in a directory.
    private static func findImages(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            if isImageFile(fileURL) {
                results.append(fileURL)
            }
        }
        return results
    }
}
