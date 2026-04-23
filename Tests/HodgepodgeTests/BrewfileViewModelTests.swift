import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class BrewfileViewModelTests: XCTestCase {
    func testLoadIfNeededUsesStoredSelectionAndLoadsDocument() async {
        let fileURL = makeExistingBrewfileURL()
        let document = BrewfileDocument.fixture(fileURL: fileURL)
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [fileURL: document]),
            selectionStore: MockBrewfileSelectionStore(loadedURL: fileURL),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: MockBrewfileCommandExecutor()
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.documentState == .loaded(document)
        }

        XCTAssertEqual(viewModel.selectedFileURL, fileURL)
        XCTAssertEqual(viewModel.selectedLine?.id, 1)
    }

    func testFilteredLinesRespectSearchFilterAndSort() {
        let document = BrewfileDocument.fixture()
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [:]),
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: MockBrewfileCommandExecutor()
        )
        viewModel.documentState = .loaded(document)

        viewModel.searchText = "desktop"
        XCTAssertEqual(viewModel.filteredLines.map(\.lineNumber), [3])

        viewModel.searchText = ""
        viewModel.filterOption = .entries
        XCTAssertEqual(viewModel.filteredLines.map(\.lineNumber), [1, 2])

        viewModel.filterOption = .all
        viewModel.sortOption = .name
        XCTAssertEqual(viewModel.filteredLines.first?.title, "brewfile_command something")
    }

    func testChooseBrewfileLoadsDocumentAndPersistsSelection() async {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let document = BrewfileDocument.fixture(fileURL: fileURL)
        let store = MockBrewfileSelectionStore()
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [fileURL: document]),
            selectionStore: store,
            picker: MockBrewfilePicker(result: fileURL),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: MockBrewfileCommandExecutor()
        )

        viewModel.chooseBrewfile()
        await waitUntil {
            viewModel.documentState == .loaded(document)
        }

        XCTAssertEqual(store.savedURLs, [fileURL])
        XCTAssertEqual(viewModel.selectedFileURL, fileURL)
    }

    func testClearSelectionResetsStateAndClearsStoredURL() {
        let store = MockBrewfileSelectionStore()
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [:]),
            selectionStore: store,
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: MockBrewfileCommandExecutor()
        )
        viewModel.selectedFileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        viewModel.selectedLine = .fixture()
        viewModel.documentState = .loaded(.fixture())

        viewModel.clearSelection()

        XCTAssertNil(viewModel.selectedFileURL)
        XCTAssertNil(viewModel.selectedLine)
        XCTAssertEqual(viewModel.documentState, .idle)
        XCTAssertEqual(store.savedURLs, [nil])
    }

    func testLoadIfNeededWithoutStoredOrDefaultSelectionLeavesStateIdle() {
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [:]),
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: MockBrewfileCommandExecutor()
        )

        viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.documentState, .idle)
        XCTAssertNil(viewModel.selectedFileURL)
    }

    func testReloadBrewfileLoadsFailureWhenLoaderThrows() async {
        let fileURL = makeExistingBrewfileURL()
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [:]),
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: MockBrewfileCommandExecutor()
        )
        viewModel.selectedFileURL = fileURL

        viewModel.reloadBrewfile()
        await waitUntil {
            if case .failed = viewModel.documentState {
                return true
            }
            return false
        }

        XCTAssertNil(viewModel.selectedLine)
    }

    func testSelectLineUsesCurrentFilteredLines() {
        let document = BrewfileDocument.fixture()
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [:]),
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: MockBrewfileCommandExecutor()
        )
        viewModel.documentState = .loaded(document)
        viewModel.filterOption = .comments

        viewModel.selectLine(id: 3)

        XCTAssertEqual(viewModel.selectedLine?.id, 3)
    }

    func testRunActionStoresSuccessStateAndStreamsLogs() async {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let executor = MockBrewfileCommandExecutor(result: .success(CommandResult(stdout: "ok\n", stderr: "", exitCode: 0)))
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [:]),
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: executor
        )
        viewModel.selectedFileURL = fileURL

        viewModel.runAction(.check)
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return true
            }
            return false
        }

        XCTAssertEqual(
            executor.executedArguments,
            [["bundle", "check", "--file", "/tmp/Brewfile", "--verbose", "--no-upgrade"]]
        )
        XCTAssertFalse(viewModel.actionLogs.isEmpty)
    }

    func testInstallActionReloadsDocumentAfterSuccess() async {
        let fileURL = makeExistingBrewfileURL()
        let document = BrewfileDocument.fixture(fileURL: fileURL)
        let loader = RecordingBrewfileLoader(documents: [fileURL: document])
        let executor = MockBrewfileCommandExecutor(
            result: .success(CommandResult(stdout: "Installed\n", stderr: "", exitCode: 0))
        )
        let viewModel = BrewfileViewModel(
            loader: loader,
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: executor
        )
        viewModel.selectedFileURL = fileURL

        viewModel.runAction(.install)
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return viewModel.documentState == .loaded(document)
            }
            return false
        }

        XCTAssertEqual(
            executor.executedArguments,
            [["bundle", "install", "--file", fileURL.path, "--verbose"]]
        )
        XCTAssertEqual(loader.loadedURLs, [fileURL])
    }

    func testDumpActionUsesDestinationPickerAndDoesNotReloadWhenExportingElsewhere() async {
        let fileURL = makeExistingBrewfileURL()
        let destinationURL = URL(fileURLWithPath: "/tmp/ExportedBrewfile")
        let loader = RecordingBrewfileLoader(documents: [:])
        let executor = MockBrewfileCommandExecutor(
            result: .success(CommandResult(stdout: "Dumped\n", stderr: "", exitCode: 0))
        )
        let viewModel = BrewfileViewModel(
            loader: loader,
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(result: destinationURL),
            commandExecutor: executor
        )
        viewModel.selectedFileURL = fileURL

        viewModel.runAction(.dump)
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return true
            }
            return false
        }

        XCTAssertEqual(
            executor.executedArguments,
            [["bundle", "dump", "--file", destinationURL.path, "--force"]]
        )
        XCTAssertEqual(loader.loadedURLs, [])
    }

    func testDumpActionReloadsDocumentWhenExportingToSelectedFile() async {
        let fileURL = makeExistingBrewfileURL()
        let document = BrewfileDocument.fixture(fileURL: fileURL)
        let loader = RecordingBrewfileLoader(documents: [fileURL: document])
        let executor = MockBrewfileCommandExecutor(
            result: .success(CommandResult(stdout: "Dumped\n", stderr: "", exitCode: 0))
        )
        let viewModel = BrewfileViewModel(
            loader: loader,
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(result: fileURL),
            commandExecutor: executor
        )
        viewModel.selectedFileURL = fileURL

        viewModel.runAction(.dump)
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return viewModel.documentState == .loaded(document)
            }
            return false
        }

        XCTAssertEqual(loader.loadedURLs, [fileURL])
    }

    func testAddEntryRunsBundleAddAndReloadsDocument() async {
        let fileURL = makeExistingBrewfileURL()
        let document = BrewfileDocument.fixture(fileURL: fileURL)
        let loader = RecordingBrewfileLoader(documents: [fileURL: document])
        let executor = MockBrewfileCommandExecutor(
            result: .success(CommandResult(stdout: "Added\n", stderr: "", exitCode: 0))
        )
        let viewModel = BrewfileViewModel(
            loader: loader,
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: executor
        )
        viewModel.selectedFileURL = fileURL

        viewModel.runAddEntry(using: BrewfileEntryDraft(kind: .cask, name: "visual-studio-code"))
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return viewModel.documentState == .loaded(document)
            }
            return false
        }

        XCTAssertEqual(
            executor.executedArguments,
            [["bundle", "add", "--cask", "visual-studio-code", "--file", fileURL.path]]
        )
        XCTAssertEqual(loader.loadedURLs, [fileURL])
    }

    func testRemoveSelectedEntryRunsBundleRemoveAndReloadsDocument() async {
        let fileURL = makeExistingBrewfileURL()
        let document = BrewfileDocument.fixture(fileURL: fileURL)
        let loader = RecordingBrewfileLoader(documents: [fileURL: document])
        let executor = MockBrewfileCommandExecutor(
            result: .success(CommandResult(stdout: "Removed\n", stderr: "", exitCode: 0))
        )
        let viewModel = BrewfileViewModel(
            loader: loader,
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: executor
        )
        viewModel.selectedFileURL = fileURL
        viewModel.documentState = .loaded(document)
        viewModel.selectedLine = BrewfileLine.fixture(
            lineNumber: 2,
            entry: BrewfileEntry.fixture(
                lineNumber: 2,
                kind: .brew,
                name: "wget",
                rawLine: #"brew "wget""#,
                options: [:]
            )
        )

        viewModel.runRemoveSelectedEntry()
        await waitUntil {
            if case .succeeded = viewModel.actionState {
                return loader.loadedURLs == [fileURL]
            }
            return false
        }

        XCTAssertEqual(
            executor.executedArguments,
            [["bundle", "remove", "--formula", "wget", "--file", fileURL.path]]
        )
        XCTAssertEqual(loader.loadedURLs, [fileURL])
    }

    func testRemoveCommandForSelectedEntryIsNilForNonEntryLines() {
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [:]),
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: MockBrewfileCommandExecutor()
        )
        viewModel.selectedFileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        viewModel.selectedLine = BrewfileLine.fixture(
            lineNumber: 3,
            category: .comment,
            entry: nil,
            rawLine: "# desktop apps",
            commentText: "desktop apps"
        )

        XCTAssertNil(viewModel.removeCommandForSelectedEntry())
    }

    func testRunActionStoresFailureState() async {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let executor = MockBrewfileCommandExecutor(result: .failure(CommandRunnerError.nonZeroExitCode(.init(stdout: "", stderr: "missing formula", exitCode: 1))))
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [:]),
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: executor
        )
        viewModel.selectedFileURL = fileURL

        viewModel.runAction(.check)
        await waitUntil {
            if case .failed = viewModel.actionState {
                return true
            }
            return false
        }

        guard case .failed(_, let message) = viewModel.actionState else {
            return XCTFail("Expected failed action state.")
        }
        XCTAssertEqual(message, "missing formula")
    }

    func testRunActionUsesStdoutMessageWhenFailureHasNoStderr() async {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let executor = MockBrewfileCommandExecutor(
            result: .failure(
                CommandRunnerError.nonZeroExitCode(
                    .init(
                        stdout: "brew bundle can't satisfy your Brewfile's dependencies.",
                        stderr: "",
                        exitCode: 1
                    )
                )
            )
        )
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [:]),
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: executor
        )
        viewModel.selectedFileURL = fileURL

        viewModel.runAction(.check)
        await waitUntil {
            if case .failed = viewModel.actionState {
                return true
            }
            return false
        }

        guard case .failed(_, let message) = viewModel.actionState else {
            return XCTFail("Expected failed action state.")
        }
        XCTAssertEqual(message, "brew bundle can't satisfy your Brewfile's dependencies.")
    }

    func testClearActionOutputResetsActionState() throws {
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [:]),
            selectionStore: MockBrewfileSelectionStore(),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: MockBrewfileCommandExecutor()
        )
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        viewModel.selectedFileURL = fileURL
        let command = try XCTUnwrap(BrewfileActionCommand.make(kind: .check, fileURL: fileURL))
        viewModel.actionState = .running(
            BrewfileActionProgress(
                command: command,
                startedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .system,
                text: "Running",
                timestamp: Date(timeIntervalSince1970: 1_001)
            )
        ]

        viewModel.clearActionOutput()

        XCTAssertEqual(viewModel.actionState, .idle)
        XCTAssertTrue(viewModel.actionLogs.isEmpty)
    }

    func testLoadIfNeededSkipsStoredSelectionWhenRestoreSettingIsDisabled() {
        let fileURL = makeExistingBrewfileURL()
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [:]),
            selectionStore: MockBrewfileSelectionStore(loadedURL: fileURL),
            settingsStore: MockAppSettingsStore(
                snapshot: AppSettingsSnapshot(
                    defaultLaunchSection: .catalog,
                    brewfile: .init(restoreLastSelectedBrewfile: false)
                )
            ),
            picker: MockBrewfilePicker(),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: MockBrewfileCommandExecutor()
        )

        viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.documentState, .idle)
        XCTAssertNil(viewModel.selectedFileURL)
    }

    func testChooseBrewfileDoesNotPersistSelectionWhenRestoreSettingIsDisabled() async {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let document = BrewfileDocument.fixture(fileURL: fileURL)
        let store = MockBrewfileSelectionStore()
        let viewModel = BrewfileViewModel(
            loader: MockBrewfileLoader(documents: [fileURL: document]),
            selectionStore: store,
            settingsStore: MockAppSettingsStore(
                snapshot: AppSettingsSnapshot(
                    defaultLaunchSection: .catalog,
                    brewfile: .init(restoreLastSelectedBrewfile: false)
                )
            ),
            picker: MockBrewfilePicker(result: fileURL),
            dumpDestinationPicker: MockBrewfileDumpDestinationPicker(),
            commandExecutor: MockBrewfileCommandExecutor()
        )

        viewModel.chooseBrewfile()
        await waitUntil {
            viewModel.documentState == .loaded(document)
        }

        XCTAssertEqual(store.savedURLs, [nil])
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

    private func makeExistingBrewfileURL() -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("Brewfile", isDirectory: false)
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}

private struct MockBrewfileLoader: BrewfileDocumentLoading {
    let documents: [URL: BrewfileDocument]

    func loadDocument(at fileURL: URL) throws -> BrewfileDocument {
        if let document = documents[fileURL] {
            return document
        }

        throw CocoaError(.fileNoSuchFile)
    }
}

private final class RecordingBrewfileLoader: BrewfileDocumentLoading, @unchecked Sendable {
    let documents: [URL: BrewfileDocument]
    private(set) var loadedURLs: [URL] = []

    init(documents: [URL: BrewfileDocument]) {
        self.documents = documents
    }

    func loadDocument(at fileURL: URL) throws -> BrewfileDocument {
        loadedURLs.append(fileURL)

        if let document = documents[fileURL] {
            return document
        }

        throw CocoaError(.fileNoSuchFile)
    }
}

private final class MockBrewfileSelectionStore: BrewfileSelectionStoring, @unchecked Sendable {
    let loadedURL: URL?
    private(set) var savedURLs: [URL?] = []

    init(loadedURL: URL? = nil) {
        self.loadedURL = loadedURL
    }

    func loadSelection() -> URL? {
        loadedURL
    }

    func saveSelection(_ url: URL?) {
        savedURLs.append(url)
    }
}

private struct MockAppSettingsStore: AppSettingsStoring {
    let snapshot: AppSettingsSnapshot

    init(snapshot: AppSettingsSnapshot = .standard) {
        self.snapshot = snapshot
    }

    func loadSettings() -> AppSettingsSnapshot {
        snapshot
    }

    func saveSettings(_ snapshot: AppSettingsSnapshot) {}
}

private extension BrewfileViewModel {
    convenience init(
        loader: any BrewfileDocumentLoading,
        selectionStore: any BrewfileSelectionStoring,
        settingsStore: any AppSettingsStoring = AppSettingsStore(),
        picker: any BrewfilePicking,
        dumpDestinationPicker: any BrewfileDumpDestinationPicking,
        commandExecutor: any BrewCommandExecuting,
        notificationScheduler: any CommandNotificationScheduling = NullCommandNotificationScheduler(),
        fileManager: FileManager = .default
    ) {
        self.init(
            dependencies: Dependencies(
                loader: loader,
                selectionStore: selectionStore,
                settingsStore: settingsStore,
                picker: picker,
                dumpDestinationPicker: dumpDestinationPicker,
                commandExecutor: commandExecutor,
                fileManager: fileManager
            ),
            notificationScheduler: notificationScheduler
        )
    }
}

private struct MockBrewfilePicker: BrewfilePicking {
    let result: URL?

    init(result: URL? = nil) {
        self.result = result
    }

    @MainActor
    func pickBrewfile(startingDirectory: URL?) -> URL? {
        result
    }
}

@MainActor
private struct MockBrewfileDumpDestinationPicker: BrewfileDumpDestinationPicking {
    let result: URL?

    init(result: URL? = nil) {
        self.result = result
    }

    func chooseDestination(
        suggestedFileName: String,
        startingDirectory: URL?
    ) -> URL? {
        result
    }
}

private final class MockBrewfileCommandExecutor: BrewCommandExecuting, @unchecked Sendable {
    let result: Result<CommandResult, Error>
    private(set) var executedArguments: [[String]] = []

    init(result: Result<CommandResult, Error> = .success(CommandResult(stdout: "", stderr: "", exitCode: 0))) {
        self.result = result
    }

    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        executedArguments.append(arguments)
        await onLog(.system, "Using Homebrew at /opt/homebrew/bin/brew")
        await onLog(.stdout, "Checking Brewfile...\n")
        return try result.get()
    }
}
