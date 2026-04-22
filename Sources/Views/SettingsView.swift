import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppSettingsModel

    var body: some View {
        Form {
            Section("General") {
                Picker("Default launch section", selection: Binding(
                    get: { model.settings.defaultLaunchSection },
                    set: { model.setDefaultLaunchSection($0) }
                )) {
                    ForEach(AppSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.menu)

                Text("Used the next time Hodgepodge launches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Enable completion notifications", isOn: Binding(
                    get: { model.settings.completionNotificationsEnabled },
                    set: { model.setCompletionNotificationsEnabled($0) }
                ))

                Toggle("Play notification sound", isOn: Binding(
                    get: { model.settings.notificationSoundEnabled },
                    set: { model.setNotificationSoundEnabled($0) }
                ))
                .disabled(!model.settings.completionNotificationsEnabled)

                Text("Notifications are used for long-running Homebrew actions when they finish, fail, or are cancelled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Brewfile") {
                Toggle("Restore last selected Brewfile on launch", isOn: Binding(
                    get: { model.settings.restoreLastSelectedBrewfile },
                    set: { model.setRestoreLastSelectedBrewfile($0) }
                ))

                Text("When enabled, the Brewfile section reopens the last selected document the next time the app starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 360)
        .padding(20)
    }
}
