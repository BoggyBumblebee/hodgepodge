import Foundation

enum CatalogPackageActionKind: String, CaseIterable, Equatable, Identifiable, Sendable {
    case install
    case fetch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .install:
            "Install"
        case .fetch:
            "Fetch"
        }
    }

    var requiresConfirmation: Bool {
        self == .install
    }
}

struct CatalogPackageActionCommand: Equatable, Sendable {
    let kind: CatalogPackageActionKind
    let packageID: String
    let packageTitle: String
    let command: String
    let arguments: [String]

    var confirmationTitle: String {
        "\(kind.title) \(packageTitle)?"
    }

    var confirmationMessage: String {
        "Hodgepodge will run `\(command)` using your local Homebrew installation."
    }
}

enum CatalogPackageActionLogKind: String, CaseIterable, Equatable, Hashable, Sendable {
    case system
    case stdout
    case stderr
}

struct CatalogPackageActionLogEntry: Identifiable, Equatable, Sendable {
    let id: Int
    let kind: CatalogPackageActionLogKind
    let text: String
}

enum CatalogPackageActionState: Equatable, Sendable {
    case idle
    case running(CatalogPackageActionCommand)
    case succeeded(CatalogPackageActionCommand, CommandResult)
    case failed(CatalogPackageActionCommand, String)
    case cancelled(CatalogPackageActionCommand)

    var command: CatalogPackageActionCommand? {
        switch self {
        case .idle:
            nil
        case .running(let command),
                .succeeded(let command, _),
                .failed(let command, _),
                .cancelled(let command):
            command
        }
    }

    var isRunning: Bool {
        if case .running = self {
            return true
        }

        return false
    }
}

extension CatalogPackageDetail {
    var packageID: String {
        "\(kind.rawValue):\(slug)"
    }

    func actionCommand(for kind: CatalogPackageActionKind) -> CatalogPackageActionCommand {
        switch kind {
        case .install:
            CatalogPackageActionCommand(
                kind: .install,
                packageID: packageID,
                packageTitle: title,
                command: installCommand,
                arguments: installCommandArguments
            )
        case .fetch:
            CatalogPackageActionCommand(
                kind: .fetch,
                packageID: packageID,
                packageTitle: title,
                command: fetchCommand,
                arguments: fetchCommandArguments
            )
        }
    }

    private var installCommandArguments: [String] {
        brewCommandArguments(subcommand: "install")
    }

    private var fetchCommandArguments: [String] {
        brewCommandArguments(subcommand: "fetch")
    }

    private func brewCommandArguments(subcommand: String) -> [String] {
        var arguments = [subcommand]
        if kind == .cask {
            arguments.append("--cask")
        }
        arguments.append(slug)
        return arguments
    }
}
