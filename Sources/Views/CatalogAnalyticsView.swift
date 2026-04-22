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
        .toolbar {
            ToolbarItemGroup {
                Picker("Analytics Window", selection: analyticsPeriodBinding) {
                    ForEach(CatalogAnalyticsPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    viewModel.refreshAnalytics()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Public Homebrew leaderboard data from the official analytics API.")
                .foregroundStyle(.secondary)
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
                        CatalogAnalyticsLeaderboardCard(
                            leaderboard: leaderboard,
                            installedPackagesViewModel: installedPackagesViewModel,
                            openInstalledPackage: openInstalledPackage,
                            openPackageInCatalog: openPackageInCatalog
                        )
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
}
