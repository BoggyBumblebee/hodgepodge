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
}
