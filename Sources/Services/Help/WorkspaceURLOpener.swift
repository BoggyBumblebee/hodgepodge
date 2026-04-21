import AppKit
import Foundation

protocol URLOpening {
    @discardableResult
    func open(_ url: URL) -> Bool
}

protocol WorkspaceOpening {
    @discardableResult
    func open(_ url: URL) -> Bool
}

extension NSWorkspace: WorkspaceOpening {}

struct WorkspaceURLOpener: URLOpening {
    private let workspace: any WorkspaceOpening

    init(workspace: any WorkspaceOpening = NSWorkspace.shared) {
        self.workspace = workspace
    }

    @discardableResult
    func open(_ url: URL) -> Bool {
        workspace.open(url)
    }
}
