import Foundation
import AppKit

/// Represents a single image in the processing queue.
struct ImageItem: Identifiable {
    let id = UUID()
    let url: URL
    let filename: String
    let fileSize: Int64
    var width: Int = 0
    var height: Int = 0
    var status: ProcessingStatus = .queued
    var thumbnail: NSImage?

    enum ProcessingStatus: Equatable {
        case queued
        case processing
        case completed
        case failed(String)
    }

    /// Human-readable file size
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// Dimensions as a string like "1920 × 1080"
    var dimensionsText: String {
        if width > 0 && height > 0 {
            return "\(width) × \(height)"
        }
        return "—"
    }

    /// Create an ImageItem from a file URL, reading dimensions and generating a thumbnail.
    init(url: URL) {
        self.url = url
        self.filename = url.lastPathComponent
        self.fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        // Read image dimensions without loading the full image into memory
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
            self.width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
            self.height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        }

        // Generate a small thumbnail
        if let image = NSImage(contentsOf: url) {
            let thumbSize = NSSize(width: 40, height: 40)
            let thumb = NSImage(size: thumbSize)
            thumb.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: thumbSize),
                       from: NSRect(origin: .zero, size: image.size),
                       operation: .copy,
                       fraction: 1.0)
            thumb.unlockFocus()
            self.thumbnail = thumb
        }
    }
}
