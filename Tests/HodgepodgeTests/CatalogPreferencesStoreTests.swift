import Foundation
import XCTest
@testable import Hodgepodge

final class CatalogPreferencesStoreTests: XCTestCase {
    func testSavedSearchSummaryDescribesConfiguration() {
        let search = CatalogSavedSearch(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID(),
            name: "Useful",
            searchText: "wget",
            scope: .formula,
            activeFilters: [.autoUpdates, .hasCaveats],
            sortOption: .tap
        )

        XCTAssertEqual(
            search.summary,
            "Search: wget • Formulae • Auto Updates, Has Caveats • Sort: Tap"
        )
    }

    func testSavedSearchSummaryFallsBackToDefaultView() {
        let search = CatalogSavedSearch(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666") ?? UUID(),
            name: "Default",
            searchText: "   ",
            scope: .all,
            activeFilters: [],
            sortOption: .name
        )

        XCTAssertEqual(search.summary, "Default catalog view")
    }

    func testPreferencesStoreRoundTripsSnapshot() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = rootURL.appendingPathComponent("catalog-preferences.json", isDirectory: false)
        let store = CatalogPreferencesStore(fileURL: fileURL)
        let snapshot = CatalogPreferencesSnapshot(
            favoritePackageIDs: ["formula:wget", "cask:docker-desktop"],
            savedSearches: [
                CatalogSavedSearch(
                    id: UUID(uuidString: "77777777-7777-7777-7777-777777777777") ?? UUID(),
                    name: "Favorites",
                    searchText: "docker",
                    scope: .cask,
                    activeFilters: [.autoUpdates],
                    sortOption: .version
                )
            ]
        )

        store.savePreferences(snapshot)

        XCTAssertEqual(store.loadPreferences(), snapshot)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        try? FileManager.default.removeItem(at: rootURL)
    }

    func testPreferencesStoreReturnsEmptySnapshotWhenFileMissing() {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("catalog-preferences.json", isDirectory: false)
        let store = CatalogPreferencesStore(fileURL: fileURL)

        XCTAssertEqual(store.loadPreferences(), .empty)
    }

    func testSavingFavoritePackageIDsPreservesSavedSearches() {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = rootURL.appendingPathComponent("catalog-preferences.json", isDirectory: false)
        let store = CatalogPreferencesStore(fileURL: fileURL)
        let originalSearch = CatalogSavedSearch(
            id: UUID(uuidString: "88888888-8888-8888-8888-888888888888") ?? UUID(),
            name: "Casks",
            searchText: "docker",
            scope: .cask,
            activeFilters: [.autoUpdates],
            sortOption: .tap
        )

        store.savePreferences(
            CatalogPreferencesSnapshot(
                favoritePackageIDs: ["formula:wget"],
                savedSearches: [originalSearch]
            )
        )
        store.saveFavoritePackageIDs(["formula:wget", "cask:docker-desktop"])

        XCTAssertEqual(
            store.loadPreferences(),
            CatalogPreferencesSnapshot(
                favoritePackageIDs: ["formula:wget", "cask:docker-desktop"],
                savedSearches: [originalSearch]
            )
        )

        try? FileManager.default.removeItem(at: rootURL)
    }

    func testSavingFavoritePackageIDsPostsChangeNotification() {
        let notificationCenter = NotificationCenter()
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = rootURL.appendingPathComponent("catalog-preferences.json", isDirectory: false)
        let store = CatalogPreferencesStore(
            fileURL: fileURL,
            notificationCenter: notificationCenter
        )
        let expectation = expectation(description: "favorite change notification")
        var receivedIDs: [String] = []
        let observer = notificationCenter.addObserver(
            forName: .favoritePackageIDsDidChange,
            object: nil,
            queue: nil
        ) { notification in
            receivedIDs = notification.userInfo?[FavoritePackageNotificationUserInfoKey.ids] as? [String] ?? []
            expectation.fulfill()
        }

        store.saveFavoritePackageIDs(["formula:wget"])

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedIDs, ["formula:wget"])
        notificationCenter.removeObserver(observer)
        try? FileManager.default.removeItem(at: rootURL)
    }
}
