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
    let timestamp: Date
}

enum CatalogPackageActionHistoryOutcome: Equatable, Sendable {
    case succeeded(Int32)
    case failed(String)
    case cancelled

    var title: String {
        switch self {
        case .succeeded:
            "Completed"
        case .failed:
            "Failed"
        case .cancelled:
            "Cancelled"
        }
    }

    var detail: String {
        switch self {
        case .succeeded(let exitCode):
            "Exit code \(exitCode)"
        case .failed(let message):
            message
        case .cancelled:
            "Stopped before completion"
        }
    }
}

struct CatalogPackageActionHistoryEntry: Identifiable, Equatable, Sendable {
    let id: Int
    let command: CatalogPackageActionCommand
    let startedAt: Date
    let finishedAt: Date
    let outcome: CatalogPackageActionHistoryOutcome
    let outputLineCount: Int

    var duration: TimeInterval {
        max(0, finishedAt.timeIntervalSince(startedAt))
    }
}

struct CatalogPackageActionProgress: Equatable, Sendable {
    let command: CatalogPackageActionCommand
    let startedAt: Date
    let finishedAt: Date?

    init(
        command: CatalogPackageActionCommand,
        startedAt: Date,
        finishedAt: Date? = nil
    ) {
        self.command = command
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    func finished(at date: Date) -> CatalogPackageActionProgress {
        CatalogPackageActionProgress(
            command: command,
            startedAt: startedAt,
            finishedAt: date
        )
    }

    func elapsedTime(at referenceDate: Date = .now) -> TimeInterval {
        let endDate = finishedAt ?? referenceDate
        return max(0, endDate.timeIntervalSince(startedAt))
    }
}

enum CatalogPackageActionState: Equatable, Sendable {
    case idle
    case running(CatalogPackageActionProgress)
    case succeeded(CatalogPackageActionProgress, CommandResult)
    case failed(CatalogPackageActionProgress, String)
    case cancelled(CatalogPackageActionProgress)

    var command: CatalogPackageActionCommand? {
        progress?.command
    }

    var progress: CatalogPackageActionProgress? {
        switch self {
        case .idle:
            nil
        case .running(let progress),
                .succeeded(let progress, _),
                .failed(let progress, _),
                .cancelled(let progress):
            progress
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
