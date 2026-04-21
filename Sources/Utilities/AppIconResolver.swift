import AppKit

enum AppIconResolver {
    @MainActor
    static func resolvedApplicationIcon(
        bundle: Bundle = .main,
        workspace: NSWorkspace = .shared
    ) -> NSImage? {
        let application = NSApplication.shared

        if let icon = application.applicationIconImage {
            return icon
        }

        let workspaceIcon = workspace.icon(forFile: bundle.bundlePath)
        if workspaceIcon.isValid {
            return workspaceIcon
        }

        return bundle.image(forResource: "AppIcon")
    }
}

private extension NSImage {
    var isValid: Bool {
        size.width > 0 && size.height > 0
    }
}
