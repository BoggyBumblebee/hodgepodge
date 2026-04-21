import Foundation

struct CommandResult: Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

@MainActor
protocol CommandRunning {
    func run(executable: String, arguments: [String]) async throws -> CommandResult
}

enum CommandRunnerError: LocalizedError, Equatable {
    case nonZeroExitCode(CommandResult)
    case unreadablePipe

    var errorDescription: String? {
        switch self {
        case .nonZeroExitCode(let result):
            if result.stderr.isEmpty {
                return "The command failed with exit code \(result.exitCode)."
            }
            return result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        case .unreadablePipe:
            return "The command output could not be read."
        }
    }
}

struct ProcessCommandRunner: CommandRunning {
    func run(executable: String, arguments: [String]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                guard
                    let stdout = String(data: stdoutData, encoding: .utf8),
                    let stderr = String(data: stderrData, encoding: .utf8)
                else {
                    continuation.resume(throwing: CommandRunnerError.unreadablePipe)
                    return
                }

                let result = CommandResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
                if result.exitCode == 0 {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: CommandRunnerError.nonZeroExitCode(result))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
