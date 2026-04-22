import Foundation

struct AppSettingsSnapshot: Codable, Equatable, Sendable {
    var defaultLaunchSection: AppSection
    var completionNotificationsEnabled: Bool
    var notificationSoundEnabled: Bool
    var restoreLastSelectedBrewfile: Bool

    static let standard = AppSettingsSnapshot(
        defaultLaunchSection: .catalog,
        completionNotificationsEnabled: true,
        notificationSoundEnabled: true,
        restoreLastSelectedBrewfile: true
    )
}
