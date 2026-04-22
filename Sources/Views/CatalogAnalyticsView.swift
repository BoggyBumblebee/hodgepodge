import SwiftUI

struct CatalogAnalyticsView: View {
    @ObservedObject var viewModel: CatalogViewModel
    @ObservedObject var installedPackagesViewModel: InstalledPackagesViewModel
    let openInstalledPackage: (CatalogAnalyticsItem) -> Void
    let openPackageInCatalog: (CatalogAnalyticsItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                analyticsContent
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            viewModel.loadAnalyticsIfNeeded()
            installedPackagesViewModel.loadIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Public Homebrew leaderboard data from the official analytics API.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Picker("Analytics Window", selection: analyticsPeriodBinding) {
                    ForEach(CatalogAnalyticsPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .accessibilityLabel("Analytics period")

                Button("Refresh Analytics") {
                    viewModel.refreshAnalytics()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var analyticsContent: some View {
        switch viewModel.analyticsState {
        case .idle, .loading:
            ProgressView("Loading analytics...")
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 300, alignment: .center)

        case .failed(_, let message):
            ContentUnavailableView(
                "Analytics Unavailable",
                systemImage: "chart.bar.xaxis",
                description: Text(message)
            )

        case .loaded(let snapshot):
            VStack(alignment: .leading, spacing: 16) {
                Text("Showing \(snapshot.period.title.lowercased()) of public install and build-error trends.")
                    .font(.headline)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)],
                    spacing: 16
                ) {
                    ForEach(snapshot.leaderboards) { leaderboard in
                        analyticsLeaderboardCard(leaderboard)
                    }
                }
            }
        }
    }

    private var analyticsPeriodBinding: Binding<CatalogAnalyticsPeriod> {
        Binding(
            get: { viewModel.analyticsPeriod },
            set: { viewModel.setAnalyticsPeriod($0) }
        )
    }

    private func analyticsLeaderboardCard(_ leaderboard: CatalogAnalyticsLeaderboard) -> some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(leaderboard.title)
                        .font(.headline)

                    Spacer()

                    Text(leaderboard.totalCount)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(leaderboard.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(leaderboard.dateRangeSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Divider()

                if leaderboard.items.isEmpty {
                    Text("No analytics entries are available for this period.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(leaderboard.items.prefix(10))) { item in
                        analyticsItemRow(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func analyticsItemRow(_ item: CatalogAnalyticsItem) -> some View {
        let isInstalled = installedPackagesViewModel.isInstalled(item)
        let content = HStack(spacing: 10) {
            Text(item.rank > 0 ? "\(item.rank)." : "•")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                Text(item.kind.title.dropLast())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isInstalled {
                Text("Installed")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.14), in: Capsule())
                    .foregroundStyle(.green)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.count)
                    .font(.caption.monospacedDigit())
                if let percent = item.percent {
                    Text("\(percent)%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)

        Button {
            if isInstalled {
                openInstalledPackage(item)
            } else {
                openPackageInCatalog(item)
            }
        } label: {
            content
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isInstalled
                ? "Open \(item.title) in Installed"
                : "Open \(item.title) in Catalog"
        )
    }
}
