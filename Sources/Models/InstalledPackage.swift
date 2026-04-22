import Foundation

struct InstalledPackageDependencyGroup: Identifiable, Equatable, Sendable {
    let title: String
    let items: [String]

    var id: String {
        title
    }
}

enum InstalledPackagesLoadState: Equatable {
    case idle
    case loading
    case loaded([InstalledPackage])
    case failed(String)
}

enum InstalledPackageFilterOption: String, CaseIterable, Identifiable, Hashable {
    case favorites
    case pinned
    case linked
    case leaves
    case outdated
    case installedOnRequest
    case installedAsDependency
    case autoUpdates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorites:
            "Favorites"
        case .pinned:
            "Pinned"
        case .linked:
            "Linked"
        case .leaves:
            "Leaves"
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
    let isLeaf: Bool
    let isOutdated: Bool
    let isInstalledOnRequest: Bool
    let isInstalledAsDependency: Bool
    let autoUpdates: Bool
    let isDeprecated: Bool
    let isDisabled: Bool
    let directDependencies: [String]
    let buildDependencies: [String]
    let testDependencies: [String]
    let recommendedDependencies: [String]
    let optionalDependencies: [String]
    let requirements: [String]
    let directRuntimeDependencies: [String]
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
        if isLeaf {
            badges.append("Leaf")
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

    var packageStateRows: [(title: String, value: String)] {
        var rows: [(String, String)] = [
            ("Pinned", yesNo(isPinned)),
            ("Outdated", yesNo(isOutdated)),
            ("Deprecated", yesNo(isDeprecated)),
            ("Disabled", yesNo(isDisabled))
        ]

        if kind == .formula {
            rows.insert(("Linked", yesNo(isLinked)), at: 1)
            rows.insert(("Leaf", yesNo(isLeaf)), at: 2)
            rows.append(("Install Source", installSourceDescription))
        } else {
            rows.insert(("Auto Updates", yesNo(autoUpdates)), at: 1)
        }

        return rows
    }

    var dependencyGroups: [InstalledPackageDependencyGroup] {
        [
            InstalledPackageDependencyGroup(title: "Direct Runtime Dependencies", items: directRuntimeDependencies),
            InstalledPackageDependencyGroup(title: "Declared Dependencies", items: directDependencies),
            InstalledPackageDependencyGroup(title: "Build Dependencies", items: buildDependencies),
            InstalledPackageDependencyGroup(title: "Test Dependencies", items: testDependencies),
            InstalledPackageDependencyGroup(title: "Recommended Dependencies", items: recommendedDependencies),
            InstalledPackageDependencyGroup(title: "Optional Dependencies", items: optionalDependencies),
            InstalledPackageDependencyGroup(title: "Requirements", items: requirements)
        ]
        .filter { !$0.items.isEmpty }
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }
}
