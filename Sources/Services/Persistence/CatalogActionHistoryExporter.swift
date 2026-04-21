import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
protocol CatalogActionHistorySavePaneling: AnyObject {
    var allowedContentTypes: [UTType] { get set }
    var canCreateDirectories: Bool { get set }
    var nameFieldStringValue: String { get set }
    var title: String { get set }
    var message: String { get set }
    var url: URL? { get }

    func runModal() -> NSApplication.ModalResponse
}

@MainActor
final class CatalogActionHistorySavePanelAdapter: CatalogActionHistorySavePaneling {
    private let panel: NSSavePanel

    init(panel: NSSavePanel = NSSavePanel()) {
        self.panel = panel
    }

    var allowedContentTypes: [UTType] {
        get { panel.allowedContentTypes }
        set { panel.allowedContentTypes = newValue }
    }

    var canCreateDirectories: Bool {
        get { panel.canCreateDirectories }
        set { panel.canCreateDirectories = newValue }
    }

    var nameFieldStringValue: String {
        get { panel.nameFieldStringValue }
        set { panel.nameFieldStringValue = newValue }
    }

    var title: String {
        get { panel.title }
        set { panel.title = newValue }
    }

    var message: String {
        get { panel.message }
        set { panel.message = newValue }
    }

    var url: URL? {
        panel.url
    }

    func runModal() -> NSApplication.ModalResponse {
        panel.runModal()
    }
}

@MainActor
protocol CatalogActionHistoryExporting {
    func export(
        entries: [CatalogPackageActionHistoryEntry],
        suggestedFileName: String
    ) throws
}

enum CatalogActionHistoryExportError: LocalizedError, Equatable {
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "The history export was cancelled."
        }
    }
}

@MainActor
struct CatalogActionHistoryExporter: CatalogActionHistoryExporting {
    private let savePanelFactory: () -> any CatalogActionHistorySavePaneling
    private let encoder: JSONEncoder

    init(
        savePanelFactory: @escaping () -> any CatalogActionHistorySavePaneling = { CatalogActionHistorySavePanelAdapter() },
        encoder: JSONEncoder = CatalogActionHistoryCodec.makeEncoder()
    ) {
        self.savePanelFactory = savePanelFactory
        self.encoder = encoder
    }

    func export(
        entries: [CatalogPackageActionHistoryEntry],
        suggestedFileName: String
    ) throws {
        let panel = savePanelFactory()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFileName
        panel.title = "Export Command History"
        panel.message = "Choose where to save the command history JSON file."

        guard panel.runModal() == .OK, let fileURL = panel.url else {
            throw CatalogActionHistoryExportError.cancelled
        }

        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic)
    }
}
