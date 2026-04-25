import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var catalogModel: CatalogViewModel
    @ObservedObject var installedPackagesModel: InstalledPackagesViewModel
    @ObservedObject var outdatedPackagesModel: OutdatedPackagesViewModel
    @ObservedObject var servicesModel: ServicesViewModel
    @ObservedObject var maintenanceModel: MaintenanceViewModel
    @ObservedObject var tapsModel: TapsViewModel
    @ObservedObject var brewfileModel: BrewfileViewModel

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $model.selectedSection) { section in
                navigationRow(for: section)
                    .tag(section)
            }
            .navigationTitle("Hodgepodge")
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        } detail: {
            detailView
                .navigationTitle(currentSection.title)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var currentSection: AppSection {
        model.selectedSection ?? .catalog
    }

    @ViewBuilder
    private func navigationRow(for section: AppSection) -> some View {
        HStack(spacing: 8) {
            Label(section.title, systemImage: section.systemImageName)

            Spacer(minLength: 8)

            if let badgeCount = navigationBadgeCount(for: section) {
                Text(badgeCount.formatted())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: section))
    }

    private func navigationBadgeCount(for section: AppSection) -> Int? {
        let count = switch section {
        case .outdated:
            outdatedPackagesModel.upgradeablePackageCount
        case .maintenance:
            maintenanceModel.issueCount
        case .overview, .catalog, .catalogAnalytics, .installed, .services, .taps, .brewfile:
            0
        }

        return count > 0 ? count : nil
    }

    private func accessibilityLabel(for section: AppSection) -> String {
        guard let badgeCount = navigationBadgeCount(for: section) else {
            return section.title
        }

        let noun = switch section {
        case .outdated:
            badgeCount == 1 ? "upgrade" : "upgrades"
        case .maintenance:
            badgeCount == 1 ? "maintenance issue" : "maintenance issues"
        case .overview, .catalog, .catalogAnalytics, .installed, .services, .taps, .brewfile:
            "items"
        }

        return "\(section.title), \(badgeCount) \(noun)"
    }

    @ViewBuilder
    private var detailView: some View {
        switch currentSection {
        case .overview:
            OverviewView(model: model)
        case .catalog:
            CatalogView(
                viewModel: catalogModel,
                installedPackagesViewModel: installedPackagesModel
            )
        case .catalogAnalytics:
            CatalogAnalyticsView(
                viewModel: catalogModel,
                installedPackagesViewModel: installedPackagesModel,
                openInstalledPackage: { item in
                    model.selectedSection = .installed
                    installedPackagesModel.openAnalyticsItem(item)
                },
                openPackageInCatalog: { item in
                    model.selectedSection = .catalog
                    catalogModel.openAnalyticsItemInCatalog(item)
                }
            )
        case .installed:
            InstalledPackagesView(viewModel: installedPackagesModel)
        case .outdated:
            OutdatedPackagesView(viewModel: outdatedPackagesModel)
        case .services:
            ServicesView(viewModel: servicesModel)
        case .taps:
            TapsView(viewModel: tapsModel)
        case .maintenance:
            MaintenanceView(viewModel: maintenanceModel)
        case .brewfile:
            BrewfileView(viewModel: brewfileModel)
        }
    }
}
