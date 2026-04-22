import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class ServicesViewModelTests: XCTestCase {
    func testLoadIfNeededLoadsServicesAndSelectsFirstService() async {
        let services = [
            BrewService.fixture(name: "postgresql@17"),
            BrewService.fixture(
                name: "grafana",
                serviceName: "homebrew.mxcl.grafana",
                status: "none",
                isRunning: false,
                isLoaded: false,
                pid: nil,
                user: nil,
                file: "/opt/homebrew/opt/grafana/homebrew.mxcl.grafana.plist",
                isRegistered: false
            )
        ]
        let viewModel = ServicesViewModel(
            provider: MockBrewServicesProvider(result: .success(services)),
            commandExecutor: MockBrewCommandExecutor()
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.servicesState == .loaded(services)
        }

        XCTAssertEqual(viewModel.filteredServices.map(\.name), ["grafana", "postgresql@17"])
        XCTAssertEqual(viewModel.selectedService?.name, "grafana")
    }

    func testFilteredServicesRespectSearchFiltersAndSort() {
        let running = BrewService.fixture(name: "postgresql@17")
        let stopped = BrewService.fixture(
            name: "grafana",
            serviceName: "homebrew.mxcl.grafana",
            status: "none",
            isRunning: false,
            isLoaded: false,
            pid: nil,
            user: nil,
            file: "/opt/homebrew/opt/grafana/homebrew.mxcl.grafana.plist",
            isRegistered: false
        )
        let failed = BrewService.fixture(
            name: "redis",
            serviceName: "homebrew.mxcl.redis",
            status: "error",
            isRunning: false,
            isLoaded: true,
            pid: nil,
            exitCode: 1,
            user: "cmb",
            file: "/Users/cmb/Library/LaunchAgents/homebrew.mxcl.redis.plist"
        )
        let viewModel = ServicesViewModel(
            provider: MockBrewServicesProvider(result: .success([running, stopped, failed])),
            commandExecutor: MockBrewCommandExecutor()
        )
        viewModel.servicesState = .loaded([running, stopped, failed])

        viewModel.searchText = "redis"
        XCTAssertEqual(viewModel.filteredServices.map(\.name), ["redis"])

        viewModel.searchText = ""
        viewModel.activeFilters = [.running]
        XCTAssertEqual(viewModel.filteredServices.map(\.name), ["postgresql@17"])

        viewModel.activeFilters = [.failed]
        XCTAssertEqual(viewModel.filteredServices.map(\.name), ["redis"])

        viewModel.activeFilters = []
        viewModel.sortOption = .user
        XCTAssertEqual(viewModel.filteredServices.map(\.name), ["grafana", "postgresql@17", "redis"])
    }

    func testRefreshServicesStoresFailureMessage() async {
        let viewModel = ServicesViewModel(
            provider: MockBrewServicesProvider(
                result: .failure(HomebrewAPIClientError.requestFailed(503))
            ),
            commandExecutor: MockBrewCommandExecutor()
        )

        viewModel.refreshServices()
        await waitUntil {
            viewModel.servicesState == .failed("The Homebrew API request failed with status code 503.")
        }

        XCTAssertNil(viewModel.selectedService)
    }

    func testRunActionStoresSuccessStateAndRefreshesSelection() async {
        let initial = BrewService.fixture(name: "postgresql@17")
        let refreshed = BrewService.fixture(
            name: "postgresql@17",
            status: "none",
            isRunning: false,
            isLoaded: false,
            pid: nil,
            user: "cmb"
        )
        let provider = CyclingBrewServicesProvider(results: [[refreshed]])
        let executor = MockBrewCommandExecutor(
            result: .success(CommandResult(stdout: "ok\n", stderr: "", exitCode: 0)),
            chunks: [.init(stream: .stdout, text: "Stopping...\n")]
        )
        let viewModel = ServicesViewModel(
            provider: provider,
            commandExecutor: executor
        )
        viewModel.servicesState = .loaded([initial])
        viewModel.selectedService = initial

        viewModel.runAction(.stop, for: initial)
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return true
            }
            return false
        }
        await waitUntil {
            viewModel.selectedService?.status == "none"
        }

        XCTAssertEqual(executor.arguments, ["services", "stop", "postgresql@17"])
        XCTAssertEqual(viewModel.selectedService, refreshed)
        XCTAssertTrue(viewModel.actionLogs.contains(where: { $0.text == "Stopping..." }))
    }

    func testRunCleanupStoresSuccessStateAndPreservesSelection() async {
        let service = BrewService.fixture(name: "postgresql@17")
        let refreshed = BrewService.fixture(name: "postgresql@17", status: "started")
        let provider = CyclingBrewServicesProvider(results: [[refreshed]])
        let executor = MockBrewCommandExecutor(
            result: .success(CommandResult(stdout: "cleaned\n", stderr: "", exitCode: 0)),
            chunks: [.init(stream: .stdout, text: "Cleaning up unused services...\n")]
        )
        let viewModel = ServicesViewModel(
            provider: provider,
            commandExecutor: executor
        )
        viewModel.servicesState = .loaded([service])
        viewModel.selectedService = service

        viewModel.runCleanup()
        await waitUntil {
            if case .succeeded = viewModel.cleanupState {
                return true
            }
            return false
        }
        await waitUntil {
            viewModel.selectedService == refreshed
        }

        XCTAssertEqual(executor.arguments, ["services", "cleanup"])
        XCTAssertEqual(viewModel.cleanupLogs.map(\.text), ["Preparing cleanup for Homebrew services.", "Cleaning up unused services..."])
    }

    func testRunActionStoresFailureState() async {
        let service = BrewService.fixture(name: "postgresql@17")
        let failure = CommandRunnerError.nonZeroExitCode(
            CommandResult(stdout: "", stderr: "Service failed\n", exitCode: 1)
        )
        let viewModel = ServicesViewModel(
            provider: MockBrewServicesProvider(result: .success([service])),
            commandExecutor: MockBrewCommandExecutor(
                result: .failure(failure),
                chunks: [.init(stream: .stderr, text: "Service failed\n")]
            )
        )
        viewModel.servicesState = .loaded([service])

        viewModel.runAction(.restart, for: service)
        await waitUntil {
            if case .failed(_, "Service failed") = viewModel.actionState {
                return true
            }
            return false
        }

        XCTAssertEqual(viewModel.actionLogs.last?.text, "Service failed")
    }

    func testCancelActionStoresCancelledState() async {
        let service = BrewService.fixture(name: "postgresql@17")
        let executor = SuspendingBrewCommandExecutor()
        let viewModel = ServicesViewModel(
            provider: MockBrewServicesProvider(result: .success([service])),
            commandExecutor: executor
        )
        viewModel.servicesState = .loaded([service])

        viewModel.runAction(.restart, for: service)
        await waitUntil {
            viewModel.actionState.command == service.command(for: .restart) &&
                viewModel.actionState.isRunning
        }

        viewModel.cancelAction()
        await waitUntil {
            if case .cancelled = viewModel.actionState {
                return true
            }
            return false
        }

        XCTAssertEqual(viewModel.actionLogs.last?.text, "Restart cancelled.")
    }

    func testRunActionCommandRoutesServiceAndGlobalCommands() async {
        let service = BrewService.fixture(name: "postgresql@17")
        let provider = CyclingBrewServicesProvider(results: [[service], [service], [service]])
        let executor = MockBrewCommandExecutor(
            result: .success(CommandResult(stdout: "done\n", stderr: "", exitCode: 0))
        )
        let viewModel = ServicesViewModel(
            provider: provider,
            commandExecutor: executor
        )
        viewModel.servicesState = .loaded([service])
        viewModel.selectedService = service

        viewModel.runActionCommand(service.command(for: .restart))
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return executor.arguments == ["services", "restart", "postgresql@17"]
            }
            return false
        }

        viewModel.runActionCommand(.cleanupAll())
        await waitUntil {
            if case .succeeded = viewModel.cleanupState {
                return executor.arguments == ["services", "cleanup"]
            }
            return false
        }
    }

    func testToggleAndClearFiltersUpdateState() {
        let viewModel = ServicesViewModel(
            provider: MockBrewServicesProvider(result: .success([])),
            commandExecutor: MockBrewCommandExecutor()
        )

        XCTAssertFalse(viewModel.isFilterActive(.running))
        viewModel.toggleFilter(.running)
        XCTAssertTrue(viewModel.isFilterActive(.running))
        XCTAssertEqual(viewModel.activeFilterCount, 1)

        viewModel.clearFilters()
        XCTAssertTrue(viewModel.activeFilters.isEmpty)
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

private struct MockBrewServicesProvider: BrewServicesProviding {
    let result: Result<[BrewService], Error>

    func fetchServices() async throws -> [BrewService] {
        try result.get()
    }
}

@MainActor
private final class CyclingBrewServicesProvider: BrewServicesProviding, @unchecked Sendable {
    let results: [[BrewService]]
    private(set) var fetchCallCount = 0

    init(results: [[BrewService]]) {
        self.results = results
    }

    func fetchServices() async throws -> [BrewService] {
        defer { fetchCallCount += 1 }
        return results[min(fetchCallCount, results.count - 1)]
    }
}

@MainActor
private final class MockBrewCommandExecutor: BrewCommandExecuting, @unchecked Sendable {
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

@MainActor
private final class SuspendingBrewCommandExecutor: BrewCommandExecuting, @unchecked Sendable {
    private var continuation: CheckedContinuation<CommandResult, Error>?

    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        onLog(.system, "Command started")

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.continuation?.resume(throwing: CancellationError())
                self?.continuation = nil
            }
        }
    }
}
