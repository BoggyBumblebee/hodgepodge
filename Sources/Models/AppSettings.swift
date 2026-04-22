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

enum CompletionNotificationCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case packageActions
    case services
    case maintenance
    case brewfiles
    case taps

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .packageActions:
            "Package actions"
        case .services:
            "Services"
        case .maintenance:
            "Maintenance"
        case .brewfiles:
            "Brewfile"
        case .taps:
            "Taps"
        }
    }
}

enum CatalogHistoryRetentionLimit: Int, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case twentyFive = 25
    case fifty = 50
    case oneHundred = 100
    case twoHundredFifty = 250

    var id: Int {
        rawValue
    }

    var title: String {
        "\(rawValue) entries"
    }
}

struct AppSettingsSnapshot: Codable, Equatable, Sendable {
    var defaultLaunchSection: AppSection
    var completionNotificationsEnabled: Bool
    var completionNotificationScope: CompletionNotificationScope
    var completionNotificationCategories: Set<CompletionNotificationCategory>
    var notificationSoundEnabled: Bool
    var restoreLastSelectedBrewfile: Bool
    var brewfileDefaultExportScope: CatalogScope
    var catalogHistoryRetentionLimit: CatalogHistoryRetentionLimit

    init(
        defaultLaunchSection: AppSection = .catalog,
        completionNotificationsEnabled: Bool = true,
        completionNotificationScope: CompletionNotificationScope = .allCompletions,
        completionNotificationCategories: Set<CompletionNotificationCategory> = Set(CompletionNotificationCategory.allCases),
        notificationSoundEnabled: Bool = true,
        restoreLastSelectedBrewfile: Bool = true,
        brewfileDefaultExportScope: CatalogScope = .all,
        catalogHistoryRetentionLimit: CatalogHistoryRetentionLimit = .fifty
    ) {
        self.defaultLaunchSection = defaultLaunchSection
        self.completionNotificationsEnabled = completionNotificationsEnabled
        self.completionNotificationScope = completionNotificationScope
        self.completionNotificationCategories = completionNotificationCategories
        self.notificationSoundEnabled = notificationSoundEnabled
        self.restoreLastSelectedBrewfile = restoreLastSelectedBrewfile
        self.brewfileDefaultExportScope = brewfileDefaultExportScope
        self.catalogHistoryRetentionLimit = catalogHistoryRetentionLimit
    }

    static let standard = AppSettingsSnapshot()
}
