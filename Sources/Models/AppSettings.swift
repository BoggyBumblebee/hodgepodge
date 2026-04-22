import Foundation

enum CompletionNotificationScope: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case allCompletions
    case longRunningOnly

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .allCompletions:
            "All completed actions"
        case .longRunningOnly:
            "Only long-running actions"
        }
    }

    var summary: String {
        switch self {
        case .allCompletions:
            "Notify whenever a Homebrew action succeeds, fails, or is cancelled."
        case .longRunningOnly:
            "Only notify when an action took long enough to feel background-worthy."
        }
    }
}

struct AppSettingsSnapshot: Codable, Equatable, Sendable {
    var defaultLaunchSection: AppSection
    var completionNotificationsEnabled: Bool
    var completionNotificationScope: CompletionNotificationScope
    var notificationSoundEnabled: Bool
    var restoreLastSelectedBrewfile: Bool
    var brewfileDefaultExportScope: CatalogScope

    init(
        defaultLaunchSection: AppSection = .catalog,
        completionNotificationsEnabled: Bool = true,
        completionNotificationScope: CompletionNotificationScope = .allCompletions,
        notificationSoundEnabled: Bool = true,
        restoreLastSelectedBrewfile: Bool = true,
        brewfileDefaultExportScope: CatalogScope = .all
    ) {
        self.defaultLaunchSection = defaultLaunchSection
        self.completionNotificationsEnabled = completionNotificationsEnabled
        self.completionNotificationScope = completionNotificationScope
        self.notificationSoundEnabled = notificationSoundEnabled
        self.restoreLastSelectedBrewfile = restoreLastSelectedBrewfile
        self.brewfileDefaultExportScope = brewfileDefaultExportScope
    }

    static let standard = AppSettingsSnapshot()
}
