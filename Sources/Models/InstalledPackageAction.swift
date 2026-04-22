import Foundation

enum InstalledPackageActionKind: String, CaseIterable, Equatable, Identifiable, Sendable {
    case reinstall
    case unlink
    case link
    case unpin
    case pin
    case uninstall

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reinstall:
            "Reinstall"
        case .unlink:
            "Unlink"
        case .link:
            "Link"
        case .unpin:
            "Unpin"
        case .pin:
            "Pin"
        case .uninstall:
            "Uninstall"
        }
    }

    var requiresConfirmation: Bool {
        switch self {
        case .reinstall, .uninstall:
            true
        case .unlink, .link, .unpin, .pin:
            false
        }
    }

    var affectsHomebrewState: Bool {
        true
    }
}

struct InstalledPackageActionCommand: Equatable, Sendable {
    let kind: InstalledPackageActionKind
    let packageID: String
    let packageTitle: String
    let packageKind: CatalogPackageKind
    let arguments: [String]

    var command: String {
        "brew \(arguments.joined(separator: " "))"
    }

    var confirmationTitle: String {
        "\(kind.title) \(packageTitle)?"
    }

    var confirmationMessage: String {
        switch kind {
        case .reinstall:
            return "Hodgepodge will run `\(command)` using your local Homebrew installation. This removes and installs the package again using Homebrew's reinstall flow."
        case .uninstall:
            return "Hodgepodge will run `\(command)` using your local Homebrew installation. This removes the package from this Mac."
        case .unlink, .link, .unpin, .pin:
            return "Hodgepodge will run `\(command)` using your local Homebrew installation."
        }
    }
}

typealias InstalledPackageActionProgress = CommandExecutionProgress<InstalledPackageActionCommand>
typealias InstalledPackageActionState = CommandExecutionState<InstalledPackageActionCommand>

extension InstalledPackage {
    var availableActionKinds: [InstalledPackageActionKind] {
        var actions: [InstalledPackageActionKind] = [.reinstall]

        if kind == .formula {
            actions.append(isLinked ? .unlink : .link)
            actions.append(isPinned ? .unpin : .pin)
        }

        actions.append(.uninstall)
        return actions
    }

    var actionDescription: String {
        if kind == .cask {
            return "Reinstall or uninstall this cask from your local Homebrew setup."
        }

        return "Manage how this formula is linked and pinned, or reinstall and uninstall it locally."
    }

    func actionCommand(for kind: InstalledPackageActionKind) -> InstalledPackageActionCommand {
        InstalledPackageActionCommand(
            kind: kind,
            packageID: id,
            packageTitle: title,
            packageKind: self.kind,
            arguments: commandArguments(for: kind)
        )
    }

    private func commandArguments(for kind: InstalledPackageActionKind) -> [String] {
        switch kind {
        case .reinstall:
            return packageArguments(subcommand: "reinstall")
        case .uninstall:
            return packageArguments(subcommand: "uninstall")
        case .unlink:
            return ["unlink", slug]
        case .link:
            return ["link", slug]
        case .pin:
            return ["pin", slug]
        case .unpin:
            return ["unpin", slug]
        }
    }

    private func packageArguments(subcommand: String) -> [String] {
        var arguments = [subcommand]
        if kind == .cask {
            arguments.append("--cask")
        }
        arguments.append(slug)
        return arguments
    }
}
