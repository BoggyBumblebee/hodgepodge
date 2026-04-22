import SwiftUI

struct CatalogAnalyticsLeaderboardCard: View {
    let leaderboard: CatalogAnalyticsLeaderboard
    @ObservedObject var installedPackagesViewModel: InstalledPackagesViewModel
    let openInstalledPackage: (CatalogAnalyticsItem) -> Void
    let openPackageInCatalog: (CatalogAnalyticsItem) -> Void

    var body: some View {
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
                        CatalogAnalyticsItemRow(
                            item: item,
                            isInstalled: installedPackagesViewModel.isInstalled(item),
                            openInstalledPackage: openInstalledPackage,
                            openPackageInCatalog: openPackageInCatalog
                        )
                    }
                }
            }
        }
    }
}

struct CatalogAnalyticsItemRow: View {
    let item: CatalogAnalyticsItem
    let isInstalled: Bool
    let openInstalledPackage: (CatalogAnalyticsItem) -> Void
    let openPackageInCatalog: (CatalogAnalyticsItem) -> Void

    var body: some View {
        Button(action: openItem) {
            HStack(spacing: 10) {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isInstalled
                ? "Open \(item.title) in Installed"
                : "Open \(item.title) in Catalog"
        )
    }

    private func openItem() {
        if isInstalled {
            openInstalledPackage(item)
        } else {
            openPackageInCatalog(item)
        }
    }
}
