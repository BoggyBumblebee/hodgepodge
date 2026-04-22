import Foundation
import XCTest
@testable import Hodgepodge

final class AppSettingsStoreTests: XCTestCase {
    func testLoadSettingsReturnsDefaultsWhenFileIsMissing() {
        let store = AppSettingsStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent("app-settings.json")
        )

        XCTAssertEqual(store.loadSettings(), .standard)
    }

    func testSaveAndLoadSettingsRoundTripsSnapshot() {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("app-settings.json", isDirectory: false)
        let store = AppSettingsStore(fileURL: fileURL)
        let snapshot = AppSettingsSnapshot(
            defaultLaunchSection: .installed,
            completionNotificationsEnabled: false,
            notificationSoundEnabled: false,
            restoreLastSelectedBrewfile: false
        )

        store.saveSettings(snapshot)

        XCTAssertEqual(store.loadSettings(), snapshot)
    }
}
