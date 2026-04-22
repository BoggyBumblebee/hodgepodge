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
                Label(section.title, systemImage: section.systemImageName)
                    .accessibilityLabel(section.title)
                    .tag(section)
            }
            .navigationTitle("Hodgepodge")
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detailView: some View {
        switch model.selectedSection ?? .catalog {
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
