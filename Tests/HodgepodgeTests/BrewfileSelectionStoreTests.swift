import Foundation
import XCTest
@testable import Hodgepodge

final class BrewfileSelectionStoreTests: XCTestCase {
    func testSaveAndLoadSelectionRoundTripsFileURL() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("selection.txt", isDirectory: false)
        let store = BrewfileSelectionStore(fileURL: fileURL)
        let selectedURL = URL(fileURLWithPath: "/tmp/Brewfile")

        store.saveSelection(selectedURL)

        XCTAssertEqual(store.loadSelection(), selectedURL)
    }

    func testSaveSelectionNilRemovesPersistedFile() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("selection.txt", isDirectory: false)
        let store = BrewfileSelectionStore(fileURL: fileURL)

        store.saveSelection(URL(fileURLWithPath: "/tmp/Brewfile"))
        store.saveSelection(nil)

        XCTAssertNil(store.loadSelection())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
