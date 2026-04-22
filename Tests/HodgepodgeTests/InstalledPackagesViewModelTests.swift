import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class InstalledPackagesViewModelTests: XCTestCase {
    func testLoadIfNeededLoadsPackagesAndSelectsFirstPackage() async {
        let packages = [
            makePackage(
                title: "wget",
                version: "1.25.0",
                installedAt: Date(timeIntervalSince1970: 100)
            ),
            makePackage(
                kind: .cask,
                slug: "docker-desktop",
                title: "Docker Desktop",
                version: "4.68.0",
                installedAt: Date(timeIntervalSince1970: 200)
            )
        ]
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success(packages)),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
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
            makePackage(
                slug: "alpha",
                title: "Alpha",
                version: "1.0.0",
                installedAt: Date(timeIntervalSince1970: 100),
                isInstalledOnRequest: true,
                isLeaf: true
            ),
            makePackage(
                kind: .cask,
                slug: "docker-desktop",
                title: "Docker Desktop",
                version: "4.68.0",
                tap: "homebrew/cask",
                installedAt: Date(timeIntervalSince1970: 300),
                autoUpdates: true
            ),
            makePackage(
                slug: "beta",
                title: "Beta",
                version: "2.0.0",
                installedAt: Date(timeIntervalSince1970: 200),
                isInstalledAsDependency: true
            )
        ]
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success(packages)),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )
        viewModel.packagesState = .loaded(packages)
        viewModel.favoritePackageIDs = [packages[1].id]

        viewModel.searchText = "docker"
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Docker Desktop"])

        viewModel.searchText = ""
        viewModel.scope = .formula
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Beta", "Alpha"])

        viewModel.scope = .all
        viewModel.activeFilters = [.favorites]
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Docker Desktop"])

        viewModel.activeFilters = [.installedAsDependency]
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Beta"])

        viewModel.activeFilters = [.leaves]
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Alpha"])

        viewModel.activeFilters = []
        viewModel.sortOption = .name
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Alpha", "Beta", "Docker Desktop"])
    }

    func testRefreshPackagesStoresFailureMessage() async {
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(
                result: .failure(HomebrewAPIClientError.requestFailed(503))
            ),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
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
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([])),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )

        XCTAssertFalse(viewModel.isFilterActive(.pinned))

        viewModel.toggleFilter(.pinned)
        XCTAssertTrue(viewModel.isFilterActive(.pinned))
        XCTAssertEqual(viewModel.activeFilterCount, 1)

        viewModel.toggleFilter(.pinned)
        XCTAssertFalse(viewModel.isFilterActive(.pinned))

        viewModel.activeFilters = [.linked, .outdated]
        viewModel.clearFilters()
        XCTAssertTrue(viewModel.activeFilters.isEmpty)
    }

    func testLoadIfNeededDoesNotRefreshWhenAlreadyLoaded() async {
        let provider = CountingInstalledPackagesProvider(
            result: .success([makePackage()])
        )
        let viewModel = InstalledPackagesViewModel(
            provider: provider,
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )
        viewModel.packagesState = .loaded([makePackage()])

        viewModel.loadIfNeeded()
        await Task.yield()

        XCTAssertEqual(provider.fetchCallCount, 0)
    }

    func testRefreshPackagesPreservesMatchingSelection() async {
        let original = makePackage(
            slug: "wget",
            title: "wget",
            version: "1.25.0",
            installedAt: Date(timeIntervalSince1970: 100)
        )
        let refreshed = makePackage(
            slug: "wget",
            title: "wget",
            version: "1.25.1",
            installedAt: Date(timeIntervalSince1970: 200)
        )
        let provider = CyclingInstalledPackagesProvider(results: [[original], [refreshed]])
        let viewModel = InstalledPackagesViewModel(
            provider: provider,
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.selectedPackage?.version == "1.25.0"
        }

        viewModel.refreshPackages()
        await waitUntil {
            viewModel.selectedPackage?.version == "1.25.1"
        }

        XCTAssertEqual(viewModel.selectedPackage, refreshed)
    }

    func testStateCountsReflectPackageStateInventory() {
        let packages = [
            makePackage(isPinned: true, isLinked: true, isInstalledOnRequest: true, isLeaf: true),
            makePackage(slug: "beta", title: "Beta", isInstalledAsDependency: true),
            makePackage(kind: .cask, slug: "docker-desktop", title: "Docker Desktop", autoUpdates: true)
        ]
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success(packages)),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )
        viewModel.packagesState = .loaded(packages)

        XCTAssertEqual(
            viewModel.stateCounts,
            [
                InstalledPackageStateCount(title: "On Request", count: 1),
                InstalledPackageStateCount(title: "Dependency", count: 1),
                InstalledPackageStateCount(title: "Leaves", count: 1),
                InstalledPackageStateCount(title: "Pinned", count: 1)
            ]
        )
    }

    func testDependencySnapshotBuildsTreesAndMetrics() {
        let packages = [
            makePackage(
                slug: "wget",
                title: "wget",
                directDependencies: ["openssl@3", "zlib"],
                directRuntimeDependencies: ["openssl@3"]
            ),
            makePackage(
                slug: "openssl@3",
                title: "openssl@3",
                directDependencies: ["zlib"],
                directRuntimeDependencies: ["zlib"]
            ),
            makePackage(
                slug: "zlib",
                title: "zlib",
                isLeaf: true
            )
        ]
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success(packages)),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )
        viewModel.packagesState = .loaded(packages)

        let snapshot = viewModel.dependencySnapshot(for: packages[0])

        XCTAssertEqual(
            snapshot?.summaryMetrics,
            [
                InstalledPackageDependencyMetric(title: "Direct Dependencies", value: "2"),
                InstalledPackageDependencyMetric(title: "Transitive Dependencies", value: "2"),
                InstalledPackageDependencyMetric(title: "Direct Dependents", value: "0"),
                InstalledPackageDependencyMetric(title: "Transitive Dependents", value: "0")
            ]
        )
        XCTAssertEqual(snapshot?.dependencyTree.map(\.title), ["openssl@3", "zlib", "zlib"])
        XCTAssertEqual(snapshot?.dependentTree, [])
    }

    func testSelectPackageUpdatesSelectionWhenIDExists() {
        let packages = [
            makePackage(slug: "wget", title: "wget"),
            makePackage(slug: "openssl@3", title: "openssl@3")
        ]
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success(packages)),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )
        viewModel.packagesState = .loaded(packages)
        viewModel.selectedPackage = packages[0]

        viewModel.selectPackage(id: packages[1].id)

        XCTAssertEqual(viewModel.selectedPackage, packages[1])
    }

    func testInitLoadsPersistedFavorites() {
        let favoritesStore = MockFavoritePackageStore(initialIDs: ["formula:wget"])
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([])),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker(),
            favoritesStore: favoritesStore
        )

        XCTAssertEqual(viewModel.favoritePackageIDs, ["formula:wget"])
    }

    func testToggleFavoritePersistsSharedFavorites() {
        let package = makePackage(slug: "wget", title: "wget")
        let favoritesStore = MockFavoritePackageStore()
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([package])),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker(),
            favoritesStore: favoritesStore
        )

        viewModel.toggleFavorite(package)

        XCTAssertTrue(viewModel.isFavorite(package))
        XCTAssertEqual(favoritesStore.savedIDs.last, [package.id])
    }

    func testFavoritePackageIDsUpdateWhenSharedNotificationIsPosted() async {
        let notificationCenter = NotificationCenter()
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([])),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker(),
            favoritesStore: MockFavoritePackageStore(),
            notificationCenter: notificationCenter
        )

        notificationCenter.post(
            name: .favoritePackageIDsDidChange,
            object: nil,
            userInfo: [FavoritePackageNotificationUserInfoKey.ids: ["formula:wget", "cask:docker-desktop"]]
        )

        await waitUntil {
            viewModel.favoritePackageIDs == ["formula:wget", "cask:docker-desktop"]
        }
    }

    func testOpenAnalyticsItemSelectsMatchingLoadedInstalledPackage() {
        let package = makePackage(slug: "wget", title: "wget")
        let analyticsItem = CatalogAnalyticsItem(
            kind: .formula,
            slug: "wget",
            rank: 1,
            count: "1,200",
            percent: "9.72"
        )
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([package])),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )
        viewModel.packagesState = .loaded([package])

        viewModel.openAnalyticsItem(analyticsItem)

        XCTAssertEqual(viewModel.selectedPackage, package)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.scope, .all)
        XCTAssertTrue(viewModel.activeFilters.isEmpty)
        XCTAssertTrue(viewModel.isInstalled(analyticsItem))
    }

    func testOpenAnalyticsItemLoadsInstalledPackagesWhenNeeded() async {
        let package = makePackage(
            kind: .cask,
            slug: "docker-desktop",
            title: "Docker Desktop"
        )
        let analyticsItem = CatalogAnalyticsItem(
            kind: .cask,
            slug: "docker-desktop",
            rank: 1,
            count: "900",
            percent: "20.00"
        )
        let provider = CountingInstalledPackagesProvider(result: .success([package]))
        let viewModel = InstalledPackagesViewModel(
            provider: provider,
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )
        viewModel.searchText = "old"
        viewModel.scope = .formula
        viewModel.activeFilters = [.favorites]

        viewModel.openAnalyticsItem(analyticsItem)
        await waitUntil {
            viewModel.selectedPackage == package
        }

        XCTAssertEqual(provider.fetchCallCount, 1)
        XCTAssertEqual(viewModel.packagesState, .loaded([package]))
        XCTAssertEqual(viewModel.selectedPackage, package)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.scope, .all)
        XCTAssertTrue(viewModel.activeFilters.isEmpty)
        XCTAssertTrue(viewModel.isInstalled(analyticsItem))
    }

    func testGenerateBrewfileUsesDestinationPickerAndRunsDumpForScope() async {
        let destinationURL = URL(fileURLWithPath: "/tmp/Brewfile-formulae")
        let executor = MockInstalledPackagesCommandExecutor(
            result: .success(CommandResult(stdout: "", stderr: "", exitCode: 0))
        )
        let picker = MockBrewfileDumpDestinationPicker(result: destinationURL)
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([makePackage()])),
            commandExecutor: executor,
            destinationPicker: picker
        )
        viewModel.scope = .formula

        viewModel.generateBrewfile()
        await waitUntil {
            if case .succeeded = viewModel.exportState {
                return true
            }
            return false
        }

        XCTAssertEqual(picker.suggestedFileNames, ["Brewfile-formulae"])
        XCTAssertEqual(
            executor.executedArguments,
            [["bundle", "dump", "--file", "/tmp/Brewfile-formulae", "--force", "--formula"]]
        )
        XCTAssertFalse(viewModel.exportLogs.isEmpty)
    }

    func testGenerateBrewfileDoesNothingWhenDestinationPickerCancels() async {
        let executor = MockInstalledPackagesCommandExecutor()
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([])),
            commandExecutor: executor,
            destinationPicker: MockBrewfileDumpDestinationPicker(result: nil)
        )

        viewModel.generateBrewfile()
        await Task.yield()

        XCTAssertEqual(viewModel.exportState, .idle)
        XCTAssertTrue(executor.executedArguments.isEmpty)
    }

    func testClearExportOutputResetsExportState() {
        let destinationURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([])),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker(result: destinationURL)
        )
        let command = InstalledPackagesBrewfileExportCommand(scope: .all, destinationURL: destinationURL)
        viewModel.exportState = .running(
            InstalledPackagesBrewfileExportProgress(
                command: command,
                startedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        viewModel.exportLogs = [
            CommandLogEntry(
                id: 0,
                kind: .system,
                text: "Generating Brewfile",
                timestamp: Date(timeIntervalSince1970: 1_001)
            )
        ]

        viewModel.clearExportOutput()

        XCTAssertEqual(viewModel.exportState, .idle)
        XCTAssertTrue(viewModel.exportLogs.isEmpty)
    }

    func testRunActionStoresSuccessStateAndPreservesRemovedPackageSelectionForOutputReview() async {
        let package = makePackage(slug: "wget", title: "wget")
        let provider = CyclingInstalledPackagesProvider(results: [[]])
        let executor = MockInstalledPackagesCommandExecutor(
            result: .success(CommandResult(stdout: "Uninstalled\n", stderr: "", exitCode: 0)),
            chunks: [.init(stream: .stdout, text: "Removing...\n")]
        )
        let viewModel = InstalledPackagesViewModel(
            provider: provider,
            commandExecutor: executor,
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )
        viewModel.packagesState = .loaded([package])
        viewModel.selectedPackage = package

        viewModel.runAction(.uninstall, for: package)
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

        XCTAssertEqual(executor.executedArguments, [["uninstall", "wget"]])
        XCTAssertEqual(viewModel.selectedPackage, package)
        XCTAssertFalse(viewModel.isPackageInCurrentSnapshot(package))
        XCTAssertTrue(viewModel.actionLogs.contains(where: { $0.text == "Removing..." }))
    }

    func testRunActionRefreshesPackageSelectionAfterSuccessfulFormulaAction() async {
        let original = makePackage(slug: "wget", title: "wget", isPinned: false, isLinked: true)
        let refreshed = makePackage(slug: "wget", title: "wget", isPinned: true, isLinked: true)
        let provider = CyclingInstalledPackagesProvider(results: [[refreshed]])
        let executor = MockInstalledPackagesCommandExecutor(
            result: .success(CommandResult(stdout: "Pinned\n", stderr: "", exitCode: 0))
        )
        let viewModel = InstalledPackagesViewModel(
            provider: provider,
            commandExecutor: executor,
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )
        viewModel.packagesState = .loaded([original])
        viewModel.selectedPackage = original

        viewModel.runAction(.pin, for: original)
        await waitUntil {
            viewModel.selectedPackage?.isPinned == true
        }

        XCTAssertEqual(executor.executedArguments, [["pin", "wget"]])
        XCTAssertEqual(viewModel.selectedPackage, refreshed)
    }

    func testRunActionStoresFailureState() async {
        let package = makePackage(slug: "wget")
        let executor = MockInstalledPackagesCommandExecutor(
            result: .failure(CommandRunnerError.nonZeroExitCode(
                CommandResult(stdout: "", stderr: "could not unlink", exitCode: 1)
            ))
        )
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([package])),
            commandExecutor: executor,
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )

        viewModel.runAction(.unlink, for: package)
        await waitUntil {
            if case .failed = viewModel.actionState {
                return true
            }
            return false
        }
    }

    func testCancelActionStoresCancelledState() async {
        let package = makePackage(slug: "wget")
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([package])),
            commandExecutor: SuspendingInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )

        viewModel.runAction(.reinstall, for: package)
        await waitUntil {
            if case .running = viewModel.actionState {
                return true
            }
            return false
        }

        viewModel.cancelAction()
        await waitUntil {
            if case .cancelled = viewModel.actionState {
                return true
            }
            return false
        }
    }

    func testClearActionOutputResetsActionStateAndFallsBackToCurrentSnapshotSelection() {
        let removedPackage = makePackage(slug: "wget", title: "wget")
        let fallbackPackage = makePackage(slug: "curl", title: "curl")
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([fallbackPackage])),
            commandExecutor: MockInstalledPackagesCommandExecutor(),
            destinationPicker: MockBrewfileDumpDestinationPicker()
        )
        viewModel.packagesState = .loaded([fallbackPackage])
        viewModel.selectedPackage = removedPackage
        viewModel.actionState = .succeeded(
            InstalledPackageActionProgress(
                command: removedPackage.actionCommand(for: .uninstall),
                startedAt: Date(timeIntervalSince1970: 1_000),
                finishedAt: Date(timeIntervalSince1970: 1_100)
            ),
            CommandResult(stdout: "", stderr: "", exitCode: 0)
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .system,
                text: "Removed wget",
                timestamp: Date(timeIntervalSince1970: 1_050)
            )
        ]

        viewModel.clearActionOutput()

        XCTAssertEqual(viewModel.actionState, .idle)
        XCTAssertTrue(viewModel.actionLogs.isEmpty)
        XCTAssertEqual(viewModel.selectedPackage, fallbackPackage)
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

    private func makePackage(
        kind: CatalogPackageKind = .formula,
        slug: String = "wget",
        title: String = "wget",
        version: String = "1.25.0",
        tap: String = "homebrew/core",
        installedAt: Date? = Date(timeIntervalSince1970: 100),
        isPinned: Bool = false,
        isLinked: Bool? = nil,
        isInstalledOnRequest: Bool = false,
        isInstalledAsDependency: Bool = false,
        autoUpdates: Bool = false,
        isLeaf: Bool = false,
        directDependencies: [String] = [],
        buildDependencies: [String] = [],
        testDependencies: [String] = [],
        recommendedDependencies: [String] = [],
        optionalDependencies: [String] = [],
        requirements: [String] = [],
        directRuntimeDependencies: [String] = [],
        runtimeDependencies: [String] = []
    ) -> InstalledPackage {
        InstalledPackage(
            kind: kind,
            slug: slug,
            title: title,
            fullName: slug,
            subtitle: "Test package",
            version: version,
            homepage: nil,
            tap: tap,
            installedVersions: [version],
            installedAt: installedAt,
            linkedVersion: resolvedLinkedVersion(kind: kind, version: version, isLinked: isLinked),
            isPinned: isPinned,
            isLinked: isLinked ?? (kind == .formula),
            isLeaf: isLeaf,
            isOutdated: false,
            isInstalledOnRequest: isInstalledOnRequest,
            isInstalledAsDependency: isInstalledAsDependency,
            autoUpdates: autoUpdates,
            isDeprecated: false,
            isDisabled: false,
            directDependencies: directDependencies,
            buildDependencies: buildDependencies,
            testDependencies: testDependencies,
            recommendedDependencies: recommendedDependencies,
            optionalDependencies: optionalDependencies,
            requirements: requirements,
            directRuntimeDependencies: directRuntimeDependencies,
            runtimeDependencies: runtimeDependencies
        )
    }

    private func resolvedLinkedVersion(
        kind: CatalogPackageKind,
        version: String,
        isLinked: Bool?
    ) -> String? {
        if let isLinked {
            return isLinked ? version : nil
        }

        return kind == .formula ? version : nil
    }
}

private final class MockFavoritePackageStore: FavoritePackageStoring, @unchecked Sendable {
    private let initialIDs: [String]
    private(set) var savedIDs: [[String]] = []

    init(initialIDs: [String] = []) {
        self.initialIDs = initialIDs
    }

    func loadFavoritePackageIDs() -> [String] {
        initialIDs
    }

    func saveFavoritePackageIDs(_ ids: [String]) {
        savedIDs.append(ids)
    }
}

private struct MockInstalledPackagesProvider: InstalledPackagesProviding {
    let result: Result<[InstalledPackage], Error>

    func fetchInstalledPackages() async throws -> [InstalledPackage] {
        try result.get()
    }
}

@MainActor
private final class CountingInstalledPackagesProvider: InstalledPackagesProviding, @unchecked Sendable {
    let result: Result<[InstalledPackage], Error>
    private(set) var fetchCallCount = 0

    init(result: Result<[InstalledPackage], Error>) {
        self.result = result
    }

    func fetchInstalledPackages() async throws -> [InstalledPackage] {
        fetchCallCount += 1
        return try result.get()
    }
}

@MainActor
private final class CyclingInstalledPackagesProvider: InstalledPackagesProviding, @unchecked Sendable {
    let results: [[InstalledPackage]]
    private(set) var fetchCallCount = 0

    init(results: [[InstalledPackage]]) {
        self.results = results
    }

    func fetchInstalledPackages() async throws -> [InstalledPackage] {
        defer { fetchCallCount += 1 }
        return results[min(fetchCallCount, results.count - 1)]
    }
}

private final class MockInstalledPackagesCommandExecutor: BrewCommandExecuting, @unchecked Sendable {
    let result: Result<CommandResult, Error>
    let chunks: [CommandOutputChunk]
    private(set) var executedArguments: [[String]] = []

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
        executedArguments.append(arguments)
        await onLog(.system, "Using Homebrew at /opt/homebrew/bin/brew")

        for chunk in chunks {
            let kind: CatalogPackageActionLogKind = switch chunk.stream {
            case .stdout:
                .stdout
            case .stderr:
                .stderr
            }
            await onLog(kind, chunk.text)
        }

        if chunks.isEmpty {
            await onLog(.stdout, "Dumping Brewfile...\n")
        }

        return try result.get()
    }
}

private struct SuspendingInstalledPackagesCommandExecutor: BrewCommandExecuting {
    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        await onLog(.system, "Using Homebrew at /opt/homebrew/bin/brew")

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        throw CancellationError()
    }
}

@MainActor
private final class MockBrewfileDumpDestinationPicker: BrewfileDumpDestinationPicking, @unchecked Sendable {
    let result: URL?
    private(set) var suggestedFileNames: [String] = []

    init(result: URL? = nil) {
        self.result = result
    }

    func chooseDestination(
        suggestedFileName: String,
        startingDirectory: URL?
    ) -> URL? {
        suggestedFileNames.append(suggestedFileName)
        return result
    }
}
