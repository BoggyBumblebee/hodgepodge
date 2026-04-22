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
        viewModel.favoritePackageIDs = [cask.id]

        viewModel.activeFilters = [.favorites]
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Zulu"])

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

    func testLoadIfNeededLoadsAnalyticsSnapshot() async {
        let snapshot = CatalogAnalyticsSnapshot(
            period: .days30,
            leaderboards: [
                CatalogAnalyticsLeaderboard(
                    kind: .formulaInstalls,
                    period: .days30,
                    startDate: "2026-03-01",
                    endDate: "2026-03-30",
                    totalItems: 10,
                    totalCount: "12,345",
                    items: [
                        CatalogAnalyticsItem(
                            kind: .formula,
                            slug: "wget",
                            rank: 1,
                            count: "1,200",
                            percent: "9.72"
                        )
                    ]
                )
            ]
        )
        let viewModel = makeViewModel(
            apiClient: MockCatalogAPIClient(
                packages: .success([]),
                details: [:],
                analytics: .success(snapshot)
            )
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.analyticsState == .loaded(snapshot)
        }

        XCTAssertEqual(viewModel.currentAnalyticsSnapshot, snapshot)
    }

    func testSetAnalyticsPeriodUsesCacheOnSecondSelection() async {
        let days30 = CatalogAnalyticsSnapshot(
            period: .days30,
            leaderboards: [
                CatalogAnalyticsLeaderboard(
                    kind: .formulaInstalls,
                    period: .days30,
                    startDate: "2026-03-01",
                    endDate: "2026-03-30",
                    totalItems: 10,
                    totalCount: "12,345",
                    items: []
                )
            ]
        )
        let days90 = CatalogAnalyticsSnapshot(
            period: .days90,
            leaderboards: [
                CatalogAnalyticsLeaderboard(
                    kind: .formulaInstalls,
                    period: .days90,
                    startDate: "2026-01-01",
                    endDate: "2026-03-30",
                    totalItems: 25,
                    totalCount: "48,000",
                    items: []
                )
            ]
        )
        let apiClient = MockCatalogAPIClient(
            packages: .success([]),
            details: [:],
            analyticsByPeriod: [
                .days30: .success(days30),
                .days90: .success(days90)
            ]
        )
        let viewModel = makeViewModel(apiClient: apiClient)

        viewModel.loadAnalyticsIfNeeded()
        await waitUntil {
            viewModel.analyticsState == .loaded(days30)
        }

        viewModel.setAnalyticsPeriod(.days90)
        await waitUntil {
            viewModel.analyticsState == .loaded(days90)
        }

        viewModel.setAnalyticsPeriod(.days30)
        XCTAssertEqual(viewModel.analyticsState, .loaded(days30))
        XCTAssertEqual(apiClient.fetchAnalyticsCallCount, 2)
    }

    func testOpenAnalyticsItemInCatalogSelectsMatchingLoadedPackage() async {
        let package = CatalogPackageSummary.fixture()
        let detail = CatalogPackageDetail.fixture()
        let analyticsItem = CatalogAnalyticsItem(
            kind: .formula,
            slug: package.slug,
            rank: 1,
            count: "1,200",
            percent: "9.72"
        )
        let apiClient = MockCatalogAPIClient(
            packages: .success([package]),
            details: [package.id: .success(detail)]
        )
        let viewModel = makeViewModel(apiClient: apiClient)
        viewModel.packagesState = .loaded([package])

        viewModel.openAnalyticsItemInCatalog(analyticsItem)
        await waitUntil {
            viewModel.selectedPackage == package && viewModel.detailState == .loaded(detail)
        }

        XCTAssertEqual(viewModel.selectedPackage, package)
        XCTAssertEqual(viewModel.detailState, .loaded(detail))
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.scope, .all)
        XCTAssertTrue(viewModel.activeFilters.isEmpty)
    }

    func testOpenAnalyticsItemInCatalogLoadsCatalogWhenNeeded() async {
        let package = CatalogPackageSummary.fixture()
        let detail = CatalogPackageDetail.fixture()
        let analyticsItem = CatalogAnalyticsItem(
            kind: .formula,
            slug: package.slug,
            rank: 1,
            count: "1,200",
            percent: "9.72"
        )
        let apiClient = MockCatalogAPIClient(
            packages: .success([package]),
            details: [package.id: .success(detail)]
        )
        let viewModel = makeViewModel(apiClient: apiClient)
        viewModel.searchText = "old"
        viewModel.scope = .cask
        viewModel.activeFilters = [.favorites]

        viewModel.openAnalyticsItemInCatalog(analyticsItem)
        await waitUntil {
            viewModel.selectedPackage == package && viewModel.detailState == .loaded(detail)
        }

        XCTAssertEqual(viewModel.packagesState, .loaded([package]))
        XCTAssertEqual(viewModel.selectedPackage, package)
        XCTAssertEqual(viewModel.detailState, .loaded(detail))
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.scope, .all)
        XCTAssertTrue(viewModel.activeFilters.isEmpty)
        XCTAssertEqual(apiClient.fetchCatalogCallCount, 1)
    }

    func testInitLoadsPersistedFavoritesAndSavedSearches() {
        let package = CatalogPackageSummary.fixture()
        let savedSearch = CatalogSavedSearch(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
            name: "Favorites",
            searchText: "wget",
            scope: .formula,
            activeFilters: [.hasCaveats],
            sortOption: .tap
        )
        let preferencesStore = MockCatalogPreferencesStore(
            initialSnapshot: CatalogPreferencesSnapshot(
                favoritePackageIDs: [package.id],
                savedSearches: [savedSearch]
            )
        )
        let viewModel = makeViewModel(preferencesStore: preferencesStore)

        XCTAssertEqual(viewModel.favoritePackageIDs, [package.id])
        XCTAssertEqual(viewModel.savedSearches, [savedSearch])
    }

    func testToggleFavoritePersistsPreferences() {
        let package = CatalogPackageSummary.fixture()
        let preferencesStore = MockCatalogPreferencesStore()
        let viewModel = makeViewModel(preferencesStore: preferencesStore)

        viewModel.toggleFavorite(package)

        XCTAssertEqual(viewModel.favoritePackageIDs, [package.id])
        XCTAssertEqual(
            preferencesStore.savedSnapshots.last,
            CatalogPreferencesSnapshot(
                favoritePackageIDs: [package.id],
                savedSearches: []
            )
        )
    }

    func testSaveCurrentSearchPersistsAndReplacesMatchingName() {
        let existingSearch = CatalogSavedSearch(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
            name: "Working Set",
            searchText: "curl",
            scope: .all,
            activeFilters: [],
            sortOption: .name
        )
        let preferencesStore = MockCatalogPreferencesStore(
            initialSnapshot: CatalogPreferencesSnapshot(
                favoritePackageIDs: [],
                savedSearches: [existingSearch]
            )
        )
        let viewModel = makeViewModel(preferencesStore: preferencesStore)
        viewModel.searchText = "wget"
        viewModel.scope = .formula
        viewModel.activeFilters = [.hasCaveats]
        viewModel.sortOption = .tap

        viewModel.saveCurrentSearch(named: "  working set  ")

        XCTAssertEqual(viewModel.savedSearches.count, 1)
        XCTAssertEqual(viewModel.savedSearches.first?.id, existingSearch.id)
        XCTAssertEqual(viewModel.savedSearches.first?.searchText, "wget")
        XCTAssertEqual(viewModel.savedSearches.first?.scope, .formula)
        XCTAssertEqual(viewModel.savedSearches.first?.activeFilters, [.hasCaveats])
        XCTAssertEqual(viewModel.savedSearches.first?.sortOption, .tap)
        XCTAssertEqual(preferencesStore.savedSnapshots.last?.savedSearches, viewModel.savedSearches)
    }

    func testApplySavedSearchRestoresCatalogConfiguration() {
        let savedSearch = CatalogSavedSearch(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
            name: "Casks",
            searchText: "docker",
            scope: .cask,
            activeFilters: [.autoUpdates],
            sortOption: .version
        )
        let viewModel = makeViewModel()

        viewModel.applySavedSearch(savedSearch)

        XCTAssertEqual(viewModel.searchText, "docker")
        XCTAssertEqual(viewModel.scope, .cask)
        XCTAssertEqual(viewModel.activeFilters, [.autoUpdates])
        XCTAssertEqual(viewModel.sortOption, .version)
    }

    func testRemoveSavedSearchPersistsPreferences() {
        let savedSearch = CatalogSavedSearch(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(),
            name: "Pinned",
            searchText: "node",
            scope: .formula,
            activeFilters: [.deprecated],
            sortOption: .tap
        )
        let preferencesStore = MockCatalogPreferencesStore(
            initialSnapshot: CatalogPreferencesSnapshot(
                favoritePackageIDs: ["formula:wget"],
                savedSearches: [savedSearch]
            )
        )
        let viewModel = makeViewModel(preferencesStore: preferencesStore)

        viewModel.removeSavedSearch(savedSearch)

        XCTAssertTrue(viewModel.savedSearches.isEmpty)
        XCTAssertEqual(
            preferencesStore.savedSnapshots.last,
            CatalogPreferencesSnapshot(
                favoritePackageIDs: ["formula:wget"],
                savedSearches: []
            )
        )
    }

    func testFavoritePackageIDsUpdateWhenSharedNotificationIsPosted() async {
        let notificationCenter = NotificationCenter()
        let viewModel = makeViewModel(notificationCenter: notificationCenter)

        notificationCenter.post(
            name: .favoritePackageIDsDidChange,
            object: nil,
            userInfo: [FavoritePackageNotificationUserInfoKey.ids: ["formula:wget", "cask:docker-desktop"]]
        )

        await waitUntil {
            viewModel.favoritePackageIDs == ["formula:wget", "cask:docker-desktop"]
        }
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

    func testSuccessfulInstallPostsHomebrewStateChangeNotification() async {
        let detail = CatalogPackageDetail.fixture()
        let notificationCenter = NotificationCenter()
        let viewModel = makeViewModel(
            commandExecutor: MockBrewCommandExecutor(
                result: .success(CommandResult(stdout: "Installed\n", stderr: "", exitCode: 0))
            ),
            notificationCenter: notificationCenter
        )
        let notificationExpectation = expectation(description: "install notification posted")
        let observer = notificationCenter.addObserver(
            forName: .homebrewStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            notificationExpectation.fulfill()
        }
        defer {
            notificationCenter.removeObserver(observer)
        }

        viewModel.runAction(.install, for: detail)
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return true
            }
            return false
        }

        await fulfillment(of: [notificationExpectation], timeout: 1)
    }

    func testSuccessfulUninstallPostsHomebrewStateChangeNotification() async {
        let detail = CatalogPackageDetail.fixture()
        let notificationCenter = NotificationCenter()
        let viewModel = makeViewModel(
            commandExecutor: MockBrewCommandExecutor(
                result: .success(CommandResult(stdout: "Uninstalled\n", stderr: "", exitCode: 0))
            ),
            notificationCenter: notificationCenter
        )
        let notificationExpectation = expectation(description: "uninstall notification posted")
        let observer = notificationCenter.addObserver(
            forName: .homebrewStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            notificationExpectation.fulfill()
        }
        defer {
            notificationCenter.removeObserver(observer)
        }

        viewModel.runAction(.uninstall, for: detail)
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return true
            }
            return false
        }

        await fulfillment(of: [notificationExpectation], timeout: 1)
        XCTAssertEqual(viewModel.actionState.command, detail.actionCommand(for: .uninstall))
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
        historyExporter: any CatalogActionHistoryExporting = MockCatalogActionHistoryExporter(),
        preferencesStore: any CatalogPreferencesStoring = MockCatalogPreferencesStore(),
        notificationCenter: NotificationCenter = .default
    ) -> CatalogViewModel {
        CatalogViewModel(
            apiClient: apiClient,
            commandExecutor: commandExecutor,
            actionHistoryStore: historyStore,
            actionHistoryExporter: historyExporter,
            preferencesStore: preferencesStore,
            notificationCenter: notificationCenter
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

private final class MockCatalogPreferencesStore: CatalogPreferencesStoring, @unchecked Sendable {
    private let initialSnapshot: CatalogPreferencesSnapshot
    private(set) var savedSnapshots: [CatalogPreferencesSnapshot] = []

    init(initialSnapshot: CatalogPreferencesSnapshot = .empty) {
        self.initialSnapshot = initialSnapshot
    }

    func loadPreferences() -> CatalogPreferencesSnapshot {
        initialSnapshot
    }

    func savePreferences(_ snapshot: CatalogPreferencesSnapshot) {
        savedSnapshots.append(snapshot)
    }

    func loadFavoritePackageIDs() -> [String] {
        initialSnapshot.favoritePackageIDs
    }

    func saveFavoritePackageIDs(_ ids: [String]) {
        savedSnapshots.append(
            CatalogPreferencesSnapshot(
                favoritePackageIDs: ids,
                savedSearches: initialSnapshot.savedSearches
            )
        )
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

    func fetchAnalytics(period: CatalogAnalyticsPeriod) async throws -> CatalogAnalyticsSnapshot {
        .empty(for: period)
    }
}

private struct MockBrewCommandExecutor: BrewCommandExecuting, Sendable {
    let result: Result<CommandResult, Error>
    var events: [(CatalogPackageActionLogKind, String)] = []

    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        await onLog(.system, "Using Homebrew at /opt/homebrew/bin/brew")
        await onLog(.system, "$ /opt/homebrew/bin/brew \(arguments.joined(separator: " "))")

        for (kind, text) in events {
            await onLog(kind, text)
        }

        return try result.get()
    }
}

private struct SuspendingBrewCommandExecutor: BrewCommandExecuting, Sendable {
    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        await onLog(.system, "Using Homebrew at /opt/homebrew/bin/brew")
        await onLog(.system, "$ /opt/homebrew/bin/brew \(arguments.joined(separator: " "))")
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
    private let analyticsResult: Result<CatalogAnalyticsSnapshot, Error>?
    private let analyticsResultsByPeriod: [CatalogAnalyticsPeriod: Result<CatalogAnalyticsSnapshot, Error>]
    private(set) var fetchCatalogCallCount = 0
    private(set) var fetchDetailCallCount = 0
    private(set) var fetchAnalyticsCallCount = 0

    init(
        packages: Result<[CatalogPackageSummary], Error>,
        details: [String: Result<CatalogPackageDetail, Error>],
        analytics: Result<CatalogAnalyticsSnapshot, Error>? = nil,
        analyticsByPeriod: [CatalogAnalyticsPeriod: Result<CatalogAnalyticsSnapshot, Error>] = [:]
    ) {
        self.packages = packages
        self.details = details
        analyticsResult = analytics
        analyticsResultsByPeriod = analyticsByPeriod
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

    func fetchAnalytics(period: CatalogAnalyticsPeriod) async throws -> CatalogAnalyticsSnapshot {
        fetchAnalyticsCallCount += 1

        if let result = analyticsResultsByPeriod[period] {
            return try result.get()
        }

        if let analyticsResult {
            return try analyticsResult.get()
        }

        return .empty(for: period)
    }
}
