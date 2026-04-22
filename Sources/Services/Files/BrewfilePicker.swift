import AppKit
import Foundation

@MainActor
protocol BrewfileOpenPaneling: AnyObject {
    var title: String? { get set }
    var message: String? { get set }
    var prompt: String? { get set }
    var canChooseFiles: Bool { get set }
    var canChooseDirectories: Bool { get set }
    var allowsMultipleSelection: Bool { get set }
    var directoryURL: URL? { get set }
    var url: URL? { get }

    func runModal() -> NSApplication.ModalResponse
}

@MainActor
final class BrewfileOpenPanelAdapter: BrewfileOpenPaneling {
    private let panel: NSOpenPanel

    init(panel: NSOpenPanel = NSOpenPanel()) {
        self.panel = panel
    }

    var title: String? {
        get { panel.title }
        set { panel.title = newValue ?? "" }
    }

    var message: String? {
        get { panel.message }
        set { panel.message = newValue ?? "" }
    }

    var prompt: String? {
        get { panel.prompt }
        set { panel.prompt = newValue ?? "" }
    }

    var canChooseFiles: Bool {
        get { panel.canChooseFiles }
        set { panel.canChooseFiles = newValue }
    }

    var canChooseDirectories: Bool {
        get { panel.canChooseDirectories }
        set { panel.canChooseDirectories = newValue }
    }

    var allowsMultipleSelection: Bool {
        get { panel.allowsMultipleSelection }
        set { panel.allowsMultipleSelection = newValue }
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

protocol BrewfilePicking {
    @MainActor func pickBrewfile(startingDirectory: URL?) -> URL?
}

struct BrewfilePicker: BrewfilePicking {
    private let panelFactory: @MainActor () -> any BrewfileOpenPaneling

    init(
        panelFactory: @escaping @MainActor () -> any BrewfileOpenPaneling = { BrewfileOpenPanelAdapter() }
    ) {
        self.panelFactory = panelFactory
    }

    @MainActor
    func pickBrewfile(startingDirectory: URL?) -> URL? {
        let panel = panelFactory()
        panel.title = "Choose a Brewfile"
        panel.message = "Select the Brewfile you want Hodgepodge to inspect."
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = startingDirectory

        return panel.runModal() == .OK ? panel.url : nil
    }
}
