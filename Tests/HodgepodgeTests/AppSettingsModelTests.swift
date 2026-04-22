import XCTest
@testable import Hodgepodge

@MainActor
final class AppSettingsModelTests: XCTestCase {
    func testMutationsUpdatePublishedSettingsAndPersistSnapshot() {
        let store = RecordingAppSettingsStore()
        let model = AppSettingsModel(store: store)

        model.setDefaultLaunchSection(.services)
        model.setCompletionNotificationsEnabled(false)
        model.setNotificationSoundEnabled(false)
        model.setRestoreLastSelectedBrewfile(false)

        XCTAssertEqual(
            model.settings,
            AppSettingsSnapshot(
                defaultLaunchSection: .services,
                completionNotificationsEnabled: false,
                notificationSoundEnabled: false,
                restoreLastSelectedBrewfile: false
            )
        )
        XCTAssertEqual(store.savedSnapshots.last, model.settings)
    }
}

private final class RecordingAppSettingsStore: AppSettingsStoring, @unchecked Sendable {
    private(set) var savedSnapshots: [AppSettingsSnapshot] = []

    func loadSettings() -> AppSettingsSnapshot {
        .default
    }

    func saveSettings(_ snapshot: AppSettingsSnapshot) {
        savedSnapshots.append(snapshot)
    }
}
