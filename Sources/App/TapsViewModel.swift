import Foundation

@MainActor
final class TapsViewModel: ObservableObject {
    @Published var tapsState: BrewTapLoadState = .idle
    @Published var searchText = ""
    @Published var activeFilters: Set<BrewTapFilterOption> = []
    @Published var sortOption: BrewTapSortOption = .name
    @Published var selectedTap: BrewTap?
    @Published var addTapName = ""
    @Published var addTapRemoteURL = ""
    @Published var untapForce = false
    @Published var actionState: BrewTapActionState = .idle
    @Published var actionLogs: [CommandLogEntry] = []

    private let provider: any BrewTapsProviding
    private let commandExecutor: any BrewCommandExecuting
    private let notificationScheduler: any CommandNotificationScheduling
    private var actionTask: Task<Void, Never>?
    private var logBuffer = CommandLogBuffer()

    init(
        provider: any BrewTapsProviding,
        commandExecutor: any BrewCommandExecuting,
        notificationScheduler: any CommandNotificationScheduling = NullCommandNotificationScheduler()
    ) {
        self.provider = provider
        self.commandExecutor = commandExecutor
        self.notificationScheduler = notificationScheduler
    }

    deinit {
        actionTask?.cancel()
    }

    var filteredTaps: [BrewTap] {
        guard case .loaded(let taps) = tapsState else {
            return []
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = taps.filter { tap in
            guard matchesActiveFilters(for: tap) else {
                return false
            }

            guard !trimmedQuery.isEmpty else {
                return true
            }

            return tap.name.localizedCaseInsensitiveContains(trimmedQuery) ||
                tap.subtitle.localizedCaseInsensitiveContains(trimmedQuery) ||
                tap.path.localizedCaseInsensitiveContains(trimmedQuery) ||
                (tap.remote?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        }

        return filtered.sorted(by: sorter(for: sortOption))
    }

    var activeFilterCount: Int {
        activeFilters.count
    }

    var hasRunningAction: Bool {
        actionState.isRunning
    }

    var addTapCommand: BrewTapActionCommand? {
        let trimmedName = addTapName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return nil
        }

        let trimmedRemote = addTapRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return .add(
            name: trimmedName,
            remoteURL: trimmedRemote.isEmpty ? nil : trimmedRemote
        )
    }

    func loadIfNeeded() {
        guard case .idle = tapsState else {
            return
        }

        refreshTaps()
    }

    func refreshTaps() {
        tapsState = .loading

        Task { @MainActor [provider] in
            do {
                let taps = try await provider.fetchTaps()
                applyLoadedTaps(taps, selection: selectionPreservingCurrentTap(from: taps))
            } catch {
                tapsState = .failed(error.localizedDescription)
                selectedTap = nil
            }
        }
    }

    func toggleFilter(_ filter: BrewTapFilterOption) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
    }

    func clearFilters() {
        activeFilters.removeAll()
    }

    func isFilterActive(_ filter: BrewTapFilterOption) -> Bool {
        activeFilters.contains(filter)
    }

    func runAddTap() {
        guard let command = addTapCommand else {
            return
        }

        run(command, preservingSelectionID: selectedTap?.id)
    }

    func untapSelectedTap() {
        guard let selectedTap else {
            return
        }

        run(.untap(name: selectedTap.name, force: untapForce), preservingSelectionID: nil)
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

    func actionState(for tap: BrewTap) -> BrewTapActionState {
        guard isShowingActionDetails(for: tap) else {
            return .idle
        }

        return actionState
    }

    func actionLogs(for tap: BrewTap) -> [CommandLogEntry] {
        guard isShowingActionDetails(for: tap) else {
            return []
        }

        return actionLogs
    }

    func isTapInCurrentSnapshot(_ tap: BrewTap) -> Bool {
        guard case .loaded(let taps) = tapsState else {
            return false
        }

        return taps.contains(where: { $0.id == tap.id })
    }

    private func run(
        _ command: BrewTapActionCommand,
        preservingSelectionID: String?
    ) {
        let progress = BrewTapActionProgress(command: command, startedAt: Date())

        actionTask?.cancel()
        actionTask = nil
        resetActionOutput()
        actionState = .running(progress)
        appendLog(.system, "Preparing \(command.kind.title.lowercased()) for \(command.tapName).")

        actionTask = Task { @MainActor [commandExecutor] in
            do {
                let result = try await commandExecutor.execute(arguments: command.arguments) { [weak self] kind, text in
                    self?.appendLog(kind, text)
                }
                let completedProgress = progress.finished(at: Date())
                storeSucceededAction(command: command, progress: completedProgress, result: result)
                await notifyActionSucceeded(command: command, elapsedTime: completedProgress.elapsedTime())
                reloadTapsAfterAction(
                    command: command,
                    preservingSelectionID: preservingSelectionID
                )
            } catch is CancellationError {
                let completedProgress = progress.finished(at: Date())
                storeCancelledAction(command: command, progress: completedProgress)
                await notifyActionCancelled(command: command, elapsedTime: completedProgress.elapsedTime())
            } catch {
                let completedProgress = progress.finished(at: Date())
                storeFailedAction(progress: completedProgress, error: error)
                await notifyActionFailed(command: command, error: error, elapsedTime: completedProgress.elapsedTime())
            }

            actionTask = nil
        }
    }

    private func reloadTapsAfterAction(
        command: BrewTapActionCommand,
        preservingSelectionID: String?
    ) {
        Task { @MainActor [provider] in
            do {
                let taps = try await provider.fetchTaps()
                applyLoadedTaps(
                    taps,
                    selection: selectionAfterAction(
                        command: command,
                        preservingSelectionID: preservingSelectionID,
                        taps: taps
                    )
                )
                clearAddTapDraftIfNeeded(for: command)
            } catch {
                appendLog(.system, error.localizedDescription)
            }
        }
    }

    private func matchesActiveFilters(for tap: BrewTap) -> Bool {
        activeFilters.allSatisfy { filter in
            switch filter {
            case .official:
                tap.isOfficial
            case .customRemote:
                tap.customRemote
            case .privateTap:
                tap.isPrivate
            }
        }
    }

    private func sorter(for option: BrewTapSortOption) -> (BrewTap, BrewTap) -> Bool {
        switch option {
        case .name:
            return { lhs, rhs in
                Self.compare(lhs.name, rhs.name, fallback: lhs.id < rhs.id)
            }
        case .packageCount:
            return { lhs, rhs in
                if lhs.packageCount != rhs.packageCount {
                    return lhs.packageCount > rhs.packageCount
                }
                return Self.compare(lhs.name, rhs.name, fallback: lhs.id < rhs.id)
            }
        case .lastCommit:
            return { lhs, rhs in
                let lhsCommit = lhs.lastCommit ?? ""
                let rhsCommit = rhs.lastCommit ?? ""
                let result = lhsCommit.localizedCaseInsensitiveCompare(rhsCommit)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
                return Self.compare(lhs.name, rhs.name, fallback: lhs.id < rhs.id)
            }
        }
    }

    private func defaultSelection(from taps: [BrewTap]) -> BrewTap? {
        taps.sorted(by: sorter(for: sortOption)).first
    }

    private func selectionPreservingCurrentTap(from taps: [BrewTap]) -> BrewTap? {
        if let selectedTap,
           let refreshedSelection = taps.first(where: { $0.id == selectedTap.id }) {
            return refreshedSelection
        }

        return defaultSelection(from: taps)
    }

    private func selectionAfterAction(
        command: BrewTapActionCommand,
        preservingSelectionID: String?,
        taps: [BrewTap]
    ) -> BrewTap? {
        switch command {
        case .add(let name, _):
            return taps.first(where: { $0.name == name }) ?? defaultSelection(from: taps)
        case .untap(let name, _):
            if preservingSelectionID == name {
                return defaultSelection(from: taps)
            }
            if let preservingSelectionID,
               let preserved = taps.first(where: { $0.id == preservingSelectionID }) {
                return preserved
            }
            return defaultSelection(from: taps)
        }
    }

    private func applyLoadedTaps(_ taps: [BrewTap], selection: BrewTap?) {
        tapsState = .loaded(taps)
        selectedTap = selection
    }

    private func clearAddTapDraftIfNeeded(for command: BrewTapActionCommand) {
        guard case .add = command else {
            return
        }

        addTapName = ""
        addTapRemoteURL = ""
    }

    private static func compare(_ lhs: String, _ rhs: String, fallback: Bool) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result != .orderedSame {
            return result == .orderedAscending
        }
        return fallback
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

    private func isShowingActionDetails(for tap: BrewTap) -> Bool {
        actionState.command?.tapName == tap.name
    }

    private func storeSucceededAction(
        command: BrewTapActionCommand,
        progress: BrewTapActionProgress,
        result: CommandResult
    ) {
        flushPendingLogs()
        appendLog(.system, "\(command.kind.title) finished with exit code \(result.exitCode).")
        actionState = .succeeded(progress, result)
    }

    private func storeCancelledAction(
        command: BrewTapActionCommand,
        progress: BrewTapActionProgress
    ) {
        flushPendingLogs()
        appendLog(.system, "\(command.kind.title) cancelled.")
        actionState = .cancelled(progress)
    }

    private func storeFailedAction(
        progress: BrewTapActionProgress,
        error: Error
    ) {
        flushPendingLogs()
        appendLog(.system, error.localizedDescription)
        actionState = .failed(progress, error.localizedDescription)
    }

    private func notifyActionSucceeded(
        command: BrewTapActionCommand,
        elapsedTime: TimeInterval
    ) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(command.kind.title) Complete",
                body: "\(command.tapName) completed successfully.",
                elapsedTime: elapsedTime,
                category: .taps
            )
        )
    }

    private func notifyActionCancelled(
        command: BrewTapActionCommand,
        elapsedTime: TimeInterval
    ) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(command.kind.title) Cancelled",
                body: "\(command.tapName) was cancelled before it finished.",
                elapsedTime: elapsedTime,
                category: .taps
            )
        )
    }

    private func notifyActionFailed(
        command: BrewTapActionCommand,
        error: Error,
        elapsedTime: TimeInterval
    ) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(command.kind.title) Failed",
                body: CommandPresentation.friendlyFailureDescription(
                    error.localizedDescription,
                    fallback: "\(command.tapName) couldn’t be completed."
                ),
                elapsedTime: elapsedTime,
                category: .taps
            )
        )
    }
}

extension TapsViewModel {
    static func live(
        notificationScheduler: any CommandNotificationScheduling = CommandNotificationScheduler.live()
    ) -> TapsViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)
        let commandExecutor = BrewCommandExecutor(
            brewLocator: brewLocator,
            runner: runner
        )

        return TapsViewModel(
            provider: BrewTapsProvider(
                brewLocator: brewLocator,
                runner: runner
            ),
            commandExecutor: commandExecutor,
            notificationScheduler: notificationScheduler
        )
    }
}
