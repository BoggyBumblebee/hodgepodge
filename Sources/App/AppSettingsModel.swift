import Foundation

@MainActor
final class AppSettingsModel: ObservableObject {
    @Published private(set) var settings: AppSettingsSnapshot

    private let store: any AppSettingsStoring

    init(store: any AppSettingsStoring) {
        self.store = store
        self.settings = store.loadSettings()
    }

    var defaultLaunchSection: AppSection {
        settings.defaultLaunchSection
    }

    func setDefaultLaunchSection(_ section: AppSection) {
        update { $0.defaultLaunchSection = section }
    }

    func setCompletionNotificationsEnabled(_ isEnabled: Bool) {
        update { $0.completionNotificationsEnabled = isEnabled }
    }

    func setCompletionNotificationScope(_ scope: CompletionNotificationScope) {
        update { $0.completionNotificationScope = scope }
    }

    func setNotificationSoundEnabled(_ isEnabled: Bool) {
        update { $0.notificationSoundEnabled = isEnabled }
    }

    func setRestoreLastSelectedBrewfile(_ isEnabled: Bool) {
        update { $0.restoreLastSelectedBrewfile = isEnabled }
    }

    func setBrewfileDefaultExportScope(_ scope: CatalogScope) {
        update { $0.brewfileDefaultExportScope = scope }
    }

    private func update(_ mutate: (inout AppSettingsSnapshot) -> Void) {
        var snapshot = settings
        mutate(&snapshot)

        guard snapshot != settings else {
            return
        }

        settings = snapshot
        store.saveSettings(snapshot)
    }
}

extension AppSettingsModel {
    static func live(store: any AppSettingsStoring = AppSettingsStore()) -> AppSettingsModel {
        AppSettingsModel(store: store)
    }
}
