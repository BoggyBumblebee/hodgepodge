import Foundation

struct CommandResult: Equatable, Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

struct CommandOutputChunk: Equatable, Sendable {
    enum Stream: String, Equatable, Sendable {
        case stdout
        case stderr
    }

    let stream: Stream
    let text: String
}

@MainActor
protocol CommandRunning {
    func run(
        executable: String,
        arguments: [String],
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) async throws -> CommandResult
}

extension CommandRunning {
    func run(executable: String, arguments: [String]) async throws -> CommandResult {
        try await run(executable: executable, arguments: arguments, onOutput: nil)
    }
}

enum CommandRunnerError: LocalizedError, Equatable {
    case nonZeroExitCode(CommandResult)
    case unreadablePipe

    var errorDescription: String? {
        switch self {
        case .nonZeroExitCode(let result):
            let message = if result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if message.isEmpty {
                return "The command failed with exit code \(result.exitCode)."
            }
            return message
        case .unreadablePipe:
            return "The command output could not be read."
        }
    }
}

struct ProcessCommandRunner: CommandRunning {
    func run(
        executable: String,
        arguments: [String],
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) async throws -> CommandResult {
        let state = ProcessRunState()
        let outputBuffer = OutputBuffer()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                state.install(process)

                stdoutPipe.fileHandleForReading.readabilityHandler = makeReadabilityHandler(
                    stream: .stdout,
                    outputBuffer: outputBuffer,
                    onOutput: onOutput
                )
                stderrPipe.fileHandleForReading.readabilityHandler = makeReadabilityHandler(
                    stream: .stderr,
                    outputBuffer: outputBuffer,
                    onOutput: onOutput
                )

                process.terminationHandler = makeTerminationHandler(
                    stdoutHandle: stdoutPipe.fileHandleForReading,
                    stderrHandle: stderrPipe.fileHandleForReading,
                    outputBuffer: outputBuffer,
                    onOutput: onOutput,
                    state: state,
                    continuation: continuation
                )

                do {
                    try process.run()
                    if state.wasCancelled {
                        state.cancel()
                    }
                } catch {
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    state.resume(continuation, with: .failure(error))
                }
            }
        } onCancel: {
            state.cancel()
        }
    }

    private nonisolated func makeReadabilityHandler(
        stream: CommandOutputChunk.Stream,
        outputBuffer: OutputBuffer,
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) -> @Sendable (FileHandle) -> Void {
        { handle in
            _ = appendData(
                handle.availableData,
                stream: stream,
                outputBuffer: outputBuffer,
                onOutput: onOutput
            )
        }
    }

    private nonisolated func makeTerminationHandler(
        stdoutHandle: FileHandle,
        stderrHandle: FileHandle,
        outputBuffer: OutputBuffer,
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?,
        state: ProcessRunState,
        continuation: CheckedContinuation<CommandResult, Error>
    ) -> @Sendable (Process) -> Void {
        { process in
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil

            if let error = appendTerminationOutput(
                stdoutHandle: stdoutHandle,
                stderrHandle: stderrHandle,
                outputBuffer: outputBuffer,
                onOutput: onOutput
            ) {
                state.resume(continuation, with: .failure(error))
                return
            }

            if state.wasCancelled {
                state.resume(continuation, with: .failure(CancellationError()))
                return
            }

            let result = outputBuffer.result(exitCode: process.terminationStatus)
            let completion: Result<CommandResult, Error> = if result.exitCode == 0 {
                .success(result)
            } else {
                .failure(CommandRunnerError.nonZeroExitCode(result))
            }
            state.resume(continuation, with: completion)
        }
    }

    private nonisolated func appendTerminationOutput(
        stdoutHandle: FileHandle,
        stderrHandle: FileHandle,
        outputBuffer: OutputBuffer,
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) -> CommandRunnerError? {
        appendRemainingOutput(
            from: stdoutHandle,
            stream: .stdout,
            outputBuffer: outputBuffer,
            onOutput: onOutput
        ) ?? appendRemainingOutput(
            from: stderrHandle,
            stream: .stderr,
            outputBuffer: outputBuffer,
            onOutput: onOutput
        )
    }

    private nonisolated func appendRemainingOutput(
        from handle: FileHandle,
        stream: CommandOutputChunk.Stream,
        outputBuffer: OutputBuffer,
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) -> CommandRunnerError? {
        appendData(
            handle.readDataToEndOfFile(),
            stream: stream,
            outputBuffer: outputBuffer,
            onOutput: onOutput
        )
    }

    private nonisolated func appendData(
        _ data: Data,
        stream: CommandOutputChunk.Stream,
        outputBuffer: OutputBuffer,
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) -> CommandRunnerError? {
        do {
            guard let text = try outputBuffer.append(data, stream: stream) else {
                return nil
            }

            guard let onOutput else {
                return nil
            }

            Task { @MainActor in
                onOutput(CommandOutputChunk(stream: stream, text: text))
            }
            return nil
        } catch let error as CommandRunnerError {
            return error
        } catch {
            return .unreadablePipe
        }
    }
}

private final class ProcessRunState: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var didResume = false
    private var isCancelled = false

    func install(_ process: Process) {
        lock.lock()
        defer { lock.unlock() }
        self.process = process
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let process = process
        lock.unlock()

        guard let process, process.isRunning else {
            return
        }

        process.interrupt()
        process.terminate()
    }

    var wasCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelled
    }

    func resume(
        _ continuation: CheckedContinuation<CommandResult, Error>,
        with result: Result<CommandResult, Error>
    ) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }

        didResume = true
        process = nil
        lock.unlock()

        continuation.resume(with: result)
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var stdout = ""
    private var stderr = ""

    func append(_ data: Data, stream: CommandOutputChunk.Stream) throws -> String? {
        guard !data.isEmpty else {
            return nil
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw CommandRunnerError.unreadablePipe
        }

        lock.lock()
        defer { lock.unlock() }

        switch stream {
        case .stdout:
            stdout.append(text)
        case .stderr:
            stderr.append(text)
        }

        return text
    }

    func result(exitCode: Int32) -> CommandResult {
        lock.lock()
        defer { lock.unlock() }
        return CommandResult(stdout: stdout, stderr: stderr, exitCode: exitCode)
    }
}
