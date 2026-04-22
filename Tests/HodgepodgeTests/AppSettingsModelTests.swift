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
        model.setNotificationSoundEnabled(false)
        model.setRestoreLastSelectedBrewfile(false)
        model.setBrewfileDefaultExportScope(.formula)

        XCTAssertEqual(
            model.settings,
            AppSettingsSnapshot(
                defaultLaunchSection: .services,
                completionNotificationsEnabled: false,
                completionNotificationScope: .longRunningOnly,
                notificationSoundEnabled: false,
                restoreLastSelectedBrewfile: false,
                brewfileDefaultExportScope: .formula
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
