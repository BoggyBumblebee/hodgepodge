import Foundation

@MainActor
final class OutdatedPackagesViewModel: ObservableObject {
    @Published var packagesState: OutdatedPackagesLoadState = .idle
    @Published var actionState: OutdatedPackageActionState = .idle
    @Published var actionLogs: [CommandLogEntry] = []
    @Published var searchText = ""
    @Published var scope: CatalogScope = .all
    @Published var activeFilters: Set<OutdatedPackageFilterOption> = []
    @Published var sortOption: OutdatedPackageSortOption = .name
    @Published var selectedPackage: OutdatedPackage?

    private let provider: any OutdatedPackagesProviding
    private let commandExecutor: any BrewCommandExecuting
    private let notificationScheduler: any CommandNotificationScheduling
    private var actionTask: Task<Void, Never>?
    private var homebrewStateObserver: HomebrewStateObserver?
    private var logBuffer = CommandLogBuffer()

    init(
        provider: any OutdatedPackagesProviding,
        commandExecutor: any BrewCommandExecuting,
        notificationScheduler: any CommandNotificationScheduling = NullCommandNotificationScheduler(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.provider = provider
        self.commandExecutor = commandExecutor
        self.notificationScheduler = notificationScheduler
        homebrewStateObserver = HomebrewStateObserver(notificationCenter: notificationCenter) { [weak self] _ in
            self?.handleHomebrewStateChange()
        }
    }

    deinit {
        actionTask?.cancel()
    }

    var filteredPackages: [OutdatedPackage] {
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
                package.fullName.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.currentVersion.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.installedVersions.joined(separator: " ").localizedCaseInsensitiveContains(trimmedQuery)
        }

        return filtered.sorted(by: sorter(for: sortOption))
    }

    var activeFilterCount: Int {
        activeFilters.count
    }

    var hasRunningAction: Bool {
        actionState.isRunning
    }

    var upgradeAllCommand: OutdatedPackageActionCommand? {
        OutdatedPackageActionCommand.upgradeAll(packages: filteredPackages)
    }

    var upgradeAllDescription: String {
        let visiblePackages = filteredPackages
        let upgradeableCount = visiblePackages.filter(\.isUpgradeAvailable).count
        let blockedCount = visiblePackages.count - upgradeableCount

        guard !visiblePackages.isEmpty else {
            return "There are no visible outdated packages to upgrade right now."
        }

        if upgradeableCount == 0 {
            return blockedCount == 1
                ? "The visible outdated package is pinned and can't be upgraded until it is unpinned."
                : "All visible outdated packages are pinned and need to be unpinned before upgrading."
        }

        if blockedCount == 0 {
            return upgradeableCount == 1
                ? "Upgrade the visible outdated package in one step."
                : "Upgrade all \(upgradeableCount) visible outdated packages in one step."
        }

        return "Upgrade \(upgradeableCount) visible outdated package\(upgradeableCount == 1 ? "" : "s"). \(blockedCount) pinned package\(blockedCount == 1 ? "" : "s") will be skipped."
    }

    var upgradeAllLogs: [CommandLogEntry] {
        guard actionState.command?.isBulkAction == true else {
            return []
        }

        return actionLogs
    }

    var upgradeAllState: OutdatedPackageActionState {
        guard actionState.command?.isBulkAction == true else {
            return .idle
        }

        return actionState
    }

    func loadIfNeeded() {
        guard case .idle = packagesState else {
            return
        }

        refreshPackages()
    }

    func refreshPackages() {
        packagesState = .loading

        Task { @MainActor [provider] in
            do {
                let packages = try await provider.fetchOutdatedPackages()
                packagesState = .loaded(packages)

                if let selectedPackage,
                   let refreshedSelection = packages.first(where: { $0.id == selectedPackage.id }) {
                    self.selectedPackage = refreshedSelection
                } else {
                    selectedPackage = defaultSelection(from: packages)
                }
            } catch {
                packagesState = .failed(error.localizedDescription)
                selectedPackage = nil
            }
        }
    }

    func toggleFilter(_ filter: OutdatedPackageFilterOption) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
    }

    func clearFilters() {
        activeFilters.removeAll()
    }

    func isFilterActive(_ filter: OutdatedPackageFilterOption) -> Bool {
        activeFilters.contains(filter)
    }

    func runAction(_ actionKind: OutdatedPackageActionKind, for package: OutdatedPackage) {
        guard package.isUpgradeAvailable else {
            return
        }

        runAction(package.actionCommand(for: actionKind), fallbackSelection: package)
    }

    func runUpgradeAll() {
        guard let command = upgradeAllCommand else {
            return
        }

        runAction(command, fallbackSelection: nil)
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

    func actionState(for package: OutdatedPackage) -> OutdatedPackageActionState {
        guard actionState.command?.packageID == package.id else {
            return .idle
        }

        return actionState
    }

    func actionLogs(for package: OutdatedPackage) -> [CommandLogEntry] {
        guard actionState.command?.packageID == package.id else {
            return []
        }

        return actionLogs
    }

    func isPackageInCurrentSnapshot(_ package: OutdatedPackage) -> Bool {
        guard case .loaded(let packages) = packagesState else {
            return false
        }

        return packages.contains(where: { $0.id == package.id })
    }

    private func matchesActiveFilters(for package: OutdatedPackage) -> Bool {
        activeFilters.allSatisfy { filter in
            switch filter {
            case .pinned:
                package.isPinned
            }
        }
    }

    private func sorter(for option: OutdatedPackageSortOption) -> (OutdatedPackage, OutdatedPackage) -> Bool {
        switch option {
        case .name:
            return { lhs, rhs in
                Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .currentVersion:
            return { lhs, rhs in
                let result = lhs.currentVersion.localizedStandardCompare(rhs.currentVersion)
                if result != .orderedSame {
                    return result == .orderedDescending
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .packageType:
            return { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        }
    }

    private func defaultSelection(from packages: [OutdatedPackage]) -> OutdatedPackage? {
        packages.sorted(by: sorter(for: sortOption)).first
    }

    private func reloadPackagesAfterAction(
        preservingSelectionID: String?,
        fallbackSelection: OutdatedPackage?
    ) {
        Task { @MainActor [provider] in
            do {
                let packages = try await provider.fetchOutdatedPackages()
                packagesState = .loaded(packages)

                if let preservingSelectionID,
                   let refreshedSelection = packages.first(where: { $0.id == preservingSelectionID }) {
                    selectedPackage = refreshedSelection
                } else {
                    selectedPackage = fallbackSelection ?? defaultSelection(from: packages)
                }
            } catch {
                appendLog(.system, error.localizedDescription)
            }
        }
    }

    private func runAction(
        _ command: OutdatedPackageActionCommand,
        fallbackSelection: OutdatedPackage?
    ) {
        let progress = OutdatedPackageActionProgress(command: command, startedAt: Date())

        actionTask?.cancel()
        actionTask = nil
        resetActionOutput()
        actionState = .running(progress)

        if command.isBulkAction {
            appendLog(.system, "Preparing \(command.kind.title.lowercased()) for \(command.packageCount) package\(command.packageCount == 1 ? "" : "s").")
        } else {
            appendLog(.system, "Preparing \(command.kind.title.lowercased()) for \(command.packageTitle).")
        }

        actionTask = Task { @MainActor [commandExecutor] in
            do {
                let result = try await commandExecutor.execute(arguments: command.arguments) { [weak self] kind, text in
                    self?.appendLog(kind, text)
                }
                flushPendingLogs()
                appendLog(.system, "\(command.kind.title) finished with exit code \(result.exitCode).")
                actionState = .succeeded(progress.finished(at: Date()), result)
                await notifyActionSucceeded(command: command)
                reloadPackagesAfterAction(
                    preservingSelectionID: fallbackSelection?.id,
                    fallbackSelection: fallbackSelection
                )
            } catch is CancellationError {
                flushPendingLogs()
                appendLog(.system, "\(command.kind.title) cancelled.")
                actionState = .cancelled(progress.finished(at: Date()))
                await notifyActionCancelled(command: command)
            } catch {
                flushPendingLogs()
                appendLog(.system, error.localizedDescription)
                actionState = .failed(progress.finished(at: Date()), error.localizedDescription)
                await notifyActionFailed(command: command, error: error)
            }

            actionTask = nil
        }
    }

    private func resetActionOutput() {
        logBuffer.reset()
        actionLogs = []
    }

    private func appendLog(_ kind: CommandLogKind, _ text: String, timestamp: Date = Date()) {
        logBuffer.append(kind, text, timestamp: timestamp)
        actionLogs = logBuffer.entries
    }

    private func flushPendingLogs() {
        logBuffer.flush()
        actionLogs = logBuffer.entries
    }

    private static func compare(_ lhs: String, _ rhs: String, fallback: Bool) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result != .orderedSame {
            return result == .orderedAscending
        }
        return fallback
    }

    private func notifyActionSucceeded(command: OutdatedPackageActionCommand) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(command.kind.title) Complete",
                body: successBody(for: command)
            )
        )
    }

    private func notifyActionCancelled(command: OutdatedPackageActionCommand) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(command.kind.title) Cancelled",
                body: cancellationBody(for: command)
            )
        )
    }

    private func notifyActionFailed(
        command: OutdatedPackageActionCommand,
        error: Error
    ) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(command.kind.title) Failed",
                body: CommandPresentation.friendlyFailureDescription(
                    error.localizedDescription,
                    fallback: failureFallback(for: command)
                )
            )
        )
    }

    private func successBody(for command: OutdatedPackageActionCommand) -> String {
        if command.isBulkAction {
            return "\(command.packageCount) package\(command.packageCount == 1 ? "" : "s") completed successfully."
        }

        return "\(command.packageTitle) completed successfully."
    }

    private func cancellationBody(for command: OutdatedPackageActionCommand) -> String {
        if command.isBulkAction {
            return "The bulk upgrade was cancelled before it finished."
        }

        return "\(command.packageTitle) was cancelled before it finished."
    }

    private func failureFallback(for command: OutdatedPackageActionCommand) -> String {
        if command.isBulkAction {
            return "The bulk upgrade couldn’t be completed."
        }

        return "\(command.packageTitle) couldn’t be completed."
    }

    private func handleHomebrewStateChange() {
        guard !hasRunningAction else {
            return
        }

        switch packagesState {
        case .idle, .loading:
            return
        case .loaded, .failed:
            refreshPackages()
        }
    }
}

extension OutdatedPackagesViewModel {
    static func live() -> OutdatedPackagesViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)
        let commandExecutor = BrewCommandExecutor(
            brewLocator: brewLocator,
            runner: runner
        )

        return OutdatedPackagesViewModel(
            provider: BrewOutdatedPackagesProvider(
                brewLocator: brewLocator,
                runner: runner
            ),
            commandExecutor: commandExecutor,
            notificationScheduler: CommandNotificationScheduler.shared,
            notificationCenter: .default
        )
    }
}
