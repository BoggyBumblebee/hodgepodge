import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class OutdatedPackagesViewModelTests: XCTestCase {
    func testLoadIfNeededLoadsPackagesAndSelectsFirstPackage() async {
        let packages = [
            OutdatedPackage.fixture(
                slug: "wget",
                title: "wget",
                fullName: "homebrew/core/wget",
                installedVersions: ["1.24.5"],
                currentVersion: "1.25.0"
            ),
            OutdatedPackage.fixture(
                kind: .cask,
                slug: "docker-desktop",
                title: "docker-desktop",
                fullName: "docker-desktop",
                installedVersions: ["4.67.0"],
                currentVersion: "4.68.0"
            )
        ]
        let viewModel = OutdatedPackagesViewModel(
            provider: MockOutdatedPackagesProvider(result: .success(packages)),
            commandExecutor: MockOutdatedBrewCommandExecutor()
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.packagesState == .loaded(packages)
        }

        XCTAssertEqual(viewModel.filteredPackages, [packages[1], packages[0]])
        XCTAssertEqual(viewModel.selectedPackage, packages[1])
    }

    func testFilteredPackagesRespectSearchScopeFiltersAndSort() {
        let packages = [
            OutdatedPackage.fixture(
                slug: "alpha",
                title: "Alpha",
                fullName: "homebrew/core/alpha",
                installedVersions: ["1.0.0"],
                currentVersion: "1.2.0",
                isPinned: true,
                pinnedVersion: "1.0.0"
            ),
            OutdatedPackage.fixture(
                kind: .cask,
                slug: "docker-desktop",
                title: "Docker Desktop",
                fullName: "docker-desktop",
                installedVersions: ["4.67.0"],
                currentVersion: "4.68.0"
            ),
            OutdatedPackage.fixture(
                slug: "beta",
                title: "Beta",
                fullName: "homebrew/core/beta",
                installedVersions: ["2.0.0"],
                currentVersion: "2.1.0"
            )
        ]
        let viewModel = OutdatedPackagesViewModel(
            provider: MockOutdatedPackagesProvider(result: .success(packages)),
            commandExecutor: MockOutdatedBrewCommandExecutor()
        )
        viewModel.packagesState = .loaded(packages)

        viewModel.searchText = "docker"
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Docker Desktop"])

        viewModel.searchText = ""
        viewModel.scope = .formula
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Alpha", "Beta"])

        viewModel.scope = .all
        viewModel.activeFilters = [.pinned]
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Alpha"])

        viewModel.activeFilters = []
        viewModel.sortOption = .currentVersion
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Docker Desktop", "Beta", "Alpha"])
    }

    func testRefreshPackagesStoresFailureMessage() async {
        let viewModel = OutdatedPackagesViewModel(
            provider: MockOutdatedPackagesProvider(
                result: .failure(HomebrewAPIClientError.requestFailed(503))
            ),
            commandExecutor: MockOutdatedBrewCommandExecutor()
        )

        viewModel.refreshPackages()
        await waitUntil {
            viewModel.packagesState == .failed("The Homebrew API request failed with status code 503.")
        }

        XCTAssertEqual(
            viewModel.packagesState,
            .failed("The Homebrew API request failed with status code 503.")
        )
        XCTAssertNil(viewModel.selectedPackage)
    }

    func testToggleAndClearFiltersUpdateState() {
        let viewModel = OutdatedPackagesViewModel(
            provider: MockOutdatedPackagesProvider(result: .success([])),
            commandExecutor: MockOutdatedBrewCommandExecutor()
        )

        XCTAssertFalse(viewModel.isFilterActive(.pinned))

        viewModel.toggleFilter(.pinned)
        XCTAssertTrue(viewModel.isFilterActive(.pinned))
        XCTAssertEqual(viewModel.activeFilterCount, 1)

        viewModel.clearFilters()
        XCTAssertTrue(viewModel.activeFilters.isEmpty)
    }

    func testLoadIfNeededDoesNotRefreshWhenAlreadyLoaded() async {
        let provider = CountingOutdatedPackagesProvider(result: .success([.fixture()]))
        let viewModel = OutdatedPackagesViewModel(
            provider: provider,
            commandExecutor: MockOutdatedBrewCommandExecutor()
        )
        viewModel.packagesState = .loaded([.fixture()])

        viewModel.loadIfNeeded()
        await Task.yield()

        XCTAssertEqual(provider.fetchCallCount, 0)
    }

    func testRefreshPackagesPreservesMatchingSelection() async {
        let original = OutdatedPackage.fixture(
            slug: "wget",
            title: "wget",
            fullName: "homebrew/core/wget",
            installedVersions: ["1.24.5"],
            currentVersion: "1.25.0"
        )
        let refreshed = OutdatedPackage.fixture(
            slug: "wget",
            title: "wget",
            fullName: "homebrew/core/wget",
            installedVersions: ["1.24.6"],
            currentVersion: "1.25.1"
        )
        let provider = CyclingOutdatedPackagesProvider(results: [[original], [refreshed]])
        let viewModel = OutdatedPackagesViewModel(
            provider: provider,
            commandExecutor: MockOutdatedBrewCommandExecutor()
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.selectedPackage?.currentVersion == "1.25.0"
        }

        viewModel.refreshPackages()
        await waitUntil {
            viewModel.selectedPackage?.currentVersion == "1.25.1"
        }

        XCTAssertEqual(viewModel.selectedPackage, refreshed)
    }

    func testRunActionStoresSuccessStateAndRetainsSelectionWhenPackageLeavesOutdatedList() async {
        let original = OutdatedPackage.fixture(slug: "wget", currentVersion: "1.25.0")
        let provider = CyclingOutdatedPackagesProvider(results: [[]])
        let executor = MockOutdatedBrewCommandExecutor(
            result: .success(CommandResult(stdout: "Upgraded\n", stderr: "", exitCode: 0)),
            chunks: [.init(stream: .stdout, text: "Pouring...\n")]
        )
        let viewModel = OutdatedPackagesViewModel(
            provider: provider,
            commandExecutor: executor
        )
        viewModel.packagesState = .loaded([original])
        viewModel.selectedPackage = original

        viewModel.runAction(.upgrade, for: original)
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return true
            }
            return false
        }
        await waitUntil {
            if case .loaded(let packages) = viewModel.packagesState {
                return packages.isEmpty
            }
            return false
        }

        XCTAssertEqual(executor.arguments, ["upgrade", "wget"])
        XCTAssertEqual(viewModel.selectedPackage, original)
        XCTAssertTrue(viewModel.actionLogs.contains(where: { $0.text == "Pouring..." }))
        XCTAssertFalse(viewModel.isPackageInCurrentSnapshot(original))
    }

    func testRunActionStoresFailureState() async {
        let package = OutdatedPackage.fixture(slug: "wget")
        let viewModel = OutdatedPackagesViewModel(
            provider: MockOutdatedPackagesProvider(result: .success([package])),
            commandExecutor: MockOutdatedBrewCommandExecutor(
                result: .failure(CommandRunnerError.nonZeroExitCode(
                    CommandResult(stdout: "", stderr: "Already installed\n", exitCode: 1)
                ))
            )
        )

        viewModel.runAction(.upgrade, for: package)
        await waitUntil {
            if case .failed = viewModel.actionState {
                return true
            }
            return false
        }
    }

    func testPinnedPackageDoesNotStartUpgradeAction() async {
        let package = OutdatedPackage.fixture(isPinned: true, pinnedVersion: "1.24.5")
        let executor = MockOutdatedBrewCommandExecutor()
        let viewModel = OutdatedPackagesViewModel(
            provider: MockOutdatedPackagesProvider(result: .success([package])),
            commandExecutor: executor
        )

        viewModel.runAction(.upgrade, for: package)
        await Task.yield()

        XCTAssertEqual(viewModel.actionState, .idle)
        XCTAssertTrue(executor.arguments.isEmpty)
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

private struct MockOutdatedPackagesProvider: OutdatedPackagesProviding {
    let result: Result<[OutdatedPackage], Error>

    func fetchOutdatedPackages() async throws -> [OutdatedPackage] {
        try result.get()
    }
}

@MainActor
private final class MockOutdatedBrewCommandExecutor: BrewCommandExecuting, @unchecked Sendable {
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
private final class CountingOutdatedPackagesProvider: OutdatedPackagesProviding, @unchecked Sendable {
    let result: Result<[OutdatedPackage], Error>
    private(set) var fetchCallCount = 0

    init(result: Result<[OutdatedPackage], Error>) {
        self.result = result
    }

    func fetchOutdatedPackages() async throws -> [OutdatedPackage] {
        fetchCallCount += 1
        return try result.get()
    }
}

@MainActor
private final class CyclingOutdatedPackagesProvider: OutdatedPackagesProviding, @unchecked Sendable {
    let results: [[OutdatedPackage]]
    private(set) var fetchCallCount = 0

    init(results: [[OutdatedPackage]]) {
        self.results = results
    }

    func fetchOutdatedPackages() async throws -> [OutdatedPackage] {
        defer { fetchCallCount += 1 }
        return results[min(fetchCallCount, results.count - 1)]
    }
}
