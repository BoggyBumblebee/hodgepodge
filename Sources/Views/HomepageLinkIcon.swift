import SwiftUI

private struct HeaderLinkIcon: View {
    let url: URL
    let systemImage: String
    let helpText: String
    let accessibilityLabel: String

    var body: some View {
        Link(destination: url) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct HomepageLinkIcon: View {
    let url: URL
    let accessibilityLabel: String

    var body: some View {
        HeaderLinkIcon(
            url: url,
            systemImage: "safari",
            helpText: "Open Homepage",
            accessibilityLabel: accessibilityLabel
        )
    }
}

struct DownloadLinkIcon: View {
    let url: URL
    let accessibilityLabel: String

    var body: some View {
        HeaderLinkIcon(
            url: url,
            systemImage: "arrow.down.circle",
            helpText: "Open Download",
            accessibilityLabel: accessibilityLabel
        )
    }
}
