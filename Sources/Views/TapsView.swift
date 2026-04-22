import SwiftUI

struct TapsView: View {
    @ObservedObject var viewModel: TapsViewModel
    @State private var pendingUntapCommand: BrewTapActionCommand?

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 400, idealWidth: 480, maxWidth: 560)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            viewModel.loadIfNeeded()
        }
        .confirmationDialog(
            pendingUntapCommand?.confirmationTitle ?? "Confirm Untap",
            isPresented: Binding(
                get: { pendingUntapCommand != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingUntapCommand = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Untap", role: .destructive) {
                viewModel.untapSelectedTap()
                pendingUntapCommand = nil
            }

            Button("Cancel", role: .cancel) {
                pendingUntapCommand = nil
            }
        } message: {
            Text(pendingUntapCommand?.confirmationMessage ?? "")
        }
        .navigationTitle("Taps")
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search taps")
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    ForEach(BrewTapFilterOption.allCases) { filter in
                        Toggle(isOn: filterBinding(filter)) {
                            Text(filter.title)
                        }
                    }

                    Divider()

                    Button("Clear Filters") {
                        viewModel.clearFilters()
                    }
                    .disabled(viewModel.activeFilters.isEmpty)
                } label: {
                    Label(
                        viewModel.activeFilterCount == 0 ? "Filters" : "Filters (\(viewModel.activeFilterCount))",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                }

                Picker("Sort", selection: $viewModel.sortOption) {
                    ForEach(BrewTapSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    viewModel.refreshTaps()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            addTapCard

            switch viewModel.tapsState {
            case .idle, .loading:
                ProgressView("Loading taps...")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message):
                ContentUnavailableView(
                    "Taps Unavailable",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                List(viewModel.filteredTaps, selection: $viewModel.selectedTap) { tap in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tap.name)
                                    .font(.headline)

                                Text(tap.subtitle)
                                    .font(.subheadline.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("\(tap.packageCount)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        if !tap.statusBadges.isEmpty {
                            TapBadgeFlow(items: tap.statusBadges)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(tap)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(tap.name), \(tap.packageCount) packages")
                }
                .listStyle(.sidebar)
                .overlay {
                    if viewModel.filteredTaps.isEmpty {
                        if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ContentUnavailableView(
                                "No Taps Found",
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text("Homebrew is not currently reporting any installed taps.")
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
            Text("Inspect installed taps, add new ones, and remove taps you no longer need.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if case .loaded(let taps) = viewModel.tapsState {
                    Text("\(taps.count) taps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var addTapCard: some View {
        GroupBox("Add Tap") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Tap name (e.g. user/repo)", text: $viewModel.addTapName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Tap name")

                TextField("Optional remote URL", text: $viewModel.addTapRemoteURL)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Optional remote URL")

                HStack {
                    Text(viewModel.addTapCommand?.command ?? "brew tap user/repo")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button("Add Tap") {
                        viewModel.runAddTap()
                    }
                    .disabled(viewModel.addTapCommand == nil || viewModel.hasRunningAction)
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch viewModel.tapsState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed:
            ContentUnavailableView(
                "Tap Details Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("Refresh the installed tap inventory to try again.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            if let tap = viewModel.selectedTap {
                TapDetailView(
                    tap: tap,
                    isCurrentSnapshot: viewModel.isTapInCurrentSnapshot(tap),
                    forceUntap: $viewModel.untapForce,
                    actionState: viewModel.actionState(for: tap),
                    actionLogs: viewModel.actionLogs(for: tap),
                    onUntap: {
                        pendingUntapCommand = .untap(name: tap.name, force: viewModel.untapForce)
                    },
                    onCancelAction: viewModel.cancelAction,
                    onClearOutput: viewModel.clearActionOutput
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    "Select a Tap",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Choose an installed tap to inspect its metadata, package counts, and available actions.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func filterBinding(_ filter: BrewTapFilterOption) -> Binding<Bool> {
        Binding(
            get: { viewModel.isFilterActive(filter) },
            set: { isActive in
                if isActive != viewModel.isFilterActive(filter) {
                    viewModel.toggleFilter(filter)
                }
            }
        )
    }
}

private struct TapDetailView: View {
    let tap: BrewTap
    let isCurrentSnapshot: Bool
    @Binding var forceUntap: Bool
    let actionState: BrewTapActionState
    let actionLogs: [CommandLogEntry]
    let onUntap: () -> Void
    let onCancelAction: () -> Void
    let onClearOutput: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleBlock
                metricsCard
                metadataCard
                packagePreviewCard
                actionCard
                outputCard
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
                    Text(tap.name)
                        .font(.largeTitle)
                        .bold()

                    Text(tap.subtitle)
                        .font(.headline.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }

                Spacer()

                Text("\(tap.packageCount) packages")
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }

            if !tap.statusBadges.isEmpty {
                TapTagFlow(items: tap.statusBadges)
            }

            if !isCurrentSnapshot {
                Label(
                    "This tap is no longer in the latest snapshot. The detail pane is keeping the last selection visible so you can review the action output.",
                    systemImage: "checkmark.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var metricsCard: some View {
        TapCard(title: "Inventory") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                ForEach(tap.summaryMetrics) { metric in
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

    private var metadataCard: some View {
        TapCard(title: "Metadata") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                ForEach(tap.detailRows) { row in
                    GridRow {
                        Text(row.title)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(row.value ?? "Unavailable")
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var packagePreviewCard: some View {
        TapCard(title: "Package Preview") {
            VStack(alignment: .leading, spacing: 14) {
                previewBlock("Formulae", items: tap.formulaNames)
                previewBlock("Casks", items: tap.caskTokens)
            }
        }
    }

    private var actionCard: some View {
        TapCard(title: "Actions") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Untap removes this repository from your local Homebrew installation. Use force only if packages from this tap are still installed.")
                    .foregroundStyle(.secondary)

                Toggle("Force untap", isOn: $forceUntap)

                HStack(spacing: 12) {
                    Button("Untap") {
                        onUntap()
                    }
                    .disabled(actionState.isRunning)

                    if actionState.isRunning {
                        Button("Cancel Action") {
                            onCancelAction()
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                }
            }
        }
    }

    private var outputCard: some View {
        TapCard(title: "Action Output") {
            VStack(alignment: .leading, spacing: 12) {
                if let progress = actionState.progress {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(statusTitle)
                                .font(.headline)
                            Spacer()
                            Text("Elapsed \(progress.elapsedTime(), format: .number.precision(.fractionLength(1)))s")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        Text(progress.command.command)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                    }
                } else {
                    Text("Add or untap a repository to stream Homebrew output here.")
                        .foregroundStyle(.secondary)
                }

                ScrollView {
                    Text(renderedLogs)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
                .frame(minHeight: 180, alignment: .topLeading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack {
                    Spacer()

                    Button("Clear Output") {
                        onClearOutput()
                    }
                    .disabled(actionLogs.isEmpty && actionState == .idle)
                }
            }
        }
    }

    private func previewBlock(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if items.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(items.prefix(6).enumerated()), id: \.offset) { _, item in
                    Text(item)
                        .font(.callout.monospaced())
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var renderedLogs: String {
        if actionLogs.isEmpty {
            return "No command output yet."
        }

        return actionLogs.map { entry in
            "[\(entry.timestamp.formatted(date: .omitted, time: .shortened))] \(entry.kind.rawValue.uppercased())  \(entry.text)"
        }
        .joined(separator: "\n")
    }

    private var statusTitle: String {
        switch actionState {
        case .idle:
            "Idle"
        case .running:
            "Running"
        case .succeeded:
            "Completed"
        case .failed:
            "Failed"
        case .cancelled:
            "Cancelled"
        }
    }
}

private struct TapCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3)
                .bold()

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
        )
    }
}

private struct TapTagFlow: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                    .textSelection(.enabled)
            }
        }
    }
}

private struct TapBadgeFlow: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
