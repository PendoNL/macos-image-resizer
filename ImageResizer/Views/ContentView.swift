import SwiftUI

/// Main app view: two-panel layout with drop zone / queue on the left, settings on the right.
struct ContentView: View {
    @StateObject private var settings = ResizeSettings()
    @State private var imageItems: [ImageItem] = []
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var showCompletionAlert = false
    @State private var completionMessage = ""
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    private var hasImages: Bool { !imageItems.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Main content area
            HStack(spacing: 0) {
                // Left panel: drop zone or image queue
                leftPanel
                    .frame(minWidth: 300)

                Divider()

                // Right panel: settings
                SettingsPanel(settings: settings)
            }

            Divider()

            // MARK: - Bottom bar
            bottomBar
        }
        .frame(minWidth: 760, minHeight: 480)
        .alert("Resize Complete", isPresented: $showCompletionAlert) {
            Button("OK") { }
        } message: {
            Text(completionMessage)
        }
        .alert("Invalid Settings", isPresented: $showValidationAlert) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
    }

    // MARK: - Left Panel

    @ViewBuilder
    private var leftPanel: some View {
        if hasImages {
            VStack(spacing: 0) {
                ImageQueueView(items: $imageItems)

                Divider()

                DropZoneView(onDrop: { urls in
                    addImages(from: urls)
                }, compact: true)
                .frame(height: 40)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .disabled(isProcessing)
            }
        } else {
            DropZoneView { urls in
                addImages(from: urls)
            }
            .padding()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if hasImages {
                Button(action: clearQueue) {
                    Label("Clear", systemImage: "xmark")
                }
                .disabled(isProcessing)
            }

            Spacer()

            if isProcessing {
                ProgressView(value: Double(processedCount), total: Double(imageItems.count))
                    .frame(width: 150)

                Text("\(processedCount)/\(imageItems.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            } else {
                Text("\(imageItems.count) image\(imageItems.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: startResize) {
                Label("Resize", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasImages || isProcessing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func addImages(from urls: [URL]) {
        let newItems = urls.map { ImageItem(url: $0) }
        // Avoid duplicates based on file URL
        let existingPaths = Set(imageItems.map { $0.url.path })
        let filtered = newItems.filter { !existingPaths.contains($0.url.path) }
        imageItems.append(contentsOf: filtered)
    }

    private func clearQueue() {
        imageItems.removeAll()
        processedCount = 0
    }

    /// Validate settings before starting the resize.
    private func validateSettings() -> String? {
        switch settings.mode {
        case .fixedDimensions:
            let w = settings.widthValue
            let h = settings.heightValue
            if w <= 0 || h <= 0 {
                return "Width and height must be positive numbers."
            }
            if w > 20000 || h > 20000 {
                return "Width and height must be 20,000 px or less."
            }
        case .maxDimension:
            let m = settings.maxDimensionValue
            if m <= 0 {
                return "Max dimension must be a positive number."
            }
            if m > 20000 {
                return "Max dimension must be 20,000 px or less."
            }
        case .percentage:
            let p = Double(settings.scalePercentage) ?? 0
            if p <= 0 {
                return "Scale percentage must be greater than 0."
            }
            if p > 1000 {
                return "Scale percentage must be 1000% or less."
            }
        }

        if settings.filenameTemplate.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Filename template cannot be empty."
        }

        return nil
    }

    private func startResize() {
        // Validate first
        if let error = validateSettings() {
            validationMessage = error
            showValidationAlert = true
            return
        }

        isProcessing = true
        processedCount = 0

        // Mark all as processing
        for i in imageItems.indices {
            imageItems[i].status = .processing
        }

        Task {
            let resizer = ImageResizeService()

            for i in imageItems.indices {
                let item = imageItems[i]

                let result = await resizer.resize(
                    imageAt: item.url,
                    mode: settings.mode,
                    targetWidth: settings.widthValue,
                    targetHeight: settings.heightValue,
                    keepAspectRatio: settings.keepAspectRatio,
                    maxDimension: settings.maxDimensionValue,
                    scalePercent: settings.scalePercent,
                    outputFormat: settings.outputFormat,
                    quality: settings.qualityNormalized,
                    filenameTemplate: settings.filenameTemplate,
                    index: i + 1,
                    stripMetadata: settings.stripMetadata,
                    preserveColorProfile: settings.preserveColorProfile
                )

                await MainActor.run {
                    switch result {
                    case .success:
                        imageItems[i].status = .completed
                    case .failure(let error):
                        imageItems[i].status = .failed(error.localizedDescription)
                    }
                    processedCount += 1
                }
            }

            await MainActor.run {
                isProcessing = false
                let failedCount = imageItems.filter {
                    if case .failed = $0.status { return true }
                    return false
                }.count

                if failedCount == 0 {
                    completionMessage = "All \(imageItems.count) images resized successfully."
                } else {
                    completionMessage = "\(imageItems.count - failedCount) resized, \(failedCount) failed. Hover over the warning icon to see details."
                }
                showCompletionAlert = true
            }
        }
    }
}
