import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var catalogModel: CatalogViewModel

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
        switch model.selectedSection ?? .overview {
        case .overview:
            OverviewView(model: model)
        case .catalog:
            CatalogView(viewModel: catalogModel)
        case .installed, .outdated, .services, .taps, .brewfile, .maintenance, .commandCenter, .settings:
            PlaceholderFeatureView(section: model.selectedSection ?? .overview)
        }
    }
}
