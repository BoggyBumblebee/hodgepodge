import SwiftUI

struct ServicesView: View {
    @ObservedObject var viewModel: ServicesViewModel
    @State private var pendingAction: BrewServiceActionCommand?

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 400, idealWidth: 480, maxWidth: 540)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            viewModel.loadIfNeeded()
        }
        .confirmationDialog(
            pendingAction?.confirmationTitle ?? "Confirm Service Action",
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
                Button(
                    pendingAction.kind.title,
                    role: pendingAction.kind == .stop || pendingAction.kind == .kill ? .destructive : nil
                ) {
                    viewModel.runActionCommand(pendingAction)
                    self.pendingAction = nil
                }
            }

            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
        } message: {
            Text(pendingAction?.confirmationMessage ?? "")
        }
        .navigationTitle("Services")
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search services")
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    ForEach(BrewServiceFilterOption.allCases) { filter in
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
                    ForEach(BrewServiceSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    viewModel.refreshServices()
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
            cleanupCard

            switch viewModel.servicesState {
            case .idle, .loading:
                ProgressView("Loading services...")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message):
                ContentUnavailableView(
                    "Services Unavailable",
                    systemImage: "bolt.horizontal.circle",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                List(viewModel.filteredServices, selection: $viewModel.selectedService) { service in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(service.title)
                                    .font(.headline)

                                Text(service.subtitle)
                                    .font(.subheadline.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(service.statusTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text(service.user ?? "System")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Spacer()

                            Text(service.pid.map { "PID \($0)" } ?? "Not Running")
                                .font(.caption.monospaced())
                                .foregroundStyle(.tertiary)
                        }

                        if !service.statusBadges.isEmpty {
                            BrewServiceBadgeFlow(items: service.statusBadges)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(service)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(service.title), status \(service.statusTitle), \(service.pid.map { "pid \($0)" } ?? "not running")"
                    )
                }
                .listStyle(.sidebar)
                .overlay {
                    if viewModel.filteredServices.isEmpty {
                        if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ContentUnavailableView(
                                "No Services Found",
                                systemImage: "bolt.horizontal.circle",
                                description: Text("Homebrew is not currently reporting any managed services.")
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
            Text("Inspect and manage Homebrew background services on this Mac.")
                .foregroundStyle(.secondary)

            if !viewModel.stateCounts.isEmpty {
                BrewServiceStateSummary(counts: viewModel.stateCounts)
            }

            HStack(spacing: 12) {
                if case .loaded(let services) = viewModel.servicesState {
                    Text("\(services.count) services")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var cleanupCard: some View {
        GroupBox("Cleanup") {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.cleanupDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                CommandPreviewField(
                    title: "Cleanup Command",
                    command: viewModel.cleanupCommand.command,
                    copyAccessibilityLabel: "Copy services cleanup command"
                )

                BrewServiceCleanupStatusView(actionState: viewModel.cleanupState)

                HStack(spacing: 12) {
                    Button("Run Cleanup") {
                        pendingAction = viewModel.cleanupCommand
                    }
                    .disabled(viewModel.hasRunningAction)

                    if viewModel.cleanupState.isRunning {
                        Button("Cancel", action: viewModel.cancelAction)
                    } else {
                        Button("Clear Output", action: viewModel.clearActionOutput)
                            .disabled(viewModel.cleanupState == .idle && viewModel.cleanupLogs.isEmpty)
                    }
                }

                if viewModel.cleanupState != .idle || !viewModel.cleanupLogs.isEmpty {
                    CommandOutputDisclosure(
                        entries: viewModel.cleanupLogs,
                        isRunning: viewModel.cleanupState.isRunning,
                        emptyMessage: "Cleanup details will appear here if you choose to inspect Homebrew output."
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch viewModel.servicesState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed:
            ContentUnavailableView(
                "Service Details Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("Refresh the Homebrew service list to try again.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            if let service = viewModel.selectedService {
                BrewServiceDetailView(
                    service: service,
                    hasRunningAction: viewModel.hasRunningAction,
                    actionState: viewModel.actionState(for: service),
                    actionLogs: viewModel.actionLogs(for: service),
                    onRunAction: handleAction(_:for:),
                    onCancelAction: viewModel.cancelAction,
                    onClearOutput: viewModel.clearActionOutput
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    "Select a Service",
                    systemImage: "bolt.horizontal.circle",
                    description: Text("Choose a Homebrew service to inspect its status, logs, and available actions.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func filterBinding(_ filter: BrewServiceFilterOption) -> Binding<Bool> {
        Binding(
            get: { viewModel.isFilterActive(filter) },
            set: { isActive in
                if isActive != viewModel.isFilterActive(filter) {
                    viewModel.toggleFilter(filter)
                }
            }
        )
    }

    private func handleAction(_ action: BrewServiceActionKind, for service: BrewService) {
        if action.requiresConfirmation {
            pendingAction = service.command(for: action)
        } else {
            viewModel.runAction(action, for: service)
        }
    }
}

private struct BrewServiceCleanupStatusView: View {
    let actionState: BrewServiceActionState

    var body: some View {
        switch actionState {
        case .idle:
            Text("Remove stale Homebrew service registrations that are no longer in use.")
                .foregroundStyle(.secondary)
        case .running(let progress):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("\(progress.command.kind.title) started at \(progress.startedAt.formatted(date: .omitted, time: .standard))")
                    .foregroundStyle(.secondary)
            }
        case .succeeded:
            Label(
                "Service cleanup completed successfully.",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        case .failed(_, let message):
            Label(
                CommandPresentation.friendlyFailureDescription(
                    message,
                    fallback: "Homebrew couldn't complete services cleanup."
                ),
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        case .cancelled:
            Label(
                "Services cleanup was cancelled.",
                systemImage: "xmark.circle.fill"
            )
            .foregroundStyle(.secondary)
        }
    }
}

private struct BrewServiceDetailView: View {
    let service: BrewService
    let hasRunningAction: Bool
    let actionState: BrewServiceActionState
    let actionLogs: [CommandLogEntry]
    let onRunAction: (BrewServiceActionKind, BrewService) -> Void
    let onCancelAction: () -> Void
    let onClearOutput: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleBlock
                metadataCard
                locationsCard
                if let command = service.command {
                    commandCard(command)
                }
                actionCard
                if !actionLogs.isEmpty || actionState != .idle {
                    actionLogCard
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
                    Text(service.title)
                        .font(.largeTitle)
                        .bold()

                    Text(service.subtitle)
                        .font(.headline.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(service.statusTitle)
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())

                    Text(service.pid.map { "PID \($0)" } ?? "Not Running")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            if !service.statusBadges.isEmpty {
                BrewServiceTagFlow(items: service.statusBadges)
            }
        }
    }

    private var metadataCard: some View {
        BrewServiceCard(title: "Status") {
            BrewServiceDetailGrid(rows: service.summaryRows)
        }
    }

    private var locationsCard: some View {
        BrewServiceCard(title: "Locations") {
            BrewServiceDetailGrid(rows: service.locationRows + service.scheduleRows)
        }
    }

    private func commandCard(_ command: String) -> some View {
        BrewServiceCard(title: "Command") {
            CommandPreviewField(
                command: command,
                copyAccessibilityLabel: "Copy service command"
            )
        }
    }

    private var actionCard: some View {
        BrewServiceCard(title: "Actions") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(service.availableActions) { action in
                        Button(action.title) {
                            onRunAction(action, service)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(hasRunningAction)
                    }

                    if actionState.isRunning {
                        Button("Cancel", role: .destructive) {
                            onCancelAction()
                        }
                    }

                    if !actionLogs.isEmpty || actionState != .idle {
                        Button("Clear Output") {
                            onClearOutput()
                        }
                        .disabled(actionState.isRunning)
                    }
                }

                Text(actionSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionLogCard: some View {
        BrewServiceCard(title: "Action Details") {
            CommandOutputDisclosure(
                entries: actionLogs,
                isRunning: actionState.isRunning,
                emptyMessage: "Service details will appear here if you choose to inspect Homebrew output."
            )
        }
    }

    private var actionSummary: String {
        switch actionState {
        case .idle:
            "Use these controls to start, stop, or restart the selected Homebrew service."
        case .running(let progress):
            "\(progress.command.kind.title) is running. Elapsed \(progress.elapsedTime().formatted(.number.precision(.fractionLength(1))))s."
        case .succeeded(let progress, _):
            "\(progress.command.kind.title) completed successfully."
        case .failed(_, let message):
            CommandPresentation.friendlyFailureDescription(
                message,
                fallback: "The service action couldn't complete."
            )
        case .cancelled:
            "The service action was cancelled."
        }
    }
}

private struct BrewServiceStateSummary: View {
    let counts: [BrewServiceStateCount]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(counts) { count in
                VStack(alignment: .leading, spacing: 2) {
                    Text(count.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(count.count)")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private struct BrewServiceDetailGrid: View {
    let rows: [BrewServiceDetailRow]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 240), alignment: .topLeading)
            ],
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(row.value)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct BrewServiceCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .bold()

            content
        }
        .padding(18)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct BrewServiceBadgeFlow: View {
    let items: [String]

    var body: some View {
        BrewServiceTagFlow(items: items)
    }
}

private struct BrewServiceTagFlow: View {
    let items: [String]

    var body: some View {
        FlowLayout(items, spacing: 8) { item in
            Text(item)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
    }
}

private struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content

    init(_ items: Data, spacing: CGFloat, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: spacing) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: spacing, alignment: .leading)], alignment: .leading, spacing: spacing) {
                    ForEach(Array(items), id: \.self) { item in
                        content(item)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}
