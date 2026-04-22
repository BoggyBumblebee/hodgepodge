import Foundation

@MainActor
final class BrewfileViewModel: ObservableObject {
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
    private let picker: any BrewfilePicking
    private let dumpDestinationPicker: any BrewfileDumpDestinationPicking
    private let commandExecutor: any BrewCommandExecuting
    private let fileManager: FileManager
    private var actionTask: Task<Void, Never>?
    private var logBuffer = CommandLogBuffer()

    init(
        loader: any BrewfileDocumentLoading,
        selectionStore: any BrewfileSelectionStoring,
        picker: any BrewfilePicking,
        dumpDestinationPicker: any BrewfileDumpDestinationPicking,
        commandExecutor: any BrewCommandExecuting,
        fileManager: FileManager = .default
    ) {
        self.loader = loader
        self.selectionStore = selectionStore
        self.picker = picker
        self.dumpDestinationPicker = dumpDestinationPicker
        self.commandExecutor = commandExecutor
        self.fileManager = fileManager
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

    func actionCommand(for kind: BrewfileActionKind) -> BrewfileActionCommand? {
        guard let selectedFileURL else {
            return nil
        }

        return BrewfileActionCommand(kind: kind, fileURL: selectedFileURL)
    }

    func loadIfNeeded() {
        guard case .idle = documentState else {
            return
        }

        if let initialURL = initialSelectionURL() {
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
        selectionStore.saveSelection(fileURL)

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
                actionState = .succeeded(progress.finished(at: Date()), result)

                if shouldReloadAfterSuccess {
                    reloadDocumentAfterSuccessfulAction(fileURL: documentURLForReload)
                }
            } catch is CancellationError {
                flushPendingLogs()
                appendLog(.system, "\(command.kind.title) cancelled.")
                actionState = .cancelled(progress.finished(at: Date()))
            } catch {
                flushPendingLogs()
                appendLog(.system, error.localizedDescription)
                actionState = .failed(progress.finished(at: Date()), error.localizedDescription)
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
}

extension BrewfileViewModel {
    static func live() -> BrewfileViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)

        return BrewfileViewModel(
            loader: BrewfileDocumentLoader(),
            selectionStore: BrewfileSelectionStore(),
            picker: BrewfilePicker(),
            dumpDestinationPicker: BrewfileDumpDestinationPicker(),
            commandExecutor: BrewCommandExecutor(
                brewLocator: brewLocator,
                runner: runner
            )
        )
    }
}
