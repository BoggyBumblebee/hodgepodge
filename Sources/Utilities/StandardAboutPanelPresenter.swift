import AppKit

protocol AboutPanelPresenting {
    @MainActor
    func presentAboutPanel()
}

@MainActor
protocol AboutPanelApplicationControlling {
    func activate(ignoringOtherApps flag: Bool)

    func orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey: Any])
}

@MainActor
extension NSApplication: AboutPanelApplicationControlling {}

struct StandardAboutPanelPresenter: AboutPanelPresenting {
    private let application: any AboutPanelApplicationControlling
    private let iconResolver: @MainActor () -> NSImage?

    @MainActor
    init(
        application: any AboutPanelApplicationControlling = NSApplication.shared,
        iconResolver: @escaping @MainActor () -> NSImage? = { AppIconResolver.resolvedApplicationIcon() }
    ) {
        self.application = application
        self.iconResolver = iconResolver
    }

    @MainActor
    func presentAboutPanel() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "Hodgepodge"
        ]

        if let icon = iconResolver() {
            options[.applicationIcon] = icon
        }

        application.activate(ignoringOtherApps: true)
        application.orderFrontStandardAboutPanel(options: options)
    }
}
