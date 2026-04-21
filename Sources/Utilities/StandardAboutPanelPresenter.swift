import AppKit

protocol AboutPanelPresenting {
    @MainActor
    func presentAboutPanel()
}

struct StandardAboutPanelPresenter: AboutPanelPresenting {
    @MainActor
    func presentAboutPanel() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "Hodgepodge"
        ]

        if let icon = AppIconResolver.resolvedApplicationIcon() {
            options[.applicationIcon] = icon
        }

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
}
