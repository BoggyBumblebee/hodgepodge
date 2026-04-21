import SwiftUI

struct HodgepodgeCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Hodgepodge") {
                model.openAboutPanel()
            }
        }

        CommandGroup(replacing: .help) {
            Button("Hodgepodge Help") {
                model.openHelp(anchor: .home)
            }
            .keyboardShortcut("?", modifiers: [.command, .shift])

            Button("Quick Start") {
                model.openHelp(anchor: .quickStart)
            }
            .keyboardShortcut("1", modifiers: [.command, .option])

            Button("Troubleshooting") {
                model.openHelp(anchor: .troubleshooting)
            }
            .keyboardShortcut("2", modifiers: [.command, .option])
        }
    }
}
