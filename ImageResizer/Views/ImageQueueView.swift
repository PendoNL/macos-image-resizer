import SwiftUI

/// Displays the list of queued images with thumbnail, name, size, and status.
struct ImageQueueView: View {
    @Binding var items: [ImageItem]

    var body: some View {
        List {
            ForEach(items) { item in
                HStack(spacing: 10) {
                    // Thumbnail
                    if let thumb = item.thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            )
                    }

                    // File info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.filename)
                            .font(.system(.body, design: .default))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        HStack(spacing: 8) {
                            Text(item.dimensionsText)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(item.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Show error inline
                            if case .failed(let message) = item.status {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }

                    Spacer()

                    // Status indicator
                    statusView(for: item.status)
                }
                .padding(.vertical, 2)
            }
            .onDelete { indexSet in
                items.remove(atOffsets: indexSet)
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func statusView(for status: ImageItem.ProcessingStatus) -> some View {
        switch status {
        case .queued:
            Image(systemName: "clock")
                .foregroundColor(.secondary)
                .font(.caption)
        case .processing:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .failed(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)
                .help(message)
        }
    }
}
