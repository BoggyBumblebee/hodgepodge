import Foundation

protocol BrewMaintenanceProviding: Sendable {
    func fetchDashboard() async throws -> BrewMaintenanceDashboard
}

struct BrewMaintenanceProvider: BrewMaintenanceProviding, @unchecked Sendable {
    private let brewLocator: any BrewLocating
    private let runner: any CommandRunning

    init(
        brewLocator: any BrewLocating,
        runner: any CommandRunning
    ) {
        self.brewLocator = brewLocator
        self.runner = runner
    }

    func fetchDashboard() async throws -> BrewMaintenanceDashboard {
        let installation = try await brewLocator.locate()
        let executable = installation.brewPath

        let configOutput = try await runCollectingOutput(
            executable: executable,
            arguments: ["config"]
        )
        let doctorOutput = try await runCollectingOutput(
            executable: executable,
            arguments: ["doctor"]
        )
        let cleanupOutput = try await runCollectingOutput(
            executable: executable,
            arguments: ["cleanup", "--dry-run"]
        )
        let autoremoveOutput = try await runCollectingOutput(
            executable: executable,
            arguments: ["autoremove", "--dry-run"]
        )

        return BrewMaintenanceDashboard(
            config: BrewMaintenanceParser.configSnapshot(from: configOutput),
            doctor: BrewMaintenanceParser.doctorSnapshot(from: doctorOutput),
            cleanup: BrewMaintenanceParser.dryRunSnapshot(task: .cleanup, from: cleanupOutput),
            autoremove: BrewMaintenanceParser.dryRunSnapshot(task: .autoremove, from: autoremoveOutput),
            capturedAt: .now
        )
    }

    private func runCollectingOutput(
        executable: String,
        arguments: [String]
    ) async throws -> String {
        do {
            let result = try await runner.run(executable: executable, arguments: arguments)
            return merge(stdout: result.stdout, stderr: result.stderr)
        } catch let error as CommandRunnerError {
            switch error {
            case .nonZeroExitCode(let result):
                return merge(stdout: result.stdout, stderr: result.stderr)
            case .unreadablePipe:
                throw error
            }
        } catch {
            throw error
        }
    }

    private func merge(stdout: String, stderr: String) -> String {
        [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: stdout.isEmpty || stderr.isEmpty ? "" : "\n")
    }
}
