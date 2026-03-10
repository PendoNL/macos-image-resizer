import Foundation
import Combine

/// The available resize modes.
enum ResizeMode: String, CaseIterable, Identifiable {
    case fixedDimensions = "Fixed"
    case maxDimension = "Max Dimension"
    case percentage = "Percentage"

    var id: String { rawValue }
}

/// Output format options.
enum OutputFormat: String, CaseIterable, Identifiable {
    case original = "Original"
    case jpeg = "JPEG"
    case png = "PNG"
    case heic = "HEIC"
    case tiff = "TIFF"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .original: return "" // determined at runtime
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .tiff: return "tiff"
        }
    }

    /// Whether this format supports a quality slider
    var supportsQuality: Bool {
        switch self {
        case .jpeg, .heic: return true
        case .png, .tiff, .original: return false
        }
    }
}

/// All configuration for a resize batch.
/// Persists settings to UserDefaults so they survive app restarts.
class ResizeSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Key {
        static let mode = "resizeMode"
        static let targetWidth = "targetWidth"
        static let targetHeight = "targetHeight"
        static let keepAspectRatio = "keepAspectRatio"
        static let maxDimension = "maxDimension"
        static let scalePercentage = "scalePercentage"
        static let outputFormat = "outputFormat"
        static let quality = "quality"
        static let filenameTemplate = "filenameTemplate"
        static let stripMetadata = "stripMetadata"
        static let preserveColorProfile = "preserveColorProfile"
    }

    // MARK: - Resize mode
    @Published var mode: ResizeMode = .fixedDimensions {
        didSet { defaults.set(mode.rawValue, forKey: Key.mode) }
    }

    // MARK: - Fixed dimensions
    @Published var targetWidth: String = "800" {
        didSet { defaults.set(targetWidth, forKey: Key.targetWidth) }
    }
    @Published var targetHeight: String = "600" {
        didSet { defaults.set(targetHeight, forKey: Key.targetHeight) }
    }
    @Published var keepAspectRatio: Bool = true {
        didSet { defaults.set(keepAspectRatio, forKey: Key.keepAspectRatio) }
    }

    // MARK: - Max dimension
    @Published var maxDimension: String = "1200" {
        didSet { defaults.set(maxDimension, forKey: Key.maxDimension) }
    }

    // MARK: - Percentage
    @Published var scalePercentage: String = "50" {
        didSet { defaults.set(scalePercentage, forKey: Key.scalePercentage) }
    }

    // MARK: - Output format
    @Published var outputFormat: OutputFormat = .jpeg {
        didSet { defaults.set(outputFormat.rawValue, forKey: Key.outputFormat) }
    }
    @Published var quality: Double = 85 {
        didSet { defaults.set(quality, forKey: Key.quality) }
    }

    // MARK: - Filename template
    @Published var filenameTemplate: String = "{name}_resized" {
        didSet { defaults.set(filenameTemplate, forKey: Key.filenameTemplate) }
    }

    // MARK: - Metadata
    @Published var stripMetadata: Bool = false {
        didSet { defaults.set(stripMetadata, forKey: Key.stripMetadata) }
    }
    @Published var preserveColorProfile: Bool = true {
        didSet { defaults.set(preserveColorProfile, forKey: Key.preserveColorProfile) }
    }

    // MARK: - Computed
    var widthValue: Int { Int(targetWidth) ?? 800 }
    var heightValue: Int { Int(targetHeight) ?? 600 }
    var maxDimensionValue: Int { Int(maxDimension) ?? 1200 }
    var scalePercent: Double { (Double(scalePercentage) ?? 50) / 100.0 }
    var qualityNormalized: CGFloat { CGFloat(quality) / 100.0 }

    // MARK: - Init (load saved settings)
    init() {
        if let modeRaw = defaults.string(forKey: Key.mode),
           let savedMode = ResizeMode(rawValue: modeRaw) {
            self.mode = savedMode
        }
        if let w = defaults.string(forKey: Key.targetWidth), !w.isEmpty {
            self.targetWidth = w
        }
        if let h = defaults.string(forKey: Key.targetHeight), !h.isEmpty {
            self.targetHeight = h
        }
        if defaults.object(forKey: Key.keepAspectRatio) != nil {
            self.keepAspectRatio = defaults.bool(forKey: Key.keepAspectRatio)
        }
        if let m = defaults.string(forKey: Key.maxDimension), !m.isEmpty {
            self.maxDimension = m
        }
        if let s = defaults.string(forKey: Key.scalePercentage), !s.isEmpty {
            self.scalePercentage = s
        }
        if let fmtRaw = defaults.string(forKey: Key.outputFormat),
           let savedFormat = OutputFormat(rawValue: fmtRaw) {
            self.outputFormat = savedFormat
        }
        if defaults.object(forKey: Key.quality) != nil {
            self.quality = defaults.double(forKey: Key.quality)
        }
        if let tmpl = defaults.string(forKey: Key.filenameTemplate), !tmpl.isEmpty {
            self.filenameTemplate = tmpl
        }
        if defaults.object(forKey: Key.stripMetadata) != nil {
            self.stripMetadata = defaults.bool(forKey: Key.stripMetadata)
        }
        if defaults.object(forKey: Key.preserveColorProfile) != nil {
            self.preserveColorProfile = defaults.bool(forKey: Key.preserveColorProfile)
        }
    }
}
