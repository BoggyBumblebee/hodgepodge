import Foundation

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var packagesState: CatalogPackagesLoadState = .idle
    @Published var detailState: CatalogDetailLoadState = .idle
    @Published var analyticsState: CatalogAnalyticsLoadState = .idle
    @Published var analyticsPeriod: CatalogAnalyticsPeriod = .days30
    @Published var actionState: CatalogPackageActionState = .idle
    @Published var actionLogs: [CatalogPackageActionLogEntry] = []
    @Published var actionHistory: [CatalogPackageActionHistoryEntry] = []
    @Published var favoritePackageIDs: Set<String> = []
    @Published var savedSearches: [CatalogSavedSearch] = []
    @Published var searchText = ""
    @Published var scope: CatalogScope = .all
    @Published var activeFilters: Set<CatalogFilterOption> = []
    @Published var sortOption: CatalogSortOption = .name
    @Published var selectedPackage: CatalogPackageSummary?

    private let apiClient: any HomebrewAPIClienting
    private let commandExecutor: any BrewCommandExecuting
    private let actionHistoryStore: any CatalogActionHistoryStoring
    private let actionHistoryExporter: any CatalogActionHistoryExporting
    private let preferencesStore: any CatalogPreferencesStoring
    private let settingsStore: any AppSettingsStoring
    private let notificationScheduler: any CommandNotificationScheduling
    private let homebrewStateNotifier: HomebrewStateNotifier
    private var detailCache: [String: CatalogPackageDetail] = [:]
    private var analyticsCache: [CatalogAnalyticsPeriod: CatalogAnalyticsSnapshot] = [:]
    private var analyticsTask: Task<Void, Never>?
    private var actionTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var favoritesObserver: FavoritePackageIDsObserver?
    private var settingsObserver: AppSettingsObserver?
    private var logBuffer = CommandLogBuffer()
    private var nextHistoryIdentifier = 0

    init(
        apiClient: any HomebrewAPIClienting,
        commandExecutor: any BrewCommandExecuting,
        actionHistoryStore: any CatalogActionHistoryStoring,
        actionHistoryExporter: any CatalogActionHistoryExporting,
        preferencesStore: any CatalogPreferencesStoring,
        settingsStore: any AppSettingsStoring = AppSettingsStore(),
        notificationScheduler: any CommandNotificationScheduling = NullCommandNotificationScheduler(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.apiClient = apiClient
        self.commandExecutor = commandExecutor
        self.actionHistoryStore = actionHistoryStore
        self.actionHistoryExporter = actionHistoryExporter
        self.preferencesStore = preferencesStore
        self.settingsStore = settingsStore
        self.notificationScheduler = notificationScheduler
        self.homebrewStateNotifier = HomebrewStateNotifier(notificationCenter: notificationCenter)
        let retentionLimit = settingsStore.loadSettings().catalogHistoryRetentionLimit.rawValue
        let restoredHistory = actionHistoryStore.loadHistory()
        actionHistory = Self.trimHistory(restoredHistory, limit: retentionLimit)
        if actionHistory != restoredHistory {
            actionHistoryStore.saveHistory(actionHistory)
        }
        nextHistoryIdentifier = (actionHistory.map { $0.id }.max() ?? -1) + 1
        let restoredPreferences = preferencesStore.loadPreferences()
        favoritePackageIDs = Set(restoredPreferences.favoritePackageIDs)
        savedSearches = restoredPreferences.savedSearches.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        favoritesObserver = FavoritePackageIDsObserver(notificationCenter: notificationCenter) { [weak self] ids in
            self?.favoritePackageIDs = Set(ids)
        }
        settingsObserver = AppSettingsObserver(notificationCenter: notificationCenter) { [weak self] snapshot in
            self?.applySettings(snapshot)
        }
    }

    deinit {
        analyticsTask?.cancel()
        actionTask?.cancel()
        selectionTask?.cancel()
    }

    var filteredPackages: [CatalogPackageSummary] {
        guard case .loaded(let packages) = packagesState else {
            return []
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = packages.filter { package in
            guard scope.includes(package.kind) else {
                return false
            }

            guard matchesActiveFilters(for: package) else {
                return false
            }

            guard !trimmedQuery.isEmpty else {
                return true
            }

            return package.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.slug.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.subtitle.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.tap.localizedCaseInsensitiveContains(trimmedQuery)
        }

        return filtered.sorted(by: sorter(for: sortOption))
    }

    var activeFilterCount: Int {
        activeFilters.count
    }

    var hasSearchConfiguration: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            scope != .all ||
            !activeFilters.isEmpty ||
            sortOption != .name
    }

    var hasRunningAction: Bool {
        actionState.isRunning
    }

    var currentAnalyticsSnapshot: CatalogAnalyticsSnapshot? {
        guard case .loaded(let snapshot) = analyticsState else {
            return nil
        }

        return snapshot
    }

    func loadIfNeeded() {
        if case .idle = packagesState {
            refreshCatalog()
        }

        if case .idle = analyticsState {
            loadAnalyticsIfNeeded()
        }
    }

    func loadCatalogIfNeeded() {
        guard case .idle = packagesState else {
            return
        }

        refreshCatalog()
    }

    func loadAnalyticsIfNeeded() {
        if let cached = analyticsCache[analyticsPeriod] {
            analyticsState = .loaded(cached)
            return
        }

        refreshAnalytics()
    }

    func setAnalyticsPeriod(_ period: CatalogAnalyticsPeriod) {
        guard analyticsPeriod != period else {
            return
        }

        analyticsPeriod = period
        loadAnalyticsIfNeeded()
    }

    func refreshAnalytics() {
        let requestedPeriod = analyticsPeriod
        analyticsTask?.cancel()
        analyticsTask = nil
        analyticsState = .loading(requestedPeriod)

        analyticsTask = Task { @MainActor [apiClient] in
            defer { analyticsTask = nil }

            do {
                let snapshot = try await apiClient.fetchAnalytics(period: requestedPeriod)
                analyticsCache[requestedPeriod] = snapshot

                guard analyticsPeriod == requestedPeriod else {
                    return
                }

                analyticsState = .loaded(snapshot)
            } catch is CancellationError {
                return
            } catch {
                guard analyticsPeriod == requestedPeriod else {
                    return
                }

                analyticsState = .failed(requestedPeriod, error.localizedDescription)
            }
        }
    }

    func refreshCatalog() {
        refreshCatalog(selecting: nil)
    }

    func openAnalyticsItemInCatalog(_ analyticsItem: CatalogAnalyticsItem) {
        clearNavigationFilters()

        if let package = packageSummary(for: analyticsItem) {
            selectPackage(package)
            return
        }

        refreshCatalog(selecting: analyticsItem)
    }

    private func clearNavigationFilters() {
        searchText = ""
        scope = .all
        activeFilters.removeAll()
    }

    private func refreshCatalog(selecting analyticsItem: CatalogAnalyticsItem?) {
        packagesState = .loading

        Task { @MainActor [apiClient] in
            do {
                let packages = try await apiClient.fetchCatalog()
                packagesState = .loaded(packages)

                if let analyticsItem,
                   let package = packageSummary(for: analyticsItem, in: packages) {
                    selectedPackage = package
                    await loadDetail(for: package)
                } else if let selectedPackage, packages.contains(selectedPackage) {
                    await loadDetail(for: selectedPackage)
                } else {
                    let replacement = packages.first
                    selectedPackage = replacement
                    if let replacement {
                        await loadDetail(for: replacement)
                    } else {
                        detailState = .idle
                    }
                }
            } catch {
                packagesState = .failed(error.localizedDescription)
                detailState = .idle
            }
        }
    }

    func selectPackage(_ package: CatalogPackageSummary?) {
        selectionTask?.cancel()
        selectionTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else {
                return
            }

            self.selectedPackage = package

            guard let package else {
                self.detailState = .idle
                return
            }

            await self.loadDetail(for: package)
        }
    }

    func refreshSelectedDetail() {
        guard let selectedPackage else {
            detailState = .idle
            return
        }

        detailCache.removeValue(forKey: selectedPackage.id)
        Task { @MainActor in
            await loadDetail(for: selectedPackage)
        }
    }

    private func loadDetail(for package: CatalogPackageSummary) async {
        if let cached = detailCache[package.id] {
            detailState = .loaded(cached)
            return
        }

        detailState = .loading(package)

        do {
            let detail = try await apiClient.fetchDetail(for: package)
            detailCache[package.id] = detail
            guard selectedPackage == package else {
                return
            }
            detailState = .loaded(detail)
        } catch {
            guard selectedPackage == package else {
                return
            }
            detailState = .failed(package, error.localizedDescription)
        }
    }

    func toggleFilter(_ filter: CatalogFilterOption) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
    }

    func clearFilters() {
        activeFilters.removeAll()
    }

    func isFilterActive(_ filter: CatalogFilterOption) -> Bool {
        activeFilters.contains(filter)
    }

    func isFavorite(_ package: CatalogPackageSummary) -> Bool {
        favoritePackageIDs.contains(package.id)
    }

    func isFavorite(_ detail: CatalogPackageDetail) -> Bool {
        favoritePackageIDs.contains(detail.packageID)
    }

    func toggleFavorite(_ package: CatalogPackageSummary) {
        toggleFavorite(packageID: package.id)
    }

    func toggleFavorite(_ detail: CatalogPackageDetail) {
        toggleFavorite(packageID: detail.packageID)
    }

    func saveCurrentSearch(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }

        let savedSearch = CatalogSavedSearch(
            id: existingSavedSearch(named: name)?.id ?? UUID(),
            name: name,
            searchText: searchText,
            scope: scope,
            activeFilters: activeFilters,
            sortOption: sortOption
        )

        savedSearches.removeAll {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
        savedSearches.append(savedSearch)
        savedSearches.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        persistPreferences()
    }

    func applySavedSearch(_ search: CatalogSavedSearch) {
        searchText = search.searchText
        scope = search.scope
        activeFilters = search.activeFilters
        sortOption = search.sortOption
    }

    func removeSavedSearch(_ search: CatalogSavedSearch) {
        savedSearches.removeAll { $0.id == search.id }
        persistPreferences()
    }

    func runAction(_ actionKind: CatalogPackageActionKind, for detail: CatalogPackageDetail) {
        let command = detail.actionCommand(for: actionKind)
        let progress = CatalogPackageActionProgress(command: command, startedAt: Date())

        actionTask?.cancel()
        actionTask = nil
        resetActionOutput()
        actionState = .running(progress)
        appendLog(.system, "Preparing \(actionKind.title.lowercased()) for \(detail.title).")

        actionTask = Task { @MainActor [commandExecutor] in
            do {
                let result = try await commandExecutor.execute(command: command) { [weak self] kind, text in
                    self?.appendLog(kind, text)
                }
                flushPendingLogs()
                appendLog(.system, "\(actionKind.title) finished with exit code \(result.exitCode).")
                let completedProgress = progress.finished(at: Date())
                actionState = .succeeded(completedProgress, result)
                appendHistoryEntry(
                    command: command,
                    progress: completedProgress,
                    outcome: .succeeded(result.exitCode)
                )
                if actionKind.affectsHomebrewState {
                    homebrewStateNotifier.notifyDidChange()
                }
                await notifyActionSucceeded(
                    actionKind: actionKind,
                    detail: detail,
                    elapsedTime: completedProgress.elapsedTime()
                )
            } catch is CancellationError {
                flushPendingLogs()
                appendLog(.system, "\(actionKind.title) cancelled.")
                let completedProgress = progress.finished(at: Date())
                actionState = .cancelled(completedProgress)
                appendHistoryEntry(
                    command: command,
                    progress: completedProgress,
                    outcome: .cancelled
                )
                await notifyActionCancelled(
                    actionKind: actionKind,
                    detail: detail,
                    elapsedTime: completedProgress.elapsedTime()
                )
            } catch {
                flushPendingLogs()
                appendLog(.system, error.localizedDescription)
                let completedProgress = progress.finished(at: Date())
                actionState = .failed(completedProgress, error.localizedDescription)
                appendHistoryEntry(
                    command: command,
                    progress: completedProgress,
                    outcome: .failed(error.localizedDescription)
                )
                await notifyActionFailed(
                    actionKind: actionKind,
                    detail: detail,
                    error: error,
                    elapsedTime: completedProgress.elapsedTime()
                )
            }

            actionTask = nil
        }
    }

    func cancelAction() {
        actionTask?.cancel()
    }

    func clearActionOutput() {
        actionTask?.cancel()
        actionTask = nil
        resetActionOutput()
        actionState = .idle
    }

    func actionState(for detail: CatalogPackageDetail) -> CatalogPackageActionState {
        guard actionState.command?.packageID == detail.packageID else {
            return .idle
        }

        return actionState
    }

    func actionLogs(for detail: CatalogPackageDetail) -> [CatalogPackageActionLogEntry] {
        guard actionState.command?.packageID == detail.packageID else {
            return []
        }

        return actionLogs
    }

    func actionHistory(for detail: CatalogPackageDetail) -> [CatalogPackageActionHistoryEntry] {
        actionHistory.filter { $0.command.packageID == detail.packageID }
    }

    func clearActionHistory(for detail: CatalogPackageDetail) {
        actionHistory.removeAll { $0.command.packageID == detail.packageID }
        actionHistoryStore.saveHistory(actionHistory)
    }

    func clearAllActionHistory() {
        actionHistory.removeAll()
        actionHistoryStore.saveHistory(actionHistory)
    }

    func exportActionHistory(for detail: CatalogPackageDetail) {
        let entries = actionHistory(for: detail)
        guard !entries.isEmpty else {
            return
        }

        do {
            try actionHistoryExporter.export(
                entries: entries,
                suggestedFileName: "hodgepodge-\(detail.slug)-command-history.json"
            )
        } catch is CatalogActionHistoryExportError {
            return
        } catch {
            return
        }
    }

    func exportAllActionHistory() {
        guard !actionHistory.isEmpty else {
            return
        }

        do {
            try actionHistoryExporter.export(
                entries: actionHistory,
                suggestedFileName: "hodgepodge-command-history.json"
            )
        } catch is CatalogActionHistoryExportError {
            return
        } catch {
            return
        }
    }

    private func matchesActiveFilters(for package: CatalogPackageSummary) -> Bool {
        activeFilters.allSatisfy { filter in
            switch filter {
            case .favorites:
                favoritePackageIDs.contains(package.id)
            case .hasCaveats:
                package.hasCaveats
            case .deprecated:
                package.isDeprecated
            case .disabled:
                package.isDisabled
            case .autoUpdates:
                package.autoUpdates
            }
        }
    }

    private func sorter(for option: CatalogSortOption) -> (CatalogPackageSummary, CatalogPackageSummary) -> Bool {
        switch option {
        case .name:
            return { lhs, rhs in
                Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .packageType:
            return { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .version:
            return { lhs, rhs in
                let result = lhs.version.localizedStandardCompare(rhs.version)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .tap:
            return { lhs, rhs in
                let result = lhs.tap.localizedCaseInsensitiveCompare(rhs.tap)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        }
    }

    private static func compare(_ lhs: String, _ rhs: String, fallback: Bool) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result != .orderedSame {
            return result == .orderedAscending
        }
        return fallback
    }

    private func appendLog(_ kind: CatalogPackageActionLogKind, _ text: String, timestamp: Date = Date()) {
        logBuffer.append(kind, text, timestamp: timestamp)
        actionLogs = logBuffer.entries
    }

    private func flushPendingLogs() {
        logBuffer.flush()
        actionLogs = logBuffer.entries
    }

    private func resetActionOutput() {
        logBuffer.reset()
        actionLogs = []
    }

    private func toggleFavorite(packageID: String) {
        if favoritePackageIDs.contains(packageID) {
            favoritePackageIDs.remove(packageID)
        } else {
            favoritePackageIDs.insert(packageID)
        }

        persistPreferences()
    }

    private func existingSavedSearch(named name: String) -> CatalogSavedSearch? {
        savedSearches.first {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    private func packageSummary(for analyticsItem: CatalogAnalyticsItem) -> CatalogPackageSummary? {
        guard case .loaded(let packages) = packagesState else {
            return nil
        }

        return packageSummary(for: analyticsItem, in: packages)
    }

    private func packageSummary(
        for analyticsItem: CatalogAnalyticsItem,
        in packages: [CatalogPackageSummary]
    ) -> CatalogPackageSummary? {
        return packages.first { package in
            package.kind == analyticsItem.kind && package.slug == analyticsItem.slug
        }
    }

    private func persistPreferences() {
        preferencesStore.savePreferences(
            CatalogPreferencesSnapshot(
                favoritePackageIDs: favoritePackageIDs.sorted(),
                savedSearches: savedSearches
            )
        )
    }

    private func appendHistoryEntry(
        command: CatalogPackageActionCommand,
        progress: CatalogPackageActionProgress,
        outcome: CatalogPackageActionHistoryOutcome
    ) {
        guard let finishedAt = progress.finishedAt else {
            return
        }

        actionHistory.insert(
            CatalogPackageActionHistoryEntry(
                id: nextHistoryIdentifier,
                command: command,
                startedAt: progress.startedAt,
                finishedAt: finishedAt,
                outcome: outcome,
                outputLineCount: actionLogs.count
            ),
            at: 0
        )
        nextHistoryIdentifier += 1

        trimHistoryToSettingsLimit()
        actionHistoryStore.saveHistory(actionHistory)
    }

    private func applySettings(_ snapshot: AppSettingsSnapshot) {
        let trimmedHistory = Self.trimHistory(actionHistory, limit: snapshot.catalogHistoryRetentionLimit.rawValue)
        guard trimmedHistory != actionHistory else {
            return
        }

        actionHistory = trimmedHistory
        actionHistoryStore.saveHistory(actionHistory)
    }

    private func trimHistoryToSettingsLimit() {
        let retentionLimit = settingsStore.loadSettings().catalogHistoryRetentionLimit.rawValue
        actionHistory = Self.trimHistory(actionHistory, limit: retentionLimit)
    }

    private static func trimHistory(
        _ entries: [CatalogPackageActionHistoryEntry],
        limit: Int
    ) -> [CatalogPackageActionHistoryEntry] {
        guard entries.count > limit else {
            return entries
        }

        return Array(entries.prefix(limit))
    }

    private func notifyActionSucceeded(
        actionKind: CatalogPackageActionKind,
        detail: CatalogPackageDetail,
        elapsedTime: TimeInterval
    ) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(actionKind.title) Complete",
                body: "\(detail.title) completed successfully.",
                elapsedTime: elapsedTime,
                category: .packageActions
            )
        )
    }

    private func notifyActionCancelled(
        actionKind: CatalogPackageActionKind,
        detail: CatalogPackageDetail,
        elapsedTime: TimeInterval
    ) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(actionKind.title) Cancelled",
                body: "\(detail.title) was cancelled before it finished.",
                elapsedTime: elapsedTime,
                category: .packageActions
            )
        )
    }

    private func notifyActionFailed(
        actionKind: CatalogPackageActionKind,
        detail: CatalogPackageDetail,
        error: Error,
        elapsedTime: TimeInterval
    ) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(actionKind.title) Failed",
                body: CommandPresentation.friendlyFailureDescription(
                    error.localizedDescription,
                    fallback: "\(detail.title) couldn’t be completed."
                ),
                elapsedTime: elapsedTime,
                category: .packageActions
            )
        )
    }
}

extension CatalogViewModel {
    static func live(
        notificationScheduler: any CommandNotificationScheduling = CommandNotificationScheduler.live()
    ) -> CatalogViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)

        return CatalogViewModel(
            apiClient: HomebrewAPIClient(),
            commandExecutor: BrewCommandExecutor(
                brewLocator: brewLocator,
                runner: runner
            ),
            actionHistoryStore: CatalogActionHistoryStore(),
            actionHistoryExporter: CatalogActionHistoryExporter(),
            preferencesStore: CatalogPreferencesStore(),
            settingsStore: AppSettingsStore(),
            notificationScheduler: notificationScheduler,
            notificationCenter: .default
        )
    }
}
