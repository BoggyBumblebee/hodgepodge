import Foundation
import XCTest
@testable import Hodgepodge

final class CatalogActionHistoryStoreTests: XCTestCase {
    func testSaveAndLoadRoundTripsEntries() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("catalog-action-history.json", isDirectory: false)
        let store = CatalogActionHistoryStore(fileURL: fileURL)
        let entry = CatalogPackageActionHistoryEntry(
            id: 3,
            command: CatalogPackageDetail.fixture().actionCommand(for: .fetch),
            startedAt: Date(timeIntervalSince1970: 100),
            finishedAt: Date(timeIntervalSince1970: 140),
            outcome: .succeeded(0),
            outputLineCount: 5
        )

        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        store.saveHistory([entry])

        XCTAssertEqual(store.loadHistory(), [entry])
    }

    func testLoadHistoryReturnsEmptyArrayForUnreadableFile() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("catalog-action-history.json", isDirectory: false)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fileURL)
        let store = CatalogActionHistoryStore(fileURL: fileURL)

        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        XCTAssertEqual(store.loadHistory(), [])
    }
}
