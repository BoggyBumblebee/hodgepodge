import SwiftUI

@main
struct HodgepodgeApp: App {
    @StateObject private var settingsModel: AppSettingsModel
    @StateObject private var model: AppModel
    @StateObject private var catalogModel: CatalogViewModel
    @StateObject private var installedPackagesModel: InstalledPackagesViewModel
    @StateObject private var outdatedPackagesModel: OutdatedPackagesViewModel
    @StateObject private var servicesModel: ServicesViewModel
    @StateObject private var maintenanceModel: MaintenanceViewModel
    @StateObject private var tapsModel: TapsViewModel
    @StateObject private var brewfileModel: BrewfileViewModel

    init() {
        let settingsStore = AppSettingsStore()
        let settingsModel = AppSettingsModel.live(store: settingsStore)
        let notificationScheduler = CommandNotificationScheduler.live(settingsStore: settingsStore)

        _settingsModel = StateObject(wrappedValue: settingsModel)
        _model = StateObject(wrappedValue: AppModel.live(defaultLaunchSection: settingsModel.defaultLaunchSection))
        _catalogModel = StateObject(wrappedValue: CatalogViewModel.live(notificationScheduler: notificationScheduler))
        _installedPackagesModel = StateObject(
            wrappedValue: InstalledPackagesViewModel.live(
                notificationScheduler: notificationScheduler,
                settingsStore: settingsStore
            )
        )
        _outdatedPackagesModel = StateObject(
            wrappedValue: OutdatedPackagesViewModel.live(notificationScheduler: notificationScheduler)
        )
        _servicesModel = StateObject(wrappedValue: ServicesViewModel.live(notificationScheduler: notificationScheduler))
        _maintenanceModel = StateObject(
            wrappedValue: MaintenanceViewModel.live(notificationScheduler: notificationScheduler)
        )
        _tapsModel = StateObject(wrappedValue: TapsViewModel.live(notificationScheduler: notificationScheduler))
        _brewfileModel = StateObject(
            wrappedValue: BrewfileViewModel.live(
                notificationScheduler: notificationScheduler,
                settingsStore: settingsStore
            )
        )
    }

    var body: some Scene {
        Window("Hodgepodge", id: "main") {
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

        Settings {
            SettingsView(model: settingsModel)
        }
    }
}
