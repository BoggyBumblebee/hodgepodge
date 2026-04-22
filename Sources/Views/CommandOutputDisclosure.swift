import SwiftUI

struct CommandOutputDisclosure: View {
    let entries: [CommandLogEntry]
    let isRunning: Bool
    let emptyMessage: String
    let title: String
    private let initiallyExpanded: Bool

    @State private var isExpanded = false

    init(
        entries: [CommandLogEntry],
        isRunning: Bool,
        emptyMessage: String,
        title: String = "Command Details",
        initiallyExpanded: Bool = false
    ) {
        self.entries = entries
        self.isRunning = isRunning
        self.emptyMessage = emptyMessage
        self.title = title
        self.initiallyExpanded = initiallyExpanded
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if entries.isEmpty {
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            } else {
                CommandLogConsoleView(entries: entries)
                    .frame(minHeight: 120, maxHeight: 220)
                    .padding(.top, 8)
            }
        } label: {
            HStack(spacing: 10) {
                Text(isExpanded ? "Hide \(title)" : "Show \(title)")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if !entries.isEmpty {
                    Text("\(entries.count) \(entries.count == 1 ? "line" : "lines")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Live")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
        }
        .onAppear {
            isExpanded = initiallyExpanded
        }
    }
}

struct CommandLogConsoleView: View {
    let entries: [CommandLogEntry]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(entries) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)

                            Text(label(for: entry.kind))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(labelColor(for: entry.kind).opacity(0.15), in: Capsule())
                                .foregroundStyle(labelColor(for: entry.kind))

                            Text(entry.text)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .id(entry.id)
                    }
                }
                .padding(12)
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear {
                scrollToLatest(using: proxy)
            }
            .onChange(of: entries.last?.id) { _, _ in
                scrollToLatest(using: proxy)
            }
        }
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let latestID = entries.last?.id else {
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            proxy.scrollTo(latestID, anchor: .bottom)
        }
    }

    private func label(for kind: CommandLogKind) -> String {
        switch kind {
        case .system:
            "SYSTEM"
        case .stdout:
            "STDOUT"
        case .stderr:
            "STDERR"
        }
    }

    private func labelColor(for kind: CommandLogKind) -> Color {
        switch kind {
        case .system:
            .secondary
        case .stdout:
            .blue
        case .stderr:
            .red
        }
    }
}
