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
            completionNotificationScope: .longRunningOnly,
            completionNotificationCategories: [.services, .maintenance],
            notificationSoundEnabled: false,
            restoreLastSelectedBrewfile: false,
            brewfileDefaultExportScope: .cask,
            catalogHistoryRetentionLimit: .oneHundred
        )

        store.saveSettings(snapshot)

        XCTAssertEqual(store.loadSettings(), snapshot)
    }

    func testSaveSettingsPostsChangeNotification() {
        let notificationCenter = NotificationCenter()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("app-settings.json", isDirectory: false)
        let store = AppSettingsStore(fileURL: fileURL, notificationCenter: notificationCenter)
        let snapshot = AppSettingsSnapshot(
            completionNotificationScope: .longRunningOnly,
            completionNotificationCategories: [.brewfiles],
            brewfileDefaultExportScope: .formula,
            catalogHistoryRetentionLimit: .twoHundredFifty
        )
        let expectation = expectation(description: "Settings change notification")
        let observer = notificationCenter.addObserver(
            forName: .appSettingsDidChange,
            object: nil,
            queue: .main
        ) { notification in
            let postedSnapshot = notification.userInfo?[AppSettingsNotificationUserInfoKey.snapshot] as? AppSettingsSnapshot
            XCTAssertEqual(postedSnapshot, snapshot)
            expectation.fulfill()
        }
        defer {
            notificationCenter.removeObserver(observer)
        }

        store.saveSettings(snapshot)

        wait(for: [expectation], timeout: 1)
    }
}
