import AppKit

@MainActor
protocol ApplicationIconImageProviding {
    var resolvedApplicationIconImage: NSImage? { get }
}

protocol WorkspaceFileIconProviding {
    func icon(forFile path: String) -> NSImage
}

protocol BundleImageResourceQuerying {
    var bundlePath: String { get }
    func image(named name: String) -> NSImage?
}

@MainActor
extension NSApplication: ApplicationIconImageProviding {
    var resolvedApplicationIconImage: NSImage? {
        applicationIconImage
    }
}

extension NSWorkspace: WorkspaceFileIconProviding {}

extension Bundle: BundleImageResourceQuerying {
    func image(named name: String) -> NSImage? {
        image(forResource: name)
    }
}

enum AppIconResolver {
    @MainActor
    static func resolvedApplicationIcon(
        bundle: any BundleImageResourceQuerying = Bundle.main,
        workspace: any WorkspaceFileIconProviding = NSWorkspace.shared,
        application: any ApplicationIconImageProviding = NSApplication.shared
    ) -> NSImage? {
        if let icon = application.resolvedApplicationIconImage, icon.isValid {
            return icon
        }

        if let bundledIcon = bundledApplicationIcon(bundle: bundle), bundledIcon.isValid {
            return bundledIcon
        }

        let workspaceIcon = workspace.icon(forFile: bundle.bundlePath)
        if workspaceIcon.isValid {
            return workspaceIcon
        }

        return nil
    }

    @MainActor
    static func bundledApplicationIcon(
        bundle: any BundleImageResourceQuerying = Bundle.main
    ) -> NSImage? {
        bundle.image(named: "AppBrandIcon") ?? bundle.image(named: "AppIcon")
    }
}

private extension NSImage {
    var isValid: Bool {
        size.width > 0 && size.height > 0
    }
}
