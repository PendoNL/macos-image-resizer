import Foundation

/// Parses filename templates with tokens like {name}, {width}, {height}, {date}, {index}, {format}.
struct FilenameTemplate {

    /// Resolve a template string into a final filename (without extension).
    static func resolve(
        template: String,
        originalName: String,
        outputWidth: Int,
        outputHeight: Int,
        index: Int,
        formatExtension: String
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        var result = template
        result = result.replacingOccurrences(of: "{name}", with: originalName)
        result = result.replacingOccurrences(of: "{width}", with: "\(outputWidth)")
        result = result.replacingOccurrences(of: "{height}", with: "\(outputHeight)")
        result = result.replacingOccurrences(of: "{date}", with: dateString)
        result = result.replacingOccurrences(of: "{index}", with: String(format: "%03d", index))
        result = result.replacingOccurrences(of: "{format}", with: formatExtension)

        return result
    }

    /// Preview what a template would produce, using sample values.
    static func preview(template: String, formatExtension: String) -> String {
        let resolved = resolve(
            template: template,
            originalName: "photo",
            outputWidth: 800,
            outputHeight: 600,
            index: 1,
            formatExtension: formatExtension
        )
        return "\(resolved).\(formatExtension)"
    }
}
