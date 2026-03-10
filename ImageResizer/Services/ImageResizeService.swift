import Foundation
import AppKit
import CoreImage
import ImageIO

/// Handles the actual image resizing, format conversion, and metadata stripping.
actor ImageResizeService {

    enum ResizeError: LocalizedError {
        case cannotLoadImage
        case cannotCreateBitmap
        case cannotWriteFile(String)
        case invalidSettings(String)
        case unsupportedFormat(String)

        var errorDescription: String? {
            switch self {
            case .cannotLoadImage:
                return "Could not load the image file."
            case .cannotCreateBitmap:
                return "Could not create a resized bitmap."
            case .cannotWriteFile(let reason):
                return "Could not save the file: \(reason)"
            case .invalidSettings(let reason):
                return "Invalid settings: \(reason)"
            case .unsupportedFormat(let format):
                return "Unsupported output format: \(format)"
            }
        }
    }

    /// The result of a successful resize, including the output dimensions.
    struct ResizeResult {
        let outputURL: URL
        let width: Int
        let height: Int
    }

    /// Resize an image, convert format, optionally strip metadata, and save.
    func resize(
        imageAt sourceURL: URL,
        mode: ResizeMode,
        targetWidth: Int,
        targetHeight: Int,
        keepAspectRatio: Bool,
        maxDimension: Int,
        scalePercent: Double,
        outputFormat: OutputFormat,
        quality: CGFloat,
        filenameTemplate: String,
        index: Int,
        stripMetadata: Bool,
        preserveColorProfile: Bool
    ) -> Result<ResizeResult, ResizeError> {

        // 1. Load the source image
        guard let sourceImage = NSImage(contentsOf: sourceURL),
              let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .failure(.cannotLoadImage)
        }

        // 2. Calculate output dimensions based on mode
        let originalWidth = cgImage.width
        let originalHeight = cgImage.height
        var outWidth: Int
        var outHeight: Int

        switch mode {
        case .fixedDimensions:
            outWidth = targetWidth
            outHeight = targetHeight

            if keepAspectRatio {
                let widthRatio = Double(targetWidth) / Double(originalWidth)
                let heightRatio = Double(targetHeight) / Double(originalHeight)
                let ratio = min(widthRatio, heightRatio)
                outWidth = max(1, Int(Double(originalWidth) * ratio))
                outHeight = max(1, Int(Double(originalHeight) * ratio))
            }

        case .maxDimension:
            let longestSide = max(originalWidth, originalHeight)
            if longestSide <= maxDimension {
                outWidth = originalWidth
                outHeight = originalHeight
            } else {
                let ratio = Double(maxDimension) / Double(longestSide)
                outWidth = max(1, Int(Double(originalWidth) * ratio))
                outHeight = max(1, Int(Double(originalHeight) * ratio))
            }

        case .percentage:
            guard scalePercent > 0 else {
                return .failure(.invalidSettings("Scale percentage must be greater than 0."))
            }
            outWidth = max(1, Int(Double(originalWidth) * scalePercent))
            outHeight = max(1, Int(Double(originalHeight) * scalePercent))
        }

        // 3. Create the resized image using CoreGraphics
        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: outWidth,
                height: outHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return .failure(.cannotCreateBitmap)
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: outWidth, height: outHeight))

        guard let resizedCGImage = context.makeImage() else {
            return .failure(.cannotCreateBitmap)
        }

        // 4. Determine the output format and file extension
        let resolvedFormat: OutputFormat
        if outputFormat == .original {
            resolvedFormat = Self.detectFormat(from: sourceURL)
        } else {
            resolvedFormat = outputFormat
        }

        let ext = resolvedFormat.fileExtension

        // 5. Build the output filename using the template
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let resolvedName = FilenameTemplate.resolve(
            template: filenameTemplate,
            originalName: baseName,
            outputWidth: outWidth,
            outputHeight: outHeight,
            index: index,
            formatExtension: ext
        )

        let directory = sourceURL.deletingLastPathComponent()
        let outputURL = directory
            .appendingPathComponent(resolvedName)
            .appendingPathExtension(ext)

        // 6. Read source metadata (if we need to preserve some of it)
        var sourceMetadata: [String: Any]?
        if !stripMetadata {
            if let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) {
                sourceMetadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
            }
        }

        // 7. Encode and write using ImageIO (supports all formats + metadata control)
        let writeResult = writeImage(
            resizedCGImage,
            to: outputURL,
            format: resolvedFormat,
            quality: quality,
            metadata: sourceMetadata,
            stripMetadata: stripMetadata,
            preserveColorProfile: preserveColorProfile
        )

        switch writeResult {
        case .success:
            return .success(ResizeResult(outputURL: outputURL, width: outWidth, height: outHeight))
        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - Private helpers

    /// Write a CGImage to disk in the specified format with metadata control.
    private func writeImage(
        _ image: CGImage,
        to url: URL,
        format: OutputFormat,
        quality: CGFloat,
        metadata: [String: Any]?,
        stripMetadata: Bool,
        preserveColorProfile: Bool
    ) -> Result<Void, ResizeError> {

        let utType: CFString
        switch format {
        case .jpeg: utType = "public.jpeg" as CFString
        case .png: utType = "public.png" as CFString
        case .heic: utType = "public.heic" as CFString
        case .tiff: utType = "public.tiff" as CFString
        case .original: utType = "public.jpeg" as CFString // fallback
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, utType, 1, nil) else {
            return .failure(.cannotWriteFile("Could not create image destination."))
        }

        // Build properties dictionary
        var properties: [CFString: Any] = [:]

        // Quality for lossy formats
        if format.supportsQuality {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }

        // Handle metadata
        if let metadata = metadata, !stripMetadata {
            // Copy metadata but optionally strip specific keys
            var filteredMetadata = metadata

            if stripMetadata {
                // Remove all metadata
                filteredMetadata.removeAll()
            }

            // If preserving color profile, keep the ICC profile data
            if !preserveColorProfile {
                filteredMetadata.removeValue(forKey: kCGImagePropertyProfileName as String)
            }

            // Merge filtered metadata into properties
            for (key, value) in filteredMetadata {
                properties[key as CFString] = value
            }
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        if CGImageDestinationFinalize(destination) {
            return .success(())
        } else {
            return .failure(.cannotWriteFile("Failed to finalize the image file."))
        }
    }

    /// Detect the original image format from the file extension.
    private static func detectFormat(from url: URL) -> OutputFormat {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic", "heif": return .heic
        case "tiff", "tif": return .tiff
        default: return .jpeg // fallback
        }
    }
}
