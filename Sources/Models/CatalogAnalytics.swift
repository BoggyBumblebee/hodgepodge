import Foundation

enum CatalogAnalyticsPeriod: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case days30 = "30d"
    case days90 = "90d"
    case days365 = "365d"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days30:
            "30 Days"
        case .days90:
            "90 Days"
        case .days365:
            "365 Days"
        }
    }
}

enum CatalogAnalyticsLeaderboardKind: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
    case formulaInstalls
    case formulaInstallsOnRequest
    case caskInstalls
    case buildErrors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .formulaInstalls:
            "Top Formula Installs"
        case .formulaInstallsOnRequest:
            "Top On-Request Formulae"
        case .caskInstalls:
            "Top Cask Installs"
        case .buildErrors:
            "Most Frequent Build Errors"
        }
    }

    var subtitle: String {
        switch self {
        case .formulaInstalls:
            "Most-installed formulae in the selected period."
        case .formulaInstallsOnRequest:
            "Formulae users explicitly chose most often."
        case .caskInstalls:
            "Most-installed casks in the selected period."
        case .buildErrors:
            "Formulae with the highest recent build error counts."
        }
    }
}

struct CatalogAnalyticsItem: Identifiable, Equatable, Sendable {
    let kind: CatalogPackageKind
    let slug: String
    let rank: Int
    let count: String
    let percent: String?

    var id: String {
        "\(kind.rawValue):\(slug)"
    }

    var title: String {
        slug
    }
}

struct CatalogAnalyticsLeaderboard: Identifiable, Equatable, Sendable {
    let kind: CatalogAnalyticsLeaderboardKind
    let period: CatalogAnalyticsPeriod
    let startDate: String
    let endDate: String
    let totalItems: Int
    let totalCount: String
    let items: [CatalogAnalyticsItem]

    var id: String {
        "\(kind.rawValue):\(period.rawValue)"
    }

    var title: String {
        kind.title
    }

    var subtitle: String {
        kind.subtitle
    }

    var dateRangeSummary: String {
        "\(startDate) to \(endDate)"
    }
}

struct CatalogAnalyticsSnapshot: Equatable, Sendable {
    let period: CatalogAnalyticsPeriod
    let leaderboards: [CatalogAnalyticsLeaderboard]

    static let empty = CatalogAnalyticsSnapshot(period: .days30, leaderboards: [])

    static func empty(for period: CatalogAnalyticsPeriod) -> CatalogAnalyticsSnapshot {
        CatalogAnalyticsSnapshot(period: period, leaderboards: [])
    }
}

enum CatalogAnalyticsLoadState: Equatable {
    case idle
    case loading(CatalogAnalyticsPeriod)
    case loaded(CatalogAnalyticsSnapshot)
    case failed(CatalogAnalyticsPeriod, String)
}
