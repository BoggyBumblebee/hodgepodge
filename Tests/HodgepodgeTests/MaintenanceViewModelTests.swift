import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class MaintenanceViewModelTests: XCTestCase {
    func testLoadIfNeededLoadsDashboard() async {
        let dashboard = BrewMaintenanceDashboard.fixture()
        let viewModel = MaintenanceViewModel(
            provider: MockBrewMaintenanceProvider(result: .success(dashboard)),
            commandExecutor: MockMaintenanceCommandExecutor()
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.dashboardState == .loaded(dashboard)
        }

        XCTAssertEqual(viewModel.dashboard?.config.version, "5.1.7")
        XCTAssertEqual(viewModel.outputText(for: .doctor), dashboard.doctor.rawOutput)
    }

    func testRefreshDashboardStoresFailure() async {
        let viewModel = MaintenanceViewModel(
            provider: MockBrewMaintenanceProvider(
                result: .failure(HomebrewAPIClientError.requestFailed(503))
            ),
            commandExecutor: MockMaintenanceCommandExecutor()
        )

        viewModel.refreshDashboard()
        await waitUntil {
            viewModel.dashboardState == .failed("The Homebrew API request failed with status code 503.")
        }
    }

    func testRunActionStoresSuccessStateAndRefreshesDashboard() async {
        let refreshed = BrewMaintenanceDashboard.fixture(
            doctor: .fixture(warningCount: 0, warnings: [], rawOutput: "No issues.")
        )
        let initial = BrewMaintenanceDashboard.fixture(
            doctor: .fixture(warningCount: 2, warnings: ["Old warning"])
        )
        let provider = CyclingMaintenanceProvider(results: [refreshed])
        let executor = MockMaintenanceCommandExecutor(
            result: .success(CommandResult(stdout: "Updated\n", stderr: "", exitCode: 0)),
            chunks: [.init(stream: .stdout, text: "Updating...\n")]
        )
        let viewModel = MaintenanceViewModel(
            provider: provider,
            commandExecutor: executor
        )
        viewModel.dashboardState = .loaded(initial)

        viewModel.runAction(.update)
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return true
            }
            return false
        }
        await waitUntil {
            viewModel.dashboard?.doctor.warningCount == 0
        }

        XCTAssertEqual(executor.arguments, ["update"])
        XCTAssertTrue(viewModel.actionLogs.contains(where: { $0.text == "Updating..." }))
        XCTAssertEqual(viewModel.selectedOutputSource, .liveAction)
    }

    func testClearActionOutputResetsState() async {
        let viewModel = MaintenanceViewModel(
            provider: MockBrewMaintenanceProvider(result: .success(.fixture())),
            commandExecutor: MockMaintenanceCommandExecutor(
                result: .success(CommandResult(stdout: "ok\n", stderr: "", exitCode: 0))
            )
        )

        viewModel.runAction(.config)
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return true
            }
            return false
        }

        viewModel.clearActionOutput()

        XCTAssertEqual(viewModel.actionState, .idle)
        XCTAssertTrue(viewModel.actionLogs.isEmpty)
    }

    private func waitUntil(
        maxIterations: Int = 50,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @MainActor () -> Bool
    ) async {
        for _ in 0..<maxIterations {
            if condition() {
                return
            }
            await Task.yield()
        }

        XCTFail("Condition was not met in time.", file: file, line: line)
    }
}

private struct MockBrewMaintenanceProvider: BrewMaintenanceProviding {
    let result: Result<BrewMaintenanceDashboard, Error>

    func fetchDashboard() async throws -> BrewMaintenanceDashboard {
        try result.get()
    }
}

@MainActor
private final class CyclingMaintenanceProvider: BrewMaintenanceProviding, @unchecked Sendable {
    let results: [BrewMaintenanceDashboard]
    private(set) var fetchCallCount = 0

    init(results: [BrewMaintenanceDashboard]) {
        self.results = results
    }

    func fetchDashboard() async throws -> BrewMaintenanceDashboard {
        defer { fetchCallCount += 1 }
        return results[min(fetchCallCount, results.count - 1)]
    }
}

@MainActor
private final class MockMaintenanceCommandExecutor: BrewCommandExecuting, @unchecked Sendable {
    let result: Result<CommandResult, Error>
    let chunks: [CommandOutputChunk]
    private(set) var arguments: [String] = []

    init(
        result: Result<CommandResult, Error> = .success(CommandResult(stdout: "", stderr: "", exitCode: 0)),
        chunks: [CommandOutputChunk] = []
    ) {
        self.result = result
        self.chunks = chunks
    }

    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        self.arguments = arguments

        for chunk in chunks {
            let kind: CatalogPackageActionLogKind = switch chunk.stream {
            case .stdout:
                .stdout
            case .stderr:
                .stderr
            }
            onLog(kind, chunk.text)
        }

        return try result.get()
    }
}
