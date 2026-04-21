import Foundation

enum OutdatedPackagesLoadState: Equatable {
    case idle
    case loading
    case loaded([OutdatedPackage])
    case failed(String)
}

enum OutdatedPackageActionKind: String, CaseIterable, Equatable, Identifiable, Sendable {
    case upgrade

    var id: String { rawValue }

    var title: String {
        "Upgrade"
    }

    var requiresConfirmation: Bool {
        true
    }
}

struct OutdatedPackageActionCommand: Equatable, Sendable {
    let kind: OutdatedPackageActionKind
    let packageID: String
    let packageTitle: String
    let arguments: [String]

    var command: String {
        "brew \(arguments.joined(separator: " "))"
    }

    var confirmationTitle: String {
        "\(kind.title) \(packageTitle)?"
    }

    var confirmationMessage: String {
        "Hodgepodge will run `\(command)` using your local Homebrew installation."
    }
}

typealias OutdatedPackageActionProgress = CommandExecutionProgress<OutdatedPackageActionCommand>
typealias OutdatedPackageActionState = CommandExecutionState<OutdatedPackageActionCommand>

enum OutdatedPackageFilterOption: String, CaseIterable, Identifiable, Hashable {
    case pinned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinned:
            "Pinned"
        }
    }
}

enum OutdatedPackageSortOption: String, CaseIterable, Identifiable {
    case name
    case currentVersion
    case packageType

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            "Name"
        case .currentVersion:
            "Current Version"
        case .packageType:
            "Package Type"
        }
    }
}

struct OutdatedPackage: Identifiable, Equatable, Hashable, Sendable {
    let kind: CatalogPackageKind
    let slug: String
    let title: String
    let fullName: String
    let installedVersions: [String]
    let currentVersion: String
    let isPinned: Bool
    let pinnedVersion: String?

    var id: String {
        "\(kind.rawValue):\(slug)"
    }

    var statusBadges: [String] {
        var badges: [String] = []

        if isPinned {
            badges.append("Pinned")
        }

        return badges
    }

    var installedVersionSummary: String {
        let versions = installedVersions.filter { !$0.isEmpty }
        guard !versions.isEmpty else {
            return "Unknown"
        }
        return versions.joined(separator: ", ")
    }

    var upgradeCommand: String {
        "brew upgrade \(kind.installCommandFlag)\(slug)"
    }

    var isUpgradeAvailable: Bool {
        !isPinned
    }

    var upgradeBlockedReason: String? {
        guard !isUpgradeAvailable else {
            return nil
        }

        if let pinnedVersion, !pinnedVersion.isEmpty {
            return "Pinned at \(pinnedVersion). Unpin before upgrading."
        }

        return "Pinned. Unpin before upgrading."
    }

    var upgradeReadinessDescription: String {
        upgradeBlockedReason ?? "Ready to upgrade to \(currentVersion)."
    }

    var primaryInstalledVersion: String {
        installedVersions.first(where: { !$0.isEmpty }) ?? "Unknown"
    }

    func actionCommand(for kind: OutdatedPackageActionKind) -> OutdatedPackageActionCommand {
        OutdatedPackageActionCommand(
            kind: kind,
            packageID: id,
            packageTitle: title,
            arguments: upgradeCommandArguments
        )
    }

    private var upgradeCommandArguments: [String] {
        var arguments = ["upgrade"]
        if self.kind == .cask {
            arguments.append("--cask")
        }
        arguments.append(slug)
        return arguments
    }
}
