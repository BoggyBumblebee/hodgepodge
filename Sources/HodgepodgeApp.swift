import SwiftUI

@main
struct HodgepodgeApp: App {
    @StateObject private var model = AppModel.live()
    @StateObject private var catalogModel = CatalogViewModel.live()
    @StateObject private var installedPackagesModel = InstalledPackagesViewModel.live()
    @StateObject private var outdatedPackagesModel = OutdatedPackagesViewModel.live()

    var body: some Scene {
        WindowGroup {
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel
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
