import Foundation

@MainActor
final class BrewfileViewModel: ObservableObject {
    struct Dependencies {
        let loader: any BrewfileDocumentLoading
        let selectionStore: any BrewfileSelectionStoring
        let settingsStore: any AppSettingsStoring
        let picker: any BrewfilePicking
        let dumpDestinationPicker: any BrewfileDumpDestinationPicking
        let commandExecutor: any BrewCommandExecuting
        let fileManager: FileManager

        init(
            loader: any BrewfileDocumentLoading,
            selectionStore: any BrewfileSelectionStoring,
            settingsStore: any AppSettingsStoring = AppSettingsStore(),
            picker: any BrewfilePicking,
            dumpDestinationPicker: any BrewfileDumpDestinationPicking,
            commandExecutor: any BrewCommandExecuting,
            fileManager: FileManager = .default
        ) {
            self.loader = loader
            self.selectionStore = selectionStore
            self.settingsStore = settingsStore
            self.picker = picker
            self.dumpDestinationPicker = dumpDestinationPicker
            self.commandExecutor = commandExecutor
            self.fileManager = fileManager
        }
    }

    @Published var documentState: BrewfileLoadState = .idle
    @Published var actionState: BrewfileActionState = .idle
    @Published var actionLogs: [CommandLogEntry] = []
    @Published var selectedFileURL: URL?
    @Published var searchText = ""
    @Published var filterOption: BrewfileFilterOption = .all
    @Published var sortOption: BrewfileSortOption = .fileOrder
    @Published var selectedLine: BrewfileLine?

    private let loader: any BrewfileDocumentLoading
    private let selectionStore: any BrewfileSelectionStoring
    private let settingsStore: any AppSettingsStoring
    private let picker: any BrewfilePicking
    private let dumpDestinationPicker: any BrewfileDumpDestinationPicking
    private let commandExecutor: any BrewCommandExecuting
    private let notificationScheduler: any CommandNotificationScheduling
    private let fileManager: FileManager
    private var actionTask: Task<Void, Never>?
    private var logBuffer = CommandLogBuffer()

    init(
        dependencies: Dependencies,
        notificationScheduler: any CommandNotificationScheduling = NullCommandNotificationScheduler()
    ) {
        self.loader = dependencies.loader
        self.selectionStore = dependencies.selectionStore
        self.settingsStore = dependencies.settingsStore
        self.picker = dependencies.picker
        self.dumpDestinationPicker = dependencies.dumpDestinationPicker
        self.commandExecutor = dependencies.commandExecutor
        self.notificationScheduler = notificationScheduler
        self.fileManager = dependencies.fileManager
    }

    deinit {
        actionTask?.cancel()
    }

    var filteredLines: [BrewfileLine] {
        guard case .loaded(let document) = documentState else {
            return []
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = document.lines.filter { line in
            guard matchesFilter(line) else {
                return false
            }

            guard !trimmedQuery.isEmpty else {
                return true
            }

            return line.searchText.localizedCaseInsensitiveContains(trimmedQuery)
        }

        return filtered.sorted(by: sorter(for: sortOption))
    }

    var summaryMetrics: [BrewfileMetric] {
        guard case .loaded(let document) = documentState else {
            return []
        }

        return document.summaryMetrics
    }

    var selectedFileDisplayName: String {
        selectedFileURL?.lastPathComponent ?? "No Brewfile Selected"
    }

    var hasRunningAction: Bool {
        actionState.isRunning
    }

    var dumpCommandPreview: String {
        guard let selectedFileURL else {
            return BrewfileActionCommand(
                kind: .dump,
                fileURL: fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Brewfile")
            ).command
        }

        return BrewfileActionCommand(kind: .dump, fileURL: selectedFileURL).command
    }

    var removableSelectedEntry: BrewfileEntry? {
        guard let entry = selectedLine?.entry,
              entry.kind.supportsBundleRemove else {
            return nil
        }

        return entry
    }

    func actionCommand(for kind: BrewfileActionKind) -> BrewfileActionCommand? {
        guard let selectedFileURL else {
            return nil
        }

        return BrewfileActionCommand(kind: kind, fileURL: selectedFileURL)
    }

    func removeCommandForSelectedEntry() -> BrewfileActionCommand? {
        guard let selectedFileURL,
              let entry = removableSelectedEntry else {
            return nil
        }

        return BrewfileActionCommand(
            kind: .remove,
            fileURL: selectedFileURL,
            entryName: entry.name,
            entryKind: entry.kind
        )
    }

    func addCommandPreview(for draft: BrewfileEntryDraft) -> String? {
        guard let selectedFileURL,
              let command = draft.command(fileURL: selectedFileURL) else {
            return nil
        }

        return command.command
    }

    func loadIfNeeded() {
        guard case .idle = documentState else {
            return
        }

        if shouldRestoreLastSelectedBrewfile, let initialURL = initialSelectionURL() {
            loadDocument(at: initialURL)
        }
    }

    func chooseBrewfile() {
        let startingDirectory = selectedFileURL?.deletingLastPathComponent()
        guard let pickedURL = picker.pickBrewfile(startingDirectory: startingDirectory) else {
            return
        }

        loadDocument(at: pickedURL)
    }

    func reloadBrewfile() {
        guard let selectedFileURL else {
            return
        }

        loadDocument(at: selectedFileURL)
    }

    func clearSelection() {
        clearActionOutput()
        selectedFileURL = nil
        selectedLine = nil
        documentState = .idle
        selectionStore.saveSelection(nil)
    }

    func selectLine(id: BrewfileLine.ID) {
        selectedLine = filteredLines.first(where: { $0.id == id })
    }

    func runAction(_ actionKind: BrewfileActionKind) {
        guard let selectedFileURL else {
            return
        }

        guard actionKind != .dump else {
            runDumpAction(from: selectedFileURL)
            return
        }

        let command = BrewfileActionCommand(kind: actionKind, fileURL: selectedFileURL)
        runAction(
            command,
            documentURLForReload: selectedFileURL,
            shouldReloadAfterSuccess: actionKind == .install
        )
    }

    func runAddEntry(using draft: BrewfileEntryDraft) {
        guard let selectedFileURL,
              let command = draft.command(fileURL: selectedFileURL) else {
            return
        }

        runAction(
            command,
            documentURLForReload: selectedFileURL,
            shouldReloadAfterSuccess: true
        )
    }

    func runPreparedAction(_ command: BrewfileActionCommand) {
        guard let selectedFileURL else {
            return
        }

        switch command.kind {
        case .install, .remove:
            runAction(
                command,
                documentURLForReload: selectedFileURL,
                shouldReloadAfterSuccess: true
            )
        case .check, .dump, .add:
            runAction(
                command,
                documentURLForReload: selectedFileURL,
                shouldReloadAfterSuccess: false
            )
        }
    }

    func runRemoveSelectedEntry() {
        guard let selectedFileURL,
              let command = removeCommandForSelectedEntry() else {
            return
        }

        runAction(
            command,
            documentURLForReload: selectedFileURL,
            shouldReloadAfterSuccess: true
        )
    }

    private func runDumpAction(from selectedFileURL: URL) {
        guard let destinationURL = dumpDestinationPicker.chooseDestination(
            suggestedFileName: selectedFileURL.lastPathComponent,
            startingDirectory: selectedFileURL.deletingLastPathComponent()
        ) else {
            return
        }

        runAction(
            BrewfileActionCommand(kind: .dump, fileURL: destinationURL),
            documentURLForReload: selectedFileURL,
            shouldReloadAfterSuccess: destinationURL == selectedFileURL
        )
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

    private func loadDocument(at fileURL: URL) {
        clearActionOutput()
        documentState = .loading
        selectedFileURL = fileURL
        selectionStore.saveSelection(shouldRestoreLastSelectedBrewfile ? fileURL : nil)

        Task { @MainActor [loader] in
            do {
                let document = try loader.loadDocument(at: fileURL)
                documentState = .loaded(document)

                if let selectedLine,
                   let refreshedSelection = document.lines.first(where: { $0.id == selectedLine.id }) {
                    self.selectedLine = refreshedSelection
                } else {
                    selectedLine = defaultSelection(from: document.lines)
                }
            } catch {
                documentState = .failed(error.localizedDescription)
                selectedLine = nil
            }
        }
    }

    private func reloadDocumentAfterSuccessfulAction(
        fileURL: URL
    ) {
        Task { @MainActor [loader] in
            do {
                let document = try loader.loadDocument(at: fileURL)
                guard selectedFileURL == fileURL else {
                    return
                }

                documentState = .loaded(document)

                if let selectedLine,
                   let refreshedSelection = document.lines.first(where: { $0.id == selectedLine.id }) {
                    self.selectedLine = refreshedSelection
                } else {
                    selectedLine = defaultSelection(from: document.lines)
                }
            } catch {
                guard selectedFileURL == fileURL else {
                    return
                }

                documentState = .failed(error.localizedDescription)
                selectedLine = nil
            }
        }
    }

    private func runAction(
        _ command: BrewfileActionCommand,
        documentURLForReload: URL,
        shouldReloadAfterSuccess: Bool
    ) {
        let progress = BrewfileActionProgress(command: command, startedAt: Date())

        actionTask?.cancel()
        actionTask = nil
        resetActionOutput()
        actionState = .running(progress)
        appendLog(.system, "Preparing \(command.kind.title.lowercased()) for \(command.fileURL.lastPathComponent).")

        actionTask = Task { @MainActor [commandExecutor] in
            do {
                let result = try await commandExecutor.execute(arguments: command.arguments) { [weak self] kind, text in
                    self?.appendLog(kind, text)
                }
                flushPendingLogs()
                appendLog(.system, "\(command.kind.title) finished with exit code \(result.exitCode).")
                let completedProgress = progress.finished(at: Date())
                actionState = .succeeded(completedProgress, result)
                await notifyActionSucceeded(command: command, elapsedTime: completedProgress.elapsedTime())

                if shouldReloadAfterSuccess {
                    reloadDocumentAfterSuccessfulAction(fileURL: documentURLForReload)
                }
            } catch is CancellationError {
                flushPendingLogs()
                appendLog(.system, "\(command.kind.title) cancelled.")
                let completedProgress = progress.finished(at: Date())
                actionState = .cancelled(completedProgress)
                await notifyActionCancelled(command: command, elapsedTime: completedProgress.elapsedTime())
            } catch {
                flushPendingLogs()
                appendLog(.system, error.localizedDescription)
                let completedProgress = progress.finished(at: Date())
                actionState = .failed(completedProgress, error.localizedDescription)
                await notifyActionFailed(command: command, error: error, elapsedTime: completedProgress.elapsedTime())
            }

            actionTask = nil
        }
    }

    private func initialSelectionURL() -> URL? {
        if let storedURL = selectionStore.loadSelection(),
           fileManager.fileExists(atPath: storedURL.path) {
            selectedFileURL = storedURL
            return storedURL
        }

        for candidate in defaultCandidateURLs() where fileManager.fileExists(atPath: candidate.path) {
            selectedFileURL = candidate
            selectionStore.saveSelection(candidate)
            return candidate
        }

        return nil
    }

    private var shouldRestoreLastSelectedBrewfile: Bool {
        settingsStore.loadSettings().restoreLastSelectedBrewfile
    }

    private func defaultCandidateURLs() -> [URL] {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)

        return [
            currentDirectory.appendingPathComponent("Brewfile", isDirectory: false),
            homeDirectory.appendingPathComponent(".Brewfile", isDirectory: false),
            homeDirectory.appendingPathComponent(".homebrew/Brewfile", isDirectory: false)
        ]
    }

    private func matchesFilter(_ line: BrewfileLine) -> Bool {
        switch filterOption {
        case .all:
            true
        case .entries:
            line.category == .entry
        case .comments:
            line.category == .comment
        case .unknown:
            line.category == .unknown
        }
    }

    private func sorter(for option: BrewfileSortOption) -> (BrewfileLine, BrewfileLine) -> Bool {
        switch option {
        case .fileOrder:
            return { $0.lineNumber < $1.lineNumber }
        case .name:
            return { lhs, rhs in
                let lhsText = lhs.title
                let rhsText = rhs.title
                let result = lhsText.localizedCaseInsensitiveCompare(rhsText)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
                return lhs.lineNumber < rhs.lineNumber
            }
        case .kind:
            return { lhs, rhs in
                let lhsText = lhs.subtitle
                let rhsText = rhs.subtitle
                let result = lhsText.localizedCaseInsensitiveCompare(rhsText)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
                return lhs.lineNumber < rhs.lineNumber
            }
        }
    }

    private func defaultSelection(from lines: [BrewfileLine]) -> BrewfileLine? {
        lines.sorted(by: sorter(for: sortOption)).first
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

    private func notifyActionSucceeded(
        command: BrewfileActionCommand,
        elapsedTime: TimeInterval
    ) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(command.kind.title) Complete",
                body: "\(command.fileURL.lastPathComponent) completed successfully.",
                elapsedTime: elapsedTime,
                category: .brewfiles
            )
        )
    }

    private func notifyActionCancelled(
        command: BrewfileActionCommand,
        elapsedTime: TimeInterval
    ) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(command.kind.title) Cancelled",
                body: "\(command.fileURL.lastPathComponent) was cancelled before it finished.",
                elapsedTime: elapsedTime,
                category: .brewfiles
            )
        )
    }

    private func notifyActionFailed(
        command: BrewfileActionCommand,
        error: Error,
        elapsedTime: TimeInterval
    ) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(command.kind.title) Failed",
                body: CommandPresentation.friendlyFailureDescription(
                    error.localizedDescription,
                    fallback: "\(command.fileURL.lastPathComponent) couldn’t be completed."
                ),
                elapsedTime: elapsedTime,
                category: .brewfiles
            )
        )
    }
}

extension BrewfileViewModel {
    static func live(
        notificationScheduler: any CommandNotificationScheduling = CommandNotificationScheduler.live(),
        settingsStore: any AppSettingsStoring = AppSettingsStore()
    ) -> BrewfileViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)

        return BrewfileViewModel(
            dependencies: Dependencies(
                loader: BrewfileDocumentLoader(),
                selectionStore: BrewfileSelectionStore(),
                settingsStore: settingsStore,
                picker: BrewfilePicker(),
                dumpDestinationPicker: BrewfileDumpDestinationPicker(),
                commandExecutor: BrewCommandExecutor(
                    brewLocator: brewLocator,
                    runner: runner
                )
            ),
            notificationScheduler: notificationScheduler
        )
    }
}
