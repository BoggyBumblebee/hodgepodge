import AppKit
import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class BrewfilePickerTests: XCTestCase {
    func testPickerConfiguresPanelAndReturnsSelectedURL() {
        let expectedURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let panel = MockBrewfileOpenPanel(response: .OK, url: expectedURL)
        let picker = BrewfilePicker(panelFactory: { panel })
        let startingDirectory = URL(fileURLWithPath: "/tmp")

        let pickedURL = picker.pickBrewfile(startingDirectory: startingDirectory)

        XCTAssertEqual(pickedURL, expectedURL)
        XCTAssertEqual(panel.title, "Choose a Brewfile")
        XCTAssertEqual(panel.message, "Select the Brewfile you want Hodgepodge to inspect.")
        XCTAssertEqual(panel.prompt, "Open")
        XCTAssertEqual(panel.directoryURL, startingDirectory)
        XCTAssertTrue(panel.canChooseFiles)
        XCTAssertFalse(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
    }

    func testPickerReturnsNilWhenPanelCancelled() {
        let panel = MockBrewfileOpenPanel(response: .cancel, url: URL(fileURLWithPath: "/tmp/Brewfile"))
        let picker = BrewfilePicker(panelFactory: { panel })

        XCTAssertNil(picker.pickBrewfile(startingDirectory: nil))
    }

    func testOpenPanelAdapterForwardsPropertiesToWrappedPanel() {
        let panel = NSOpenPanel()
        let adapter = BrewfileOpenPanelAdapter(panel: panel)
        let directoryURL = URL(fileURLWithPath: "/tmp")

        adapter.title = "Choose a Brewfile"
        adapter.message = "Inspect a Brewfile."
        adapter.prompt = "Open"
        adapter.canChooseFiles = true
        adapter.canChooseDirectories = false
        adapter.allowsMultipleSelection = false
        adapter.directoryURL = directoryURL

        XCTAssertEqual(adapter.title, "Choose a Brewfile")
        XCTAssertEqual(adapter.message, "Inspect a Brewfile.")
        XCTAssertEqual(adapter.prompt, "Open")
        XCTAssertTrue(adapter.canChooseFiles)
        XCTAssertFalse(adapter.canChooseDirectories)
        XCTAssertFalse(adapter.allowsMultipleSelection)
        XCTAssertEqual(adapter.directoryURL, directoryURL)
        XCTAssertNil(adapter.url)
    }
}

@MainActor
private final class MockBrewfileOpenPanel: BrewfileOpenPaneling, @unchecked Sendable {
    var title: String?
    var message: String?
    var prompt: String?
    var canChooseFiles = false
    var canChooseDirectories = false
    var allowsMultipleSelection = true
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
