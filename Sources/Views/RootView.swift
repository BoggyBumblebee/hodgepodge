import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $model.selectedSection) { section in
                Label(section.title, systemImage: section.systemImageName)
                    .accessibilityLabel(section.title)
                    .tag(section)
            }
            .navigationTitle("Hodgepodge")
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch model.selectedSection ?? .overview {
        case .overview:
            OverviewView(model: model)
        case .catalog, .installed, .outdated, .services, .taps, .brewfile, .maintenance, .commandCenter, .settings:
            PlaceholderFeatureView(section: model.selectedSection ?? .overview)
        }
    }
}
