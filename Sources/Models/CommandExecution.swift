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

struct CommandLogBuffer: Equatable, Sendable {
    private(set) var entries: [CommandLogEntry] = []
    private var nextIdentifier = 0
    private var pendingText: [CommandLogKind: String] = [:]

    mutating func reset() {
        entries.removeAll()
        nextIdentifier = 0
        pendingText.removeAll()
    }

    mutating func append(
        _ kind: CommandLogKind,
        _ text: String,
        timestamp: Date = Date()
    ) {
        switch kind {
        case .system:
            let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                return
            }
            appendLine(kind, line, timestamp: timestamp)
        case .stdout, .stderr:
            var buffered = pendingText[kind, default: ""]
            buffered.append(text)

            let lines = buffered.components(separatedBy: .newlines)
            pendingText[kind] = lines.last ?? ""

            for line in lines.dropLast() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    continue
                }
                appendLine(kind, trimmed, timestamp: timestamp)
            }
        }
    }

    mutating func flush(timestamp: Date = Date()) {
        for kind in [CommandLogKind.stdout, .stderr] {
            let line = pendingText[kind, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }

            appendLine(kind, line, timestamp: timestamp)
        }

        pendingText.removeAll()
    }

    private mutating func appendLine(
        _ kind: CommandLogKind,
        _ line: String,
        timestamp: Date
    ) {
        entries.append(
            CommandLogEntry(
                id: nextIdentifier,
                kind: kind,
                text: line,
                timestamp: timestamp
            )
        )
        nextIdentifier += 1
    }
}

enum CommandPresentation {
    static func friendlyFailureDescription(
        _ technicalMessage: String,
        fallback: String
    ) -> String {
        let trimmed = technicalMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }

        if isGenericFailureMessage(trimmed) {
            return fallback
        }

        return trimmed
    }

    private static func isGenericFailureMessage(_ message: String) -> Bool {
        if message == CommandRunnerError.unreadablePipe.localizedDescription {
            return true
        }

        return message.range(
            of: #"^The command failed with exit code \d+\.$"#,
            options: .regularExpression
        ) != nil
    }
}
