import XCTest
@testable import Hodgepodge

@MainActor
final class AppSettingsModelTests: XCTestCase {
    func testMutationsUpdatePublishedSettingsAndPersistSnapshot() {
        let store = RecordingAppSettingsStore()
        let model = AppSettingsModel(store: store)

        model.setDefaultLaunchSection(.services)
        model.setCompletionNotificationsEnabled(false)
        model.setCompletionNotificationScope(.longRunningOnly)
        model.setCompletionNotificationCategory(.maintenance, isEnabled: false)
        model.setNotificationSoundEnabled(false)
        model.setRestoreLastSelectedBrewfile(false)
        model.setBrewfileDefaultExportScope(.formula)
        model.setCatalogHistoryRetentionLimit(.oneHundred)

        XCTAssertEqual(
            model.settings,
            AppSettingsSnapshot(
                defaultLaunchSection: .services,
                notifications: .init(
                    isEnabled: false,
                    scope: .longRunningOnly,
                    categories: Set(CompletionNotificationCategory.allCases).subtracting([.maintenance]),
                    soundEnabled: false
                ),
                brewfile: .init(
                    restoreLastSelectedBrewfile: false,
                    defaultExportScope: .formula
                ),
                catalogHistoryRetentionLimit: .oneHundred
            )
        )
        XCTAssertEqual(store.savedSnapshots.last, model.settings)
    }
}

private final class RecordingAppSettingsStore: AppSettingsStoring, @unchecked Sendable {
    private(set) var savedSnapshots: [AppSettingsSnapshot] = []

    func loadSettings() -> AppSettingsSnapshot {
        .standard
    }

    func saveSettings(_ snapshot: AppSettingsSnapshot) {
        savedSnapshots.append(snapshot)
    }
}
