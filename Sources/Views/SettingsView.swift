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

                Picker("Notify for", selection: Binding(
                    get: { model.settings.completionNotificationScope },
                    set: { model.setCompletionNotificationScope($0) }
                )) {
                    ForEach(CompletionNotificationScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!model.settings.completionNotificationsEnabled)

                Toggle("Play notification sound", isOn: Binding(
                    get: { model.settings.notificationSoundEnabled },
                    set: { model.setNotificationSoundEnabled($0) }
                ))
                .disabled(!model.settings.completionNotificationsEnabled)

                Text(model.settings.completionNotificationScope.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Brewfile") {
                Toggle("Restore last selected Brewfile on launch", isOn: Binding(
                    get: { model.settings.restoreLastSelectedBrewfile },
                    set: { model.setRestoreLastSelectedBrewfile($0) }
                ))

                Picker("Default installed export scope", selection: Binding(
                    get: { model.settings.brewfileDefaultExportScope },
                    set: { model.setBrewfileDefaultExportScope($0) }
                )) {
                    ForEach(CatalogScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.menu)

                Text("When enabled, the Brewfile section reopens the last selected document the next time the app starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Installed-page Brewfile exports use this scope by default instead of inheriting the current package filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 360)
        .padding(20)
    }
}
