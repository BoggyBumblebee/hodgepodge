import AppKit
import Foundation

@MainActor
protocol BrewfileDumpSavePaneling: AnyObject {
    var canCreateDirectories: Bool { get set }
    var title: String { get set }
    var message: String { get set }
    var nameFieldStringValue: String { get set }
    var directoryURL: URL? { get set }
    var url: URL? { get }

    func runModal() -> NSApplication.ModalResponse
}

@MainActor
final class BrewfileDumpSavePanelAdapter: BrewfileDumpSavePaneling {
    private let panel: NSSavePanel

    init(panel: NSSavePanel = NSSavePanel()) {
        self.panel = panel
    }

    var canCreateDirectories: Bool {
        get { panel.canCreateDirectories }
        set { panel.canCreateDirectories = newValue }
    }

    var title: String {
        get { panel.title }
        set { panel.title = newValue }
    }

    var message: String {
        get { panel.message }
        set { panel.message = newValue }
    }

    var nameFieldStringValue: String {
        get { panel.nameFieldStringValue }
        set { panel.nameFieldStringValue = newValue }
    }

    var directoryURL: URL? {
        get { panel.directoryURL }
        set { panel.directoryURL = newValue }
    }

    var url: URL? {
        panel.url
    }

    func runModal() -> NSApplication.ModalResponse {
        panel.runModal()
    }
}

@MainActor
protocol BrewfileDumpDestinationPicking {
    func chooseDestination(
        suggestedFileName: String,
        startingDirectory: URL?
    ) -> URL?
}

@MainActor
struct BrewfileDumpDestinationPicker: BrewfileDumpDestinationPicking {
    private let savePanelFactory: () -> any BrewfileDumpSavePaneling

    init(
        savePanelFactory: @escaping () -> any BrewfileDumpSavePaneling = { BrewfileDumpSavePanelAdapter() }
    ) {
        self.savePanelFactory = savePanelFactory
    }

    func chooseDestination(
        suggestedFileName: String,
        startingDirectory: URL?
    ) -> URL? {
        let panel = savePanelFactory()
        panel.canCreateDirectories = true
        panel.title = "Generate Brewfile"
        panel.message = "Choose where Hodgepodge should write the generated Brewfile."
        panel.nameFieldStringValue = suggestedFileName
        panel.directoryURL = startingDirectory

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}
