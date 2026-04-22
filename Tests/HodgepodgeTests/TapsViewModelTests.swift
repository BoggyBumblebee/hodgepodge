import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class TapsViewModelTests: XCTestCase {
    func testLoadIfNeededLoadsTapsAndSelectsFirstTap() async {
        let taps = [
            BrewTap.fixture(name: "timescale/tap", lastCommit: "16 hours ago"),
            BrewTap.fixture(name: "keith/formulae", lastCommit: "6 weeks ago")
        ]
        let viewModel = TapsViewModel(
            provider: MockBrewTapsProvider(result: .success(taps)),
            commandExecutor: MockTapCommandExecutor()
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.tapsState == .loaded(taps)
        }

        XCTAssertEqual(viewModel.filteredTaps.map(\.name), ["keith/formulae", "timescale/tap"])
        XCTAssertEqual(viewModel.selectedTap?.name, "keith/formulae")
    }

    func testFilteredTapsRespectSearchFiltersAndSort() {
        let official = BrewTap.fixture(name: "homebrew/core", isOfficial: true)
        let custom = BrewTap.fixture(name: "example/custom", customRemote: true)
        let privateTap = BrewTap.fixture(name: "example/private", isPrivate: true)
        let viewModel = TapsViewModel(
            provider: MockBrewTapsProvider(result: .success([official, custom, privateTap])),
            commandExecutor: MockTapCommandExecutor()
        )
        viewModel.tapsState = .loaded([official, custom, privateTap])

        viewModel.searchText = "custom"
        XCTAssertEqual(viewModel.filteredTaps.map(\.name), ["example/custom"])

        viewModel.searchText = ""
        viewModel.activeFilters = [.official]
        XCTAssertEqual(viewModel.filteredTaps.map(\.name), ["homebrew/core"])

        viewModel.activeFilters = []
        viewModel.sortOption = .packageCount
        XCTAssertEqual(viewModel.filteredTaps.first?.name, "example/custom")
    }

    func testRunAddTapStoresSuccessStateAndRefreshesSelection() async {
        let addedTap = BrewTap.fixture(name: "timescale/tap")
        let provider = CyclingTapsProvider(results: [[addedTap]])
        let executor = MockTapCommandExecutor(
            result: .success(CommandResult(stdout: "Tapped\n", stderr: "", exitCode: 0)),
            chunks: [.init(stream: .stdout, text: "Cloning...\n")]
        )
        let viewModel = TapsViewModel(
            provider: provider,
            commandExecutor: executor
        )
        viewModel.addTapName = "timescale/tap"

        viewModel.runAddTap()
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return true
            }
            return false
        }
        await waitUntil {
            viewModel.selectedTap?.name == "timescale/tap"
        }

        XCTAssertEqual(executor.arguments, ["tap", "timescale/tap"])
        XCTAssertEqual(viewModel.selectedTap, addedTap)
        XCTAssertTrue(viewModel.actionLogs.contains(where: { $0.text == "Cloning..." }))
        XCTAssertEqual(viewModel.addTapName, "")
    }

    func testUntapSelectedTapRefreshesAndClearsSelectionWhenRemoved() async {
        let tap = BrewTap.fixture(name: "keith/formulae")
        let provider = CyclingTapsProvider(results: [[]])
        let executor = MockTapCommandExecutor(
            result: .success(CommandResult(stdout: "Untapped\n", stderr: "", exitCode: 0))
        )
        let viewModel = TapsViewModel(
            provider: provider,
            commandExecutor: executor
        )
        viewModel.tapsState = .loaded([tap])
        viewModel.selectedTap = tap
        viewModel.untapForce = true

        viewModel.untapSelectedTap()
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return true
            }
            return false
        }
        await waitUntil {
            if case .loaded(let taps) = viewModel.tapsState {
                return taps.isEmpty
            }
            return false
        }

        XCTAssertEqual(executor.arguments, ["untap", "--force", "keith/formulae"])
        XCTAssertNil(viewModel.selectedTap)
    }

    func testToggleAndClearFiltersUpdateState() {
        let viewModel = TapsViewModel(
            provider: MockBrewTapsProvider(result: .success([])),
            commandExecutor: MockTapCommandExecutor()
        )

        XCTAssertFalse(viewModel.isFilterActive(.official))
        viewModel.toggleFilter(.official)
        XCTAssertTrue(viewModel.isFilterActive(.official))
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

private struct MockBrewTapsProvider: BrewTapsProviding {
    let result: Result<[BrewTap], Error>

    func fetchTaps() async throws -> [BrewTap] {
        try result.get()
    }
}

@MainActor
private final class CyclingTapsProvider: BrewTapsProviding, @unchecked Sendable {
    let results: [[BrewTap]]
    private(set) var fetchCallCount = 0

    init(results: [[BrewTap]]) {
        self.results = results
    }

    func fetchTaps() async throws -> [BrewTap] {
        defer { fetchCallCount += 1 }
        return results[min(fetchCallCount, results.count - 1)]
    }
}

@MainActor
private final class MockTapCommandExecutor: BrewCommandExecuting, @unchecked Sendable {
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
