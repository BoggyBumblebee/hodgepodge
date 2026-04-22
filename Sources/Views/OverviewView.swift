import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Homebrew installation details, health, and quick-access help.")
                    .foregroundStyle(.secondary)

                statusCard

                if let helpURL = model.lastOpenedHelpURL {
                    Text("Last opened help page: \(helpURL.absoluteString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.refreshInstallation()
                } label: {
                    Label("Refresh Homebrew", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button {
                    model.openHelp(anchor: .quickStart)
                } label: {
                    Label("Quick Start Help", systemImage: "questionmark.circle")
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
            }
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        switch model.installationState {
        case .idle, .loading:
            ProgressView("Detecting Homebrew...")
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .failed(let message):
            ContentUnavailableView("Homebrew Not Ready", systemImage: "exclamationmark.triangle", description: Text(message))

        case .loaded(let installation):
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                row("Executable", installation.brewPath)
                row("Version", installation.version)
                row("Prefix", installation.prefix)
                row("Cellar", installation.cellar)
                row("Repository", installation.repository)
                row("Tap Count", "\(installation.taps.count)")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 2)
            )
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
