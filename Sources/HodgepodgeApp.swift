import SwiftUI

@main
struct HodgepodgeApp: App {
    @StateObject private var model = AppModel.live()
    @StateObject private var catalogModel = CatalogViewModel.live()
    @StateObject private var installedPackagesModel = InstalledPackagesViewModel.live()
    @StateObject private var outdatedPackagesModel = OutdatedPackagesViewModel.live()
    @StateObject private var servicesModel = ServicesViewModel.live()
    @StateObject private var maintenanceModel = MaintenanceViewModel.live()
    @StateObject private var tapsModel = TapsViewModel.live()
    @StateObject private var brewfileModel = BrewfileViewModel.live()

    var body: some Scene {
        WindowGroup {
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel,
                servicesModel: servicesModel,
                maintenanceModel: maintenanceModel,
                tapsModel: tapsModel,
                brewfileModel: brewfileModel
            )
                .frame(minWidth: 980, minHeight: 640)
                .task {
                    model.loadIfNeeded()
                }
        }
        .commands {
            HodgepodgeCommands(model: model)
        }
    }
}
