import AppKit
import SwiftUI

struct CommandPreviewField: View {
    let title: String?
    let command: String
    let copyAccessibilityLabel: String
    let lineLimit: Int?

    init(
        title: String? = nil,
        command: String,
        copyAccessibilityLabel: String = "Copy command",
        lineLimit: Int? = nil
    ) {
        self.title = title
        self.command = command
        self.copyAccessibilityLabel = copyAccessibilityLabel
        self.lineLimit = lineLimit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 8) {
                Text(command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(lineLimit)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Button(action: copyToPasteboard) {
                    Image(systemName: "doc.on.doc")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel(copyAccessibilityLabel)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
    }

    private func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
    }
}
