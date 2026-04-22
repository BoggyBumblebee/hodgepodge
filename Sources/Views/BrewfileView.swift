import SwiftUI

struct BrewfileView: View {
    @ObservedObject var viewModel: BrewfileViewModel
    @State private var pendingAction: BrewfileActionCommand?
    @State private var isPresentingAddEntrySheet = false
    @State private var addEntryDraft = BrewfileEntryDraft()

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 380, idealWidth: 500, maxWidth: .infinity)

            detail
                .frame(minWidth: 500, idealWidth: 760, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            viewModel.loadIfNeeded()
        }
        .sheet(isPresented: $isPresentingAddEntrySheet) {
            BrewfileAddEntrySheet(
                draft: $addEntryDraft,
                commandPreview: viewModel.addCommandPreview(for: addEntryDraft),
                onAdd: {
                    viewModel.runAddEntry(using: addEntryDraft)
                    isPresentingAddEntrySheet = false
                    addEntryDraft = BrewfileEntryDraft()
                },
                onCancel: {
                    isPresentingAddEntrySheet = false
                    addEntryDraft = BrewfileEntryDraft()
                }
            )
        }
        .confirmationDialog(
            pendingAction?.confirmationTitle ?? "Confirm Brewfile Action",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingAction = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingAction {
                Button(pendingAction.kind.actionLabel) {
                    viewModel.runPreparedAction(pendingAction)
                    self.pendingAction = nil
                }
            }

            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
        } message: {
            Text(pendingAction?.confirmationMessage ?? "")
        }
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search Brewfile")
        .toolbar {
            ToolbarItemGroup {
                Picker("Filter", selection: $viewModel.filterOption) {
                    ForEach(BrewfileFilterOption.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Picker("Sort", selection: $viewModel.sortOption) {
                    ForEach(BrewfileSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    viewModel.reloadBrewfile()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(viewModel.selectedFileURL == nil)
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            fileCard

            switch viewModel.documentState {
            case .idle:
                ContentUnavailableView(
                    "Choose a Brewfile",
                    systemImage: "doc.text",
                    description: Text("Pick a Brewfile to inspect its entries, comments, and any lines that need cleanup.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loading:
                ProgressView("Loading Brewfile...")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message):
                ContentUnavailableView(
                    "Brewfile Unavailable",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                List(viewModel.filteredLines, selection: selectionBinding) { line in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Label(line.title, systemImage: line.systemImageName)
                                .font(.headline)
                                .lineLimit(1)

                            Spacer()

                            Text(line.badgeText)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                        }

                        HStack {
                            Text(line.subtitle)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("L\(line.lineNumber)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(line)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(line.title), \(line.subtitle), line \(line.lineNumber)")
                }
                .listStyle(.sidebar)
                .overlay {
                    if viewModel.filteredLines.isEmpty {
                        if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ContentUnavailableView(
                                "Nothing to Show",
                                systemImage: "doc.text.magnifyingglass",
                                description: Text("This Brewfile does not currently contain any non-empty lines in the selected filter.")
                            )
                        } else {
                            ContentUnavailableView.search(text: viewModel.searchText)
                        }
                    }
                }
            }
        }
        .padding(20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspect a Brewfile and run bundle actions against it from the current Mac.")
                .foregroundStyle(.secondary)
        }
    }

    private var fileCard: some View {
        GroupBox("File") {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.selectedFileDisplayName)
                    .font(.headline)

                if let selectedFileURL = viewModel.selectedFileURL {
                    Text(selectedFileURL.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text("No Brewfile has been selected yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                CommandPreviewField(
                    title: "Dump Preview",
                    command: viewModel.dumpCommandPreview,
                    copyAccessibilityLabel: "Copy Brewfile dump command"
                )

                HStack {
                    Button("Choose Brewfile") {
                        viewModel.chooseBrewfile()
                    }
                    .keyboardShortcut("o", modifiers: [.command])

                    Button("Clear") {
                        viewModel.clearSelection()
                    }
                    .disabled(viewModel.selectedFileURL == nil)
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch viewModel.documentState {
        case .idle:
            ContentUnavailableView(
                "No Brewfile Selected",
                systemImage: "doc.text",
                description: Text("Choose a Brewfile to inspect its contents and run bundle actions against it.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed:
            ContentUnavailableView(
                "Brewfile Details Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("Pick a valid Brewfile or reload the selected file to try again.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let document):
            BrewfileLoadedDetailView(
                document: document,
                selectedLine: viewModel.selectedLine,
                checkCommand: viewModel.actionCommand(for: .check),
                installCommand: viewModel.actionCommand(for: .install),
                removeCommand: viewModel.removeCommandForSelectedEntry(),
                dumpCommandPreview: viewModel.dumpCommandPreview,
                actionState: viewModel.actionState,
                actionLogs: viewModel.actionLogs,
                onRunAction: handleAction,
                onPresentAddEntry: {
                    addEntryDraft = BrewfileEntryDraft()
                    isPresentingAddEntrySheet = true
                },
                onConfirmRemoveSelectedEntry: handleRemoveSelectedEntry,
                onCancelAction: viewModel.cancelAction,
                onClearOutput: viewModel.clearActionOutput
            )
        }
    }

    private var selectionBinding: Binding<BrewfileLine?> {
        Binding(
            get: { viewModel.selectedLine },
            set: { line in
                if let line {
                    viewModel.selectLine(id: line.id)
                }
            }
        )
    }

    private func handleAction(_ kind: BrewfileActionKind) {
        guard let command = viewModel.actionCommand(for: kind) else {
            return
        }

        if kind.requiresConfirmation {
            pendingAction = command
        } else {
            viewModel.runAction(kind)
        }
    }

    private func handleRemoveSelectedEntry() {
        guard let command = viewModel.removeCommandForSelectedEntry() else {
            return
        }

        pendingAction = command
    }
}

private struct BrewfileLoadedDetailView: View {
    let document: BrewfileDocument
    let selectedLine: BrewfileLine?
    let checkCommand: BrewfileActionCommand?
    let installCommand: BrewfileActionCommand?
    let removeCommand: BrewfileActionCommand?
    let dumpCommandPreview: String
    let actionState: BrewfileActionState
    let actionLogs: [CommandLogEntry]
    let onRunAction: (BrewfileActionKind) -> Void
    let onPresentAddEntry: () -> Void
    let onConfirmRemoveSelectedEntry: () -> Void
    let onCancelAction: () -> Void
    let onClearOutput: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleBlock
                actionCard
                metricsCard

                if let line = selectedLine {
                    BrewfileLineDetailCard(line: line)
                    BrewfileRawLineCard(line: line)
                } else {
                    ContentUnavailableView(
                        "Select a Line",
                        systemImage: "text.alignleft",
                        description: Text("Choose an entry, comment, or unknown line to inspect its details.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(document.fileURL.lastPathComponent)
                        .font(.largeTitle)
                        .bold()

                    Text(selectedLine?.subtitle ?? "Brewfile Overview")
                        .font(.headline.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let selectedLine {
                    Text("Line \(selectedLine.lineNumber)")
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())
                }
            }

            Text(document.fileURL.path)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)

            actionBlock
        }
    }

    private var actionBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(checkCommand?.kind.actionLabel ?? "Run Check") {
                    onRunAction(.check)
                }
                .buttonStyle(.borderedProminent)
                .disabled(checkCommand == nil || actionState.isRunning)

                Button(installCommand?.kind.actionLabel ?? "Install") {
                    onRunAction(.install)
                }
                .disabled(installCommand == nil || actionState.isRunning)

                Button(BrewfileActionKind.dump.actionLabel) {
                    onRunAction(.dump)
                }
                .disabled(actionState.isRunning)

                Button(BrewfileActionKind.add.actionLabel) {
                    onPresentAddEntry()
                }
                .disabled(actionState.isRunning)

                Button(BrewfileActionKind.remove.actionLabel) {
                    onConfirmRemoveSelectedEntry()
                }
                .disabled(removeCommand == nil || actionState.isRunning)

                if actionState.isRunning {
                    Button("Cancel", action: onCancelAction)
                        .keyboardShortcut(.cancelAction)
                }
            }

            if actionState != .idle {
                BrewfileActionStatusView(actionState: actionState)
            }
        }
    }

    private var actionCard: some View {
        BrewfileCard(title: "Bundle Commands") {
            VStack(alignment: .leading, spacing: 12) {
                if let checkCommand {
                    CommandPreviewField(
                        title: checkCommand.kind.subtitle,
                        command: checkCommand.command,
                        copyAccessibilityLabel: "Copy bundle check command"
                    )
                } else {
                    Text("Choose a Brewfile to run `brew bundle check --no-upgrade`.")
                        .foregroundStyle(.secondary)
                }

                if let installCommand {
                    CommandPreviewField(
                        title: installCommand.kind.subtitle,
                        command: installCommand.command,
                        copyAccessibilityLabel: "Copy bundle install command"
                    )
                }

                CommandPreviewField(
                    title: BrewfileActionKind.dump.subtitle,
                    command: dumpCommandPreview,
                    copyAccessibilityLabel: "Copy Brewfile dump command"
                )

                if actionState != .idle || !actionLogs.isEmpty {
                    CommandOutputDisclosure(
                        entries: actionLogs,
                        isRunning: actionState.isRunning,
                        emptyMessage: "Bundle details will appear here if you choose to inspect Homebrew output."
                    )
                }

                if let removeCommand {
                    Divider()

                    CommandPreviewField(
                        title: BrewfileActionKind.remove.subtitle,
                        command: removeCommand.command,
                        copyAccessibilityLabel: "Copy bundle remove command"
                    )
                }

                Button("Clear Output", action: onClearOutput)
                    .disabled(actionState == .idle && actionLogs.isEmpty)
            }
        }
    }

    private var metricsCard: some View {
        BrewfileCard(title: "Summary") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                ForEach(document.summaryMetrics) { metric in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(metric.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(metric.value)
                            .font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

}

private struct BrewfileAddEntrySheet: View {
    @Binding var draft: BrewfileEntryDraft
    let commandPreview: String?
    let onAdd: () -> Void
    let onCancel: () -> Void
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Brewfile Entry")
                .font(.title2.bold())

            Text("Use Homebrew Bundle to append a supported dependency entry to the selected Brewfile.")
                .foregroundStyle(.secondary)

            Picker("Entry Type", selection: $draft.kind) {
                ForEach(BrewfileEntryKind.addableCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }

            TextField("Entry Name", text: $draft.name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .accessibilityLabel("Entry Name")

            if let commandPreview {
                CommandPreviewField(
                    title: "Command Preview",
                    command: commandPreview,
                    copyAccessibilityLabel: "Copy bundle add command"
                )
            } else {
                Text("Enter a supported entry name to preview the Homebrew command.")
                    .foregroundStyle(.secondary)
            }

            Text("Mac App Store entries aren't included here because `brew bundle add` doesn't currently support `--mas`.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                Spacer()

                Button("Cancel", action: onCancel)

                Button("Add Entry", action: onAdd)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
            }
        }
        .padding(24)
        .frame(minWidth: 460)
        .task {
            isNameFieldFocused = true
        }
    }
}

private struct BrewfileActionStatusView: View {
    let actionState: BrewfileActionState

    var body: some View {
        switch actionState {
        case .idle:
            Text("Run a bundle check, install, or export action to work with this Brewfile on the current Mac.")
                .foregroundStyle(.secondary)
        case .running(let progress):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("\(progress.command.kind.title) has been running since \(progress.startedAt.formatted(date: .omitted, time: .standard)).")
                    .foregroundStyle(.secondary)
            }
        case .succeeded(let progress, _):
            Label(
                "\(progress.command.kind.title) completed successfully.",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        case .failed(let progress, let message):
            Label(
                CommandPresentation.friendlyFailureDescription(
                    message,
                    fallback: "\(progress.command.kind.title) couldn't complete."
                ),
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        case .cancelled(let progress):
            Label(
                "\(progress.command.kind.title) was cancelled.",
                systemImage: "xmark.circle.fill"
            )
            .foregroundStyle(.secondary)
        }
    }
}

private struct BrewfileLineDetailCard: View {
    let line: BrewfileLine

    var body: some View {
        BrewfileCard(title: "Line Details") {
            VStack(alignment: .leading, spacing: 12) {
                detailRow("Category", value: line.category.title)

                if let entry = line.entry {
                    detailRow("Kind", value: entry.kind.title)
                    detailRow("Name", value: entry.name)

                    if !entry.options.isEmpty {
                        Divider()

                        Text("Options")
                            .font(.headline)

                        ForEach(entry.options.keys.sorted(), id: \.self) { key in
                            detailRow(key, value: entry.options[key] ?? "")
                        }
                    }

                    if let inlineComment = entry.inlineComment, !inlineComment.isEmpty {
                        Divider()
                        detailRow("Inline Comment", value: inlineComment)
                    }
                } else if let commentText = line.commentText {
                    detailRow("Comment", value: commentText)
                } else {
                    Text("Hodgepodge could not confidently parse this line yet, so it is being preserved as-is.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BrewfileRawLineCard: View {
    let line: BrewfileLine

    var body: some View {
        BrewfileCard(title: "Raw Line") {
            Text(line.rawLine)
                .font(.body.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct BrewfileCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
