import Foundation

enum CatalogPackageActionKind: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
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

struct CatalogPackageActionCommand: Codable, Equatable, Sendable {
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

enum CommandLogKind: String, CaseIterable, Equatable, Hashable, Sendable {
    case system
    case stdout
    case stderr
}

struct CommandLogEntry: Identifiable, Equatable, Sendable {
    let id: Int
    let kind: CommandLogKind
    let text: String
    let timestamp: Date
}

typealias CatalogPackageActionLogKind = CommandLogKind
typealias CatalogPackageActionLogEntry = CommandLogEntry

enum CatalogPackageActionHistoryOutcome: Codable, Equatable, Sendable {
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

    private enum CodingKeys: String, CodingKey {
        case status
        case exitCode
        case message
    }

    private enum Status: String, Codable {
        case succeeded
        case failed
        case cancelled
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Status.self, forKey: .status) {
        case .succeeded:
            self = .succeeded(try container.decode(Int32.self, forKey: .exitCode))
        case .failed:
            self = .failed(try container.decode(String.self, forKey: .message))
        case .cancelled:
            self = .cancelled
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .succeeded(let exitCode):
            try container.encode(Status.succeeded, forKey: .status)
            try container.encode(exitCode, forKey: .exitCode)
        case .failed(let message):
            try container.encode(Status.failed, forKey: .status)
            try container.encode(message, forKey: .message)
        case .cancelled:
            try container.encode(Status.cancelled, forKey: .status)
        }
    }
}

struct CatalogPackageActionHistoryEntry: Codable, Identifiable, Equatable, Sendable {
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
