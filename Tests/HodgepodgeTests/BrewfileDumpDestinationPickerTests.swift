import AppKit
import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class BrewfileDumpDestinationPickerTests: XCTestCase {
    func testPickerConfiguresSavePanelAndReturnsSelectedURL() {
        let expectedURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let panel = MockBrewfileDumpSavePanel(response: .OK, url: expectedURL)
        let picker = BrewfileDumpDestinationPicker(savePanelFactory: { panel })
        let startingDirectory = URL(fileURLWithPath: "/tmp")

        let destination = picker.chooseDestination(
            suggestedFileName: "Brewfile",
            startingDirectory: startingDirectory
        )

        XCTAssertEqual(destination, expectedURL)
        XCTAssertTrue(panel.canCreateDirectories)
        XCTAssertEqual(panel.title, "Generate Brewfile")
        XCTAssertEqual(panel.message, "Choose where Hodgepodge should write the generated Brewfile.")
        XCTAssertEqual(panel.nameFieldStringValue, "Brewfile")
        XCTAssertEqual(panel.directoryURL, startingDirectory)
    }

    func testPickerReturnsNilWhenPanelIsCancelled() {
        let panel = MockBrewfileDumpSavePanel(
            response: .cancel,
            url: URL(fileURLWithPath: "/tmp/Brewfile")
        )
        let picker = BrewfileDumpDestinationPicker(savePanelFactory: { panel })

        XCTAssertNil(picker.chooseDestination(suggestedFileName: "Brewfile", startingDirectory: nil))
    }

    func testSavePanelAdapterForwardsConfigurationToWrappedPanel() {
        let panel = NSSavePanel()
        let adapter = BrewfileDumpSavePanelAdapter(panel: panel)
        let directoryURL = URL(fileURLWithPath: "/tmp")

        adapter.canCreateDirectories = true
        adapter.title = "Generate Brewfile"
        adapter.message = "Write the Brewfile here."
        adapter.nameFieldStringValue = "Brewfile"
        adapter.directoryURL = directoryURL

        XCTAssertTrue(adapter.canCreateDirectories)
        XCTAssertEqual(adapter.title, "Generate Brewfile")
        XCTAssertEqual(adapter.message, "Write the Brewfile here.")
        XCTAssertEqual(adapter.nameFieldStringValue, "Brewfile")
        XCTAssertEqual(adapter.directoryURL, directoryURL)
    }
}

@MainActor
private final class MockBrewfileDumpSavePanel: BrewfileDumpSavePaneling, @unchecked Sendable {
    var canCreateDirectories = false
    var title = ""
    var message = ""
    var nameFieldStringValue = ""
    var directoryURL: URL?
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
