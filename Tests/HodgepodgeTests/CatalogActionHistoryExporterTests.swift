import AppKit
import Foundation
import UniformTypeIdentifiers
import XCTest
@testable import Hodgepodge

@MainActor
final class CatalogActionHistoryExporterTests: XCTestCase {
    func testSavePanelAdapterForwardsConfigurationToWrappedPanel() {
        let panel = NSSavePanel()
        let adapter = CatalogActionHistorySavePanelAdapter(panel: panel)

        adapter.allowedContentTypes = [.json]
        adapter.canCreateDirectories = true
        adapter.nameFieldStringValue = "history.json"
        adapter.title = "Export Command History"
        adapter.message = "Choose where to save the command history JSON file."

        XCTAssertEqual(panel.allowedContentTypes, [.json])
        XCTAssertTrue(panel.canCreateDirectories)
        XCTAssertEqual(panel.nameFieldStringValue, "history.json")
        XCTAssertEqual(panel.title, "Export Command History")
        XCTAssertEqual(panel.message, "Choose where to save the command history JSON file.")
        XCTAssertNotNil(adapter.url)
    }

    func testExportWritesJSONToSelectedLocation() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("history.json", isDirectory: false)
        let panel = MockCatalogActionHistorySavePanel(response: .OK, url: fileURL)
        let exporter = CatalogActionHistoryExporter(savePanelFactory: { panel })
        let entry = CatalogPackageActionHistoryEntry(
            id: 1,
            command: CatalogPackageDetail.fixture().actionCommand(for: .fetch),
            startedAt: Date(timeIntervalSince1970: 100),
            finishedAt: Date(timeIntervalSince1970: 120),
            outcome: .succeeded(0),
            outputLineCount: 2
        )

        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        try exporter.export(
            entries: [entry],
            suggestedFileName: "hodgepodge-command-history.json"
        )

        let data = try Data(contentsOf: fileURL)
        let decodedEntries = try CatalogActionHistoryCodec.makeDecoder().decode(
            [CatalogPackageActionHistoryEntry].self,
            from: data
        )

        XCTAssertEqual(decodedEntries, [entry])
        XCTAssertEqual(panel.nameFieldStringValue, "hodgepodge-command-history.json")
        XCTAssertEqual(panel.allowedContentTypes, [.json])
        XCTAssertTrue(panel.canCreateDirectories)
        XCTAssertEqual(panel.title, "Export Command History")
        XCTAssertEqual(panel.message, "Choose where to save the command history JSON file.")
    }

    func testExportThrowsCancelledWhenSavePanelIsDismissed() {
        let panel = MockCatalogActionHistorySavePanel(response: .cancel, url: nil)
        let exporter = CatalogActionHistoryExporter(savePanelFactory: { panel })

        XCTAssertThrowsError(
            try exporter.export(
                entries: [],
                suggestedFileName: "hodgepodge-command-history.json"
            )
        ) { error in
            XCTAssertEqual(error as? CatalogActionHistoryExportError, .cancelled)
        }
    }

    func testCancelledExportErrorHasHelpfulDescription() {
        XCTAssertEqual(
            CatalogActionHistoryExportError.cancelled.errorDescription,
            "The history export was cancelled."
        )
    }
}

@MainActor
private final class MockCatalogActionHistorySavePanel: CatalogActionHistorySavePaneling {
    var allowedContentTypes: [UTType] = []
    var canCreateDirectories = false
    var nameFieldStringValue = ""
    var title = ""
    var message = ""
    let response: NSApplication.ModalResponse
    let url: URL?

    init(response: NSApplication.ModalResponse, url: URL?) {
        self.response = response
        self.url = url
    }

    func runModal() -> NSApplication.ModalResponse {
        response
    }
}
