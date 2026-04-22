import Foundation

protocol BrewCommandExecuting: Sendable {
    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult
}

extension BrewCommandExecuting {
    func execute(
        command: CatalogPackageActionCommand,
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        try await execute(arguments: command.arguments, onLog: onLog)
    }
}

struct BrewCommandExecutor: BrewCommandExecuting, @unchecked Sendable {
    private let brewLocator: any BrewLocating
    private let runner: any CommandRunning

    init(
        brewLocator: any BrewLocating,
        runner: any CommandRunning
    ) {
        self.brewLocator = brewLocator
        self.runner = runner
    }

    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        let installation = try await brewLocator.locate()
        let resolvedArguments = try installation.compatibility.normalized(arguments: arguments)
        await onLog(.system, "Using Homebrew at \(installation.brewPath)")
        if resolvedArguments != arguments {
            await onLog(.system, "Adjusted command arguments for Homebrew \(installation.version).")
        }
        await onLog(.system, "$ \(installation.brewPath) \(resolvedArguments.joined(separator: " "))")

        return try await runner.run(
            executable: installation.brewPath,
            arguments: resolvedArguments,
            onOutput: { chunk in
                let logKind: CatalogPackageActionLogKind = switch chunk.stream {
                case .stdout:
                    .stdout
                case .stderr:
                    .stderr
                }

                onLog(logKind, chunk.text)
            }
        )
    }
}
