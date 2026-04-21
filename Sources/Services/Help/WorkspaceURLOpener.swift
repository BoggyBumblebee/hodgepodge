import AppKit
import Foundation

protocol URLOpening {
    @discardableResult
    func open(_ url: URL) -> Bool
}

struct WorkspaceURLOpener: URLOpening {
    @discardableResult
    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}
