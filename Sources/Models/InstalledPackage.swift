import Foundation

enum InstalledPackagesLoadState: Equatable {
    case idle
    case loading
    case loaded([InstalledPackage])
    case failed(String)
}

enum InstalledPackageFilterOption: String, CaseIterable, Identifiable, Hashable {
    case pinned
    case linked
    case outdated
    case installedOnRequest
    case installedAsDependency
    case autoUpdates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinned:
            "Pinned"
        case .linked:
            "Linked"
        case .outdated:
            "Outdated"
        case .installedOnRequest:
            "On Request"
        case .installedAsDependency:
            "Dependency"
        case .autoUpdates:
            "Auto Updates"
        }
    }
}

enum InstalledPackageSortOption: String, CaseIterable, Identifiable {
    case name
    case installDate
    case packageType
    case tap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            "Name"
        case .installDate:
            "Install Date"
        case .packageType:
            "Package Type"
        case .tap:
            "Tap"
        }
    }
}

struct InstalledPackage: Identifiable, Equatable, Hashable, Sendable {
    let kind: CatalogPackageKind
    let slug: String
    let title: String
    let fullName: String
    let subtitle: String
    let version: String
    let homepage: URL?
    let tap: String
    let installedVersions: [String]
    let installedAt: Date?
    let linkedVersion: String?
    let isPinned: Bool
    let isLinked: Bool
    let isOutdated: Bool
    let isInstalledOnRequest: Bool
    let isInstalledAsDependency: Bool
    let autoUpdates: Bool
    let isDeprecated: Bool
    let isDisabled: Bool
    let runtimeDependencies: [String]

    var id: String {
        "\(kind.rawValue):\(slug)"
    }

    var statusBadges: [String] {
        var badges: [String] = []

        if isPinned {
            badges.append("Pinned")
        }
        if isLinked {
            badges.append("Linked")
        }
        if isOutdated {
            badges.append("Outdated")
        }
        if isInstalledOnRequest {
            badges.append("On Request")
        }
        if isInstalledAsDependency {
            badges.append("Dependency")
        }
        if autoUpdates {
            badges.append("Auto Updates")
        }
        if isDeprecated {
            badges.append("Deprecated")
        }
        if isDisabled {
            badges.append("Disabled")
        }

        return badges
    }

    var installSourceDescription: String {
        if isInstalledOnRequest {
            return "Installed on request"
        }
        if isInstalledAsDependency {
            return "Installed as a dependency"
        }
        return "Install source unavailable"
    }
}
