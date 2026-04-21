import Foundation

struct CommandExecutionProgress<Command: Equatable & Sendable>: Equatable, Sendable {
    let command: Command
    let startedAt: Date
    let finishedAt: Date?

    init(
        command: Command,
        startedAt: Date,
        finishedAt: Date? = nil
    ) {
        self.command = command
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    func finished(at date: Date) -> CommandExecutionProgress<Command> {
        CommandExecutionProgress(command: command, startedAt: startedAt, finishedAt: date)
    }

    func elapsedTime(at referenceDate: Date = .now) -> TimeInterval {
        max(0, (finishedAt ?? referenceDate).timeIntervalSince(startedAt))
    }
}

enum CommandExecutionState<Command: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case running(CommandExecutionProgress<Command>)
    case succeeded(CommandExecutionProgress<Command>, CommandResult)
    case failed(CommandExecutionProgress<Command>, String)
    case cancelled(CommandExecutionProgress<Command>)

    var command: Command? {
        progress?.command
    }

    var progress: CommandExecutionProgress<Command>? {
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
