import SwiftUI

@main
struct HodgepodgeApp: App {
    @StateObject private var model = AppModel.live()
    @StateObject private var catalogModel = CatalogViewModel.live()
    @StateObject private var installedPackagesModel = InstalledPackagesViewModel.live()

    var body: some Scene {
        WindowGroup {
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel
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
