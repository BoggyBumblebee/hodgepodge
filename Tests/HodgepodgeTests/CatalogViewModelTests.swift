import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class CatalogViewModelTests: XCTestCase {
    func testLoadIfNeededLoadsPackagesAndFirstDetail() async {
        let package = CatalogPackageSummary.fixture()
        let detail = CatalogPackageDetail(
            kind: .formula,
            slug: "wget",
            title: "wget",
            fullName: "wget",
            aliases: [],
            oldNames: [],
            description: "Internet file retriever",
            homepage: package.homepage,
            version: "1.25.0",
            tap: "homebrew/core",
            license: "GPL-3.0-or-later",
            downloadURL: nil,
            checksum: nil,
            autoUpdates: nil,
            versionDetails: [
                CatalogDetailMetric(title: "Current", value: "1.25.0"),
                CatalogDetailMetric(title: "Stable", value: "1.25.0")
            ],
            dependencies: ["openssl@3"],
            dependencySections: [
                CatalogDetailSection(title: "Runtime Dependencies", items: ["openssl@3"], style: .tags)
            ],
            conflicts: [],
            lifecycleSections: [],
            platformSections: [],
            caveats: nil,
            artifacts: [],
            artifactSections: [],
            analytics: []
        )
        let apiClient = MockCatalogAPIClient(packages: .success([package]), details: [package.id: .success(detail)])
        let viewModel = makeViewModel(apiClient: apiClient)

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.detailState == .loaded(detail)
        }

        XCTAssertEqual(viewModel.filteredPackages, [package])
        XCTAssertEqual(viewModel.selectedPackage, package)
        XCTAssertEqual(viewModel.detailState, .loaded(detail))
        XCTAssertEqual(apiClient.fetchCatalogCallCount, 1)
        XCTAssertEqual(apiClient.fetchDetailCallCount, 1)
    }

    func testFilteredPackagesRespectSearchAndScope() {
        let formula = CatalogPackageSummary.fixture(homepage: nil)
        let cask = CatalogPackageSummary.fixture(
            kind: .cask,
            slug: "docker-desktop",
            title: "Docker Desktop",
            subtitle: "Container desktop app",
            version: "4.68.0",
            homepage: nil,
            tap: "homebrew/cask"
        )
        let viewModel = makeViewModel(apiClient: MockCatalogAPIClient(packages: .success([]), details: [:]))
        viewModel.packagesState = .loaded([formula, cask])

        viewModel.searchText = "docker"
        XCTAssertEqual(viewModel.filteredPackages, [cask])

        viewModel.searchText = ""
        viewModel.scope = .formula
        XCTAssertEqual(viewModel.filteredPackages, [formula])
    }

    func testFilteredPackagesRespectActiveFiltersAndSort() {
        let formula = CatalogPackageSummary.fixture(
            slug: "alpha",
            title: "Alpha",
            tap: "homebrew/core",
            hasCaveats: true
        )
        let cask = CatalogPackageSummary.fixture(
            kind: .cask,
            slug: "zulu",
            title: "Zulu",
            subtitle: "Auto-updating cask",
            version: "5.0",
            homepage: nil,
            tap: "homebrew/cask",
            autoUpdates: true
        )
        let deprecated = CatalogPackageSummary.fixture(
            slug: "beta",
            title: "Beta",
            version: "0.9",
            homepage: nil,
            tap: "homebrew/core",
            isDeprecated: true
        )
        let viewModel = makeViewModel(apiClient: MockCatalogAPIClient(packages: .success([]), details: [:]))
        viewModel.packagesState = .loaded([cask, deprecated, formula])

        viewModel.activeFilters = [.hasCaveats]
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Alpha"])

        viewModel.activeFilters = [.autoUpdates]
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Zulu"])

        viewModel.activeFilters = []
        viewModel.sortOption = .version
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Beta", "Alpha", "Zulu"])

        viewModel.sortOption = .tap
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Zulu", "Alpha", "Beta"])
    }

    func testSelectPackageUsesCachedDetailOnSecondSelection() async {
        let first = CatalogPackageSummary.fixture(homepage: nil)
        let second = CatalogPackageSummary.fixture(
            kind: .cask,
            slug: "docker-desktop",
            title: "Docker Desktop",
            subtitle: "Container desktop app",
            version: "4.68.0",
            homepage: nil,
            tap: "homebrew/cask"
        )
        let detail = CatalogPackageDetail(
            kind: .cask,
            slug: "docker-desktop",
            title: "Docker Desktop",
            fullName: "docker-desktop",
            aliases: [],
            oldNames: [],
            description: "Container desktop app",
            homepage: nil,
            version: "4.68.0",
            tap: "homebrew/cask",
            license: nil,
            downloadURL: nil,
            checksum: nil,
            autoUpdates: true,
            versionDetails: [
                CatalogDetailMetric(title: "Current", value: "4.68.0"),
                CatalogDetailMetric(title: "Stable", value: "4.68.0")
            ],
            dependencies: [],
            dependencySections: [],
            conflicts: [],
            lifecycleSections: [],
            platformSections: [],
            caveats: nil,
            artifacts: [],
            artifactSections: [],
            analytics: []
        )
        let apiClient = MockCatalogAPIClient(
            packages: .success([first, second]),
            details: [second.id: .success(detail)]
        )
        let viewModel = makeViewModel(apiClient: apiClient)

        viewModel.packagesState = .loaded([first, second])
        viewModel.selectPackage(second)
        await waitUntil {
            viewModel.detailState == .loaded(detail)
        }
        viewModel.selectPackage(second)
        await waitUntil {
            apiClient.fetchDetailCallCount == 1
        }

        XCTAssertEqual(viewModel.detailState, .loaded(detail))
        XCTAssertEqual(apiClient.fetchDetailCallCount, 1)
    }

    func testRefreshCatalogStoresFailureMessage() async {
        let viewModel = makeViewModel(
            apiClient: MockCatalogAPIClient(
                packages: .failure(HomebrewAPIClientError.requestFailed(503)),
                details: [:]
            )
        )

        viewModel.refreshCatalog()
        await waitUntil {
            viewModel.packagesState == .failed("The Homebrew API request failed with status code 503.")
        }

        XCTAssertEqual(
            viewModel.packagesState,
            .failed("The Homebrew API request failed with status code 503.")
        )
        XCTAssertEqual(viewModel.detailState, .idle)
    }

    func testToggleAndClearFiltersUpdateState() {
        let viewModel = makeViewModel(apiClient: MockCatalogAPIClient(packages: .success([]), details: [:]))

        XCTAssertFalse(viewModel.isFilterActive(.hasCaveats))

        viewModel.toggleFilter(.hasCaveats)
        XCTAssertTrue(viewModel.isFilterActive(.hasCaveats))
        XCTAssertEqual(viewModel.activeFilterCount, 1)

        viewModel.toggleFilter(.hasCaveats)
        XCTAssertFalse(viewModel.isFilterActive(.hasCaveats))

        viewModel.activeFilters = [.deprecated, .disabled]
        viewModel.clearFilters()
        XCTAssertTrue(viewModel.activeFilters.isEmpty)
    }

    func testRefreshSelectedDetailReloadsWhenSelectionExists() async {
        let package = CatalogPackageSummary.fixture()
        let originalDetail = CatalogPackageDetail.fixture(
            dependencies: ["openssl@3"],
            dependencySections: [
                CatalogDetailSection(title: "Runtime Dependencies", items: ["openssl@3"], style: .tags)
            ]
        )
        let refreshedDetail = CatalogPackageDetail.fixture(
            dependencies: ["curl"],
            dependencySections: [
                CatalogDetailSection(title: "Runtime Dependencies", items: ["curl"], style: .tags)
            ]
        )
        let apiClient = CyclingCatalogAPIClient(details: [originalDetail, refreshedDetail])
        let viewModel = makeViewModel(apiClient: apiClient)

        viewModel.packagesState = .loaded([package])
        viewModel.selectPackage(package)
        await waitUntil {
            viewModel.detailState == .loaded(originalDetail)
        }
        XCTAssertEqual(viewModel.detailState, .loaded(originalDetail))

        viewModel.refreshSelectedDetail()
        await waitUntil {
            viewModel.detailState == .loaded(refreshedDetail)
        }

        XCTAssertEqual(viewModel.detailState, .loaded(refreshedDetail))
        XCTAssertEqual(apiClient.fetchDetailCallCount, 2)
    }

    func testRefreshSelectedDetailResetsToIdleWhenNothingSelected() {
        let viewModel = makeViewModel(apiClient: MockCatalogAPIClient(packages: .success([]), details: [:]))

        viewModel.refreshSelectedDetail()

        XCTAssertEqual(viewModel.detailState, .idle)
    }

    func testRunActionStoresSuccessStateAndStreamsLogs() async {
        let detail = CatalogPackageDetail.fixture()
        let result = CommandResult(stdout: "Fetched\n", stderr: "", exitCode: 0)
        let executor = MockBrewCommandExecutor(
            result: .success(result),
            events: [
                (.stdout, "Downloading...\n"),
                (.stdout, "Fetched\n")
            ]
        )
        let historyStore = MockCatalogActionHistoryStore()
        let viewModel = makeViewModel(commandExecutor: executor, historyStore: historyStore)

        viewModel.runAction(.fetch, for: detail)
        await waitUntil {
            viewModel.actionState.command == detail.actionCommand(for: .fetch) &&
                succeededResult(from: viewModel.actionState) == result
        }

        XCTAssertEqual(viewModel.actionState.command, detail.actionCommand(for: .fetch))
        XCTAssertEqual(succeededResult(from: viewModel.actionState), result)
        XCTAssertNotNil(viewModel.actionState.progress?.finishedAt)
        XCTAssertEqual(
            viewModel.actionHistory(for: detail),
            [
                CatalogPackageActionHistoryEntry(
                    id: 0,
                    command: detail.actionCommand(for: .fetch),
                    startedAt: viewModel.actionState.progress?.startedAt ?? .distantPast,
                    finishedAt: viewModel.actionState.progress?.finishedAt ?? .distantFuture,
                    outcome: .succeeded(0),
                    outputLineCount: 6
                )
            ]
        )
        XCTAssertEqual(
            viewModel.actionLogs.map(\.text),
            [
                "Preparing fetch for wget.",
                "Using Homebrew at /opt/homebrew/bin/brew",
                "$ /opt/homebrew/bin/brew fetch wget",
                "Downloading...",
                "Fetched",
                "Fetch finished with exit code 0."
            ]
        )
        XCTAssertTrue(viewModel.actionLogs.allSatisfy { $0.timestamp <= Date() })
        XCTAssertEqual(historyStore.savedEntries.last, viewModel.actionHistory(for: detail))
    }

    func testRunActionStoresFailureState() async {
        let detail = CatalogPackageDetail.fixture(kind: .cask, slug: "docker-desktop", title: "Docker Desktop")
        let failure = CommandRunnerError.nonZeroExitCode(
            CommandResult(stdout: "", stderr: "Already installed\n", exitCode: 1)
        )
        let viewModel = makeViewModel(
            commandExecutor: MockBrewCommandExecutor(
                result: .failure(failure),
                events: [(.stderr, "Already installed\n")]
            )
        )

        viewModel.runAction(.install, for: detail)
        await waitUntil {
            failedMessage(from: viewModel.actionState) == "Already installed"
        }

        XCTAssertEqual(viewModel.actionState.command, detail.actionCommand(for: .install))
        XCTAssertEqual(failedMessage(from: viewModel.actionState), "Already installed")
        XCTAssertNotNil(viewModel.actionState.progress?.finishedAt)
        XCTAssertEqual(viewModel.actionLogs.last?.text, "Already installed")
        XCTAssertEqual(viewModel.actionHistory(for: detail).first?.outcome, .failed("Already installed"))
    }

    func testCancelActionStoresCancelledState() async {
        let detail = CatalogPackageDetail.fixture()
        let executor = SuspendingBrewCommandExecutor()
        let viewModel = makeViewModel(commandExecutor: executor)

        viewModel.runAction(.fetch, for: detail)
        await waitUntil {
            viewModel.actionState.command == detail.actionCommand(for: .fetch) &&
                viewModel.actionState.isRunning
        }

        viewModel.cancelAction()
        await waitUntil {
            isCancelled(viewModel.actionState)
        }

        XCTAssertEqual(viewModel.actionState.command, detail.actionCommand(for: .fetch))
        XCTAssertTrue(isCancelled(viewModel.actionState))
        XCTAssertNotNil(viewModel.actionState.progress?.finishedAt)
        XCTAssertEqual(viewModel.actionHistory(for: detail).first?.outcome, .cancelled)
    }

    func testActionStateAndLogsOnlyApplyToMatchingDetail() async {
        let first = CatalogPackageDetail.fixture(slug: "wget", title: "wget")
        let second = CatalogPackageDetail.fixture(kind: .cask, slug: "docker-desktop", title: "Docker Desktop")
        let result = CommandResult(stdout: "", stderr: "", exitCode: 0)
        let viewModel = makeViewModel(
            commandExecutor: MockBrewCommandExecutor(result: .success(result), events: [])
        )

        viewModel.runAction(.fetch, for: first)
        await waitUntil {
            viewModel.actionState.command == first.actionCommand(for: .fetch) &&
                succeededResult(from: viewModel.actionState) == result
        }

        XCTAssertEqual(viewModel.actionState(for: first).command, first.actionCommand(for: .fetch))
        XCTAssertEqual(succeededResult(from: viewModel.actionState(for: first)), result)
        XCTAssertEqual(viewModel.actionState(for: second), .idle)
        XCTAssertFalse(viewModel.actionLogs(for: first).isEmpty)
        XCTAssertTrue(viewModel.actionLogs(for: second).isEmpty)
        XCTAssertEqual(viewModel.actionHistory(for: first).count, 1)
        XCTAssertTrue(viewModel.actionHistory(for: second).isEmpty)
    }

    func testClearActionOutputResetsActionState() async {
        let detail = CatalogPackageDetail.fixture()
        let result = CommandResult(stdout: "", stderr: "", exitCode: 0)
        let viewModel = makeViewModel(
            commandExecutor: MockBrewCommandExecutor(result: .success(result), events: [])
        )

        viewModel.runAction(.fetch, for: detail)
        await waitUntil {
            viewModel.actionState.command == detail.actionCommand(for: .fetch) &&
                succeededResult(from: viewModel.actionState) == result
        }

        viewModel.clearActionOutput()

        XCTAssertEqual(viewModel.actionState, .idle)
        XCTAssertTrue(viewModel.actionLogs.isEmpty)
        XCTAssertEqual(viewModel.actionHistory(for: detail).count, 1)
    }

    func testInitLoadsPersistedActionHistory() {
        let detail = CatalogPackageDetail.fixture()
        let persistedEntry = CatalogPackageActionHistoryEntry(
            id: 4,
            command: detail.actionCommand(for: .fetch),
            startedAt: Date(timeIntervalSince1970: 500),
            finishedAt: Date(timeIntervalSince1970: 530),
            outcome: .succeeded(0),
            outputLineCount: 3
        )
        let historyStore = MockCatalogActionHistoryStore(initialEntries: [persistedEntry])

        let viewModel = makeViewModel(historyStore: historyStore)

        XCTAssertEqual(viewModel.actionHistory(for: detail), [persistedEntry])
    }

    func testClearActionHistoryRemovesOnlyMatchingPackageAndPersists() {
        let first = CatalogPackageDetail.fixture(slug: "wget", title: "wget")
        let second = CatalogPackageDetail.fixture(kind: .cask, slug: "docker-desktop", title: "Docker Desktop")
        let firstEntry = CatalogPackageActionHistoryEntry(
            id: 0,
            command: first.actionCommand(for: .fetch),
            startedAt: Date(timeIntervalSince1970: 10),
            finishedAt: Date(timeIntervalSince1970: 20),
            outcome: .succeeded(0),
            outputLineCount: 3
        )
        let secondEntry = CatalogPackageActionHistoryEntry(
            id: 1,
            command: second.actionCommand(for: .install),
            startedAt: Date(timeIntervalSince1970: 30),
            finishedAt: Date(timeIntervalSince1970: 45),
            outcome: .failed("Already installed"),
            outputLineCount: 2
        )
        let historyStore = MockCatalogActionHistoryStore(initialEntries: [firstEntry, secondEntry])
        let viewModel = makeViewModel(historyStore: historyStore)

        viewModel.clearActionHistory(for: first)

        XCTAssertEqual(viewModel.actionHistory(for: first), [])
        XCTAssertEqual(viewModel.actionHistory(for: second), [secondEntry])
        XCTAssertEqual(historyStore.savedEntries.last, [secondEntry])
    }

    func testClearAllActionHistoryRemovesEverythingAndPersists() {
        let detail = CatalogPackageDetail.fixture()
        let entry = CatalogPackageActionHistoryEntry(
            id: 0,
            command: detail.actionCommand(for: .fetch),
            startedAt: Date(timeIntervalSince1970: 10),
            finishedAt: Date(timeIntervalSince1970: 20),
            outcome: .succeeded(0),
            outputLineCount: 1
        )
        let historyStore = MockCatalogActionHistoryStore(initialEntries: [entry])
        let viewModel = makeViewModel(historyStore: historyStore)

        viewModel.clearAllActionHistory()

        XCTAssertTrue(viewModel.actionHistory.isEmpty)
        XCTAssertEqual(historyStore.savedEntries.last, [])
    }

    func testExportActionHistoryUsesExporterWithPackageEntries() {
        let first = CatalogPackageDetail.fixture(slug: "wget", title: "wget")
        let second = CatalogPackageDetail.fixture(kind: .cask, slug: "docker-desktop", title: "Docker Desktop")
        let firstEntry = CatalogPackageActionHistoryEntry(
            id: 0,
            command: first.actionCommand(for: .fetch),
            startedAt: Date(timeIntervalSince1970: 10),
            finishedAt: Date(timeIntervalSince1970: 20),
            outcome: .succeeded(0),
            outputLineCount: 3
        )
        let secondEntry = CatalogPackageActionHistoryEntry(
            id: 1,
            command: second.actionCommand(for: .install),
            startedAt: Date(timeIntervalSince1970: 30),
            finishedAt: Date(timeIntervalSince1970: 45),
            outcome: .failed("Already installed"),
            outputLineCount: 2
        )
        let exporter = MockCatalogActionHistoryExporter()
        let viewModel = makeViewModel(
            historyStore: MockCatalogActionHistoryStore(initialEntries: [firstEntry, secondEntry]),
            historyExporter: exporter
        )

        viewModel.exportActionHistory(for: first)

        XCTAssertEqual(exporter.exportedEntries, [firstEntry])
        XCTAssertEqual(exporter.suggestedFileName, "hodgepodge-wget-command-history.json")
    }

    func testExportAllActionHistoryUsesExporterWithAllEntries() {
        let detail = CatalogPackageDetail.fixture()
        let entry = CatalogPackageActionHistoryEntry(
            id: 0,
            command: detail.actionCommand(for: .fetch),
            startedAt: Date(timeIntervalSince1970: 10),
            finishedAt: Date(timeIntervalSince1970: 20),
            outcome: .succeeded(0),
            outputLineCount: 3
        )
        let exporter = MockCatalogActionHistoryExporter()
        let viewModel = makeViewModel(
            historyStore: MockCatalogActionHistoryStore(initialEntries: [entry]),
            historyExporter: exporter
        )

        viewModel.exportAllActionHistory()

        XCTAssertEqual(exporter.exportedEntries, [entry])
        XCTAssertEqual(exporter.suggestedFileName, "hodgepodge-command-history.json")
    }

    private func makeViewModel(
        apiClient: any HomebrewAPIClienting = MockCatalogAPIClient(packages: .success([]), details: [:]),
        commandExecutor: any BrewCommandExecuting = MockBrewCommandExecutor(result: .success(CommandResult(stdout: "", stderr: "", exitCode: 0))),
        historyStore: any CatalogActionHistoryStoring = MockCatalogActionHistoryStore(),
        historyExporter: any CatalogActionHistoryExporting = MockCatalogActionHistoryExporter()
    ) -> CatalogViewModel {
        CatalogViewModel(
            apiClient: apiClient,
            commandExecutor: commandExecutor,
            actionHistoryStore: historyStore,
            actionHistoryExporter: historyExporter
        )
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

    private func succeededResult(from state: CatalogPackageActionState) -> CommandResult? {
        guard case .succeeded(_, let result) = state else {
            return nil
        }

        return result
    }

    private func failedMessage(from state: CatalogPackageActionState) -> String? {
        guard case .failed(_, let message) = state else {
            return nil
        }

        return message
    }

    private func isCancelled(_ state: CatalogPackageActionState) -> Bool {
        if case .cancelled = state {
            return true
        }

        return false
    }
}

private final class CyclingCatalogAPIClient: HomebrewAPIClienting, @unchecked Sendable {
    let details: [CatalogPackageDetail]
    private(set) var fetchDetailCallCount = 0

    init(details: [CatalogPackageDetail]) {
        self.details = details
    }

    func fetchCatalog() async throws -> [CatalogPackageSummary] {
        []
    }

    func fetchDetail(for package: CatalogPackageSummary) async throws -> CatalogPackageDetail {
        defer { fetchDetailCallCount += 1 }
        return details[min(fetchDetailCallCount, details.count - 1)]
    }
}

private struct MockBrewCommandExecutor: BrewCommandExecuting, Sendable {
    let result: Result<CommandResult, Error>
    var events: [(CatalogPackageActionLogKind, String)] = []

    func execute(
        command: CatalogPackageActionCommand,
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        await onLog(.system, "Using Homebrew at /opt/homebrew/bin/brew")
        await onLog(.system, "$ /opt/homebrew/bin/brew \(command.arguments.joined(separator: " "))")

        for (kind, text) in events {
            await onLog(kind, text)
        }

        return try result.get()
    }
}

private struct SuspendingBrewCommandExecutor: BrewCommandExecuting, Sendable {
    func execute(
        command: CatalogPackageActionCommand,
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        await onLog(.system, "Using Homebrew at /opt/homebrew/bin/brew")
        await onLog(.system, "$ /opt/homebrew/bin/brew \(command.arguments.joined(separator: " "))")
        try await Task.sleep(for: .seconds(60))
        return CommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}

private final class MockCatalogActionHistoryStore: CatalogActionHistoryStoring, @unchecked Sendable {
    private let initialEntries: [CatalogPackageActionHistoryEntry]
    private(set) var savedEntries: [[CatalogPackageActionHistoryEntry]] = []

    init(initialEntries: [CatalogPackageActionHistoryEntry] = []) {
        self.initialEntries = initialEntries
    }

    func loadHistory() -> [CatalogPackageActionHistoryEntry] {
        initialEntries
    }

    func saveHistory(_ entries: [CatalogPackageActionHistoryEntry]) {
        savedEntries.append(entries)
    }
}

@MainActor
private final class MockCatalogActionHistoryExporter: CatalogActionHistoryExporting, @unchecked Sendable {
    private(set) var exportedEntries: [CatalogPackageActionHistoryEntry] = []
    private(set) var suggestedFileName: String?

    func export(
        entries: [CatalogPackageActionHistoryEntry],
        suggestedFileName: String
    ) throws {
        exportedEntries = entries
        self.suggestedFileName = suggestedFileName
    }
}

@MainActor
private final class MockCatalogAPIClient: HomebrewAPIClienting, @unchecked Sendable {
    let packages: Result<[CatalogPackageSummary], Error>
    let details: [String: Result<CatalogPackageDetail, Error>]
    private(set) var fetchCatalogCallCount = 0
    private(set) var fetchDetailCallCount = 0

    init(
        packages: Result<[CatalogPackageSummary], Error>,
        details: [String: Result<CatalogPackageDetail, Error>]
    ) {
        self.packages = packages
        self.details = details
    }

    func fetchCatalog() async throws -> [CatalogPackageSummary] {
        fetchCatalogCallCount += 1
        return try packages.get()
    }

    func fetchDetail(for package: CatalogPackageSummary) async throws -> CatalogPackageDetail {
        fetchDetailCallCount += 1

        guard let result = details[package.id] else {
            throw HomebrewAPIClientError.requestFailed(404)
        }

        return try result.get()
    }
}
