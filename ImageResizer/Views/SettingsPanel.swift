import SwiftUI

/// Right-side panel with all resize settings.
struct SettingsPanel: View {
    @ObservedObject var settings: ResizeSettings

    /// The file extension to show in the preview
    private var previewExtension: String {
        if settings.outputFormat == .original {
            return "jpg"
        }
        return settings.outputFormat.fileExtension
    }

    private let sectionPadding: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Resize Mode
                VStack(alignment: .leading, spacing: 10) {
                    Text("Resize")
                        .font(.headline)
                        .padding(.bottom, -6)

                    Picker("Mode", selection: $settings.mode) {
                        ForEach(ResizeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    // Mode-specific settings
                    switch settings.mode {
                    case .fixedDimensions:
                        fixedDimensionsSettings
                    case .maxDimension:
                        maxDimensionSettings
                    case .percentage:
                        percentageSettings
                    }
                }
                .padding(sectionPadding)

                Divider()

                // MARK: - Output Format
                VStack(alignment: .leading, spacing: 10) {
                    Text("Output")
                        .font(.headline)

                    Picker("Format", selection: $settings.outputFormat) {
                        ForEach(OutputFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    if settings.outputFormat.supportsQuality || settings.outputFormat == .original {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Quality: \(Int(settings.quality))%")
                                .font(.subheadline)

                            Slider(value: $settings.quality, in: 10...100, step: 5)

                            HStack {
                                Text("Smaller file")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Better quality")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(sectionPadding)

                Divider()

                // MARK: - Filename Template
                VStack(alignment: .leading, spacing: 10) {
                    Text("Filename")
                        .font(.headline)

                    TextField("{name}_resized", text: $settings.filenameTemplate)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 0) {
                        Text("\(FilenameTemplate.resolve(template: settings.filenameTemplate, originalName: "photo", outputWidth: 800, outputHeight: 600, index: 1, formatExtension: previewExtension))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(".\(previewExtension)")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.5))
                    }

                    DisclosureGroup {
                        Text("{name} {width} {height} {date} {index}")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    } label: {
                        Text("Available tokens")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(sectionPadding)

                Divider()

                // MARK: - Metadata
                VStack(alignment: .leading, spacing: 10) {
                    Text("Metadata")
                        .font(.headline)

                    Toggle("Strip EXIF / metadata", isOn: $settings.stripMetadata)
                        .toggleStyle(.checkbox)

                    if settings.stripMetadata {
                        Toggle("Preserve color profile", isOn: $settings.preserveColorProfile)
                            .toggleStyle(.checkbox)
                            .padding(.leading, 18)
                    }
                }
                .padding(sectionPadding)

                Spacer()
            }
        }
        .frame(width: 280)
    }

    // MARK: - Fixed Dimensions

    private var fixedDimensionsSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Width")
                Spacer()
                TextField("px", text: $settings.targetWidth)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("px")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            HStack {
                Text("Height")
                Spacer()
                TextField("px", text: $settings.targetHeight)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("px")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Toggle("Keep aspect ratio", isOn: $settings.keepAspectRatio)
                .toggleStyle(.checkbox)
        }
    }

    // MARK: - Max Dimension

    private var maxDimensionSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Max")
                Spacer()
                TextField("px", text: $settings.maxDimension)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("px")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Text("The longest side will be scaled to this value. Aspect ratio is always preserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Percentage

    private var percentageSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Scale")
                Spacer()
                TextField("%", text: $settings.scalePercentage)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("%")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Text("50% = half size, 200% = double size")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
