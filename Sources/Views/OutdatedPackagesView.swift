import SwiftUI

struct OutdatedPackagesView: View {
    @ObservedObject var viewModel: OutdatedPackagesViewModel
    @State private var pendingAction: OutdatedPackageActionCommand?

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity)

            detail
                .frame(minWidth: 500, idealWidth: 760, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            viewModel.loadIfNeeded()
        }
        .confirmationDialog(
            pendingAction?.confirmationTitle ?? "Confirm Upgrade",
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
                Button(pendingAction.kind.title) {
                    if pendingAction.isBulkAction {
                        viewModel.runUpgradeAll()
                    } else if let package = viewModel.selectedPackage,
                              package.id == pendingAction.packageID {
                        viewModel.runAction(pendingAction.kind, for: package)
                    }
                    self.pendingAction = nil
                }
            }

            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
        } message: {
            Text(pendingAction?.confirmationMessage ?? "")
        }
        .navigationTitle("Outdated")
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search outdated packages")
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    ForEach(OutdatedPackageFilterOption.allCases) { filter in
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
                    ForEach(OutdatedPackageSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    viewModel.refreshPackages()
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

            switch viewModel.packagesState {
            case .idle, .loading:
                ProgressView("Loading outdated packages...")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message):
                ContentUnavailableView(
                    "Outdated Packages Unavailable",
                    systemImage: "arrow.triangle.2.circlepath.circle",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                upgradeAllCard

                List(viewModel.filteredPackages, selection: $viewModel.selectedPackage) { package in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(package.title)
                                    .font(.headline)

                                Text(package.fullName)
                                    .font(.subheadline.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(package.kind.title.dropLast())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Text(package.primaryInstalledVersion)
                                .font(.caption.monospaced())
                                .foregroundStyle(.tertiary)

                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)

                            Text(package.currentVersion)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        if !package.statusBadges.isEmpty {
                            OutdatedPackageBadgeFlow(items: package.statusBadges)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(package)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(package.title), \(package.kind.title.dropLast()), installed \(package.primaryInstalledVersion), current \(package.currentVersion)"
                    )
                }
                .listStyle(.sidebar)
                .overlay {
                    if viewModel.filteredPackages.isEmpty {
                        if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ContentUnavailableView(
                                "Everything Is Up to Date",
                                systemImage: "checkmark.circle",
                                description: Text("Homebrew is not reporting any outdated formulae or casks right now.")
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
            Text("Review upgrade candidates from this Mac’s Homebrew installation before taking action.")
                .foregroundStyle(.secondary)

            Picker("Package Scope", selection: $viewModel.scope) {
                ForEach(CatalogScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                if case .loaded(let packages) = viewModel.packagesState {
                    Text("\(packages.count) packages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var upgradeAllCard: some View {
        GroupBox("Upgrade All") {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.upgradeAllDescription)
                    .foregroundStyle(.secondary)

                if let command = viewModel.upgradeAllCommand {
                    CommandPreviewField(
                        title: "Upgrade Command",
                        command: command.command,
                        copyAccessibilityLabel: "Copy bulk upgrade command"
                    )
                } else {
                    Text("No upgrade command is available for the current view.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                OutdatedUpgradeAllStatusView(actionState: viewModel.upgradeAllState)

                HStack(spacing: 12) {
                    Button("Upgrade All") {
                        pendingAction = viewModel.upgradeAllCommand
                    }
                    .disabled(viewModel.upgradeAllCommand == nil || viewModel.hasRunningAction)
                    .keyboardShortcut("u", modifiers: [.command, .shift])

                    if viewModel.upgradeAllState.isRunning {
                        Button("Cancel Upgrade") {
                            viewModel.cancelAction()
                        }
                        .keyboardShortcut(.cancelAction)
                    } else {
                        Button("Clear Output") {
                            viewModel.clearActionOutput()
                        }
                        .disabled(viewModel.upgradeAllLogs.isEmpty && viewModel.upgradeAllState == .idle)
                    }
                }

                if viewModel.upgradeAllState != .idle || !viewModel.upgradeAllLogs.isEmpty {
                    CommandOutputDisclosure(
                        entries: viewModel.upgradeAllLogs,
                        isRunning: viewModel.upgradeAllState.isRunning,
                        emptyMessage: "Upgrade details will appear here if you choose to inspect Homebrew output."
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch viewModel.packagesState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed:
            ContentUnavailableView(
                "Outdated Package Details Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("Refresh the outdated package inventory to try again.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            if let package = viewModel.selectedPackage {
                OutdatedPackageDetailView(
                    package: package,
                    isCurrentSnapshot: viewModel.isPackageInCurrentSnapshot(package),
                    actionState: viewModel.actionState(for: package),
                    actionLogs: viewModel.actionLogs(for: package),
                    onRunAction: handleAction(_:for:),
                    onCancelAction: viewModel.cancelAction,
                    onClearOutput: viewModel.clearActionOutput
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    "Select a Package",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("Choose an outdated formula or cask to inspect the upgrade candidate.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func handleAction(_ action: OutdatedPackageActionKind, for package: OutdatedPackage) {
        if action.requiresConfirmation {
            pendingAction = package.actionCommand(for: action)
        } else {
            viewModel.runAction(action, for: package)
        }
    }

    private func filterBinding(_ filter: OutdatedPackageFilterOption) -> Binding<Bool> {
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

private struct OutdatedUpgradeAllStatusView: View {
    let actionState: OutdatedPackageActionState

    var body: some View {
        switch actionState {
        case .idle:
            Text("Upgrade all visible outdated packages from this view in one action.")
                .foregroundStyle(.secondary)
        case .running(let progress):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Upgrading \(progress.command.packageCount) package\(progress.command.packageCount == 1 ? "" : "s") since \(progress.startedAt.formatted(date: .omitted, time: .standard))")
                    .foregroundStyle(.secondary)
            }
        case .succeeded:
            Label(
                "All selected packages were upgraded successfully.",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        case .failed(_, let message):
            Label(
                CommandPresentation.friendlyFailureDescription(
                    message,
                    fallback: "Homebrew couldn't complete the bulk upgrade."
                ),
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        case .cancelled:
            Label(
                "The bulk upgrade was cancelled.",
                systemImage: "xmark.circle.fill"
            )
            .foregroundStyle(.secondary)
        }
    }
}

private struct OutdatedPackageDetailView: View {
    let package: OutdatedPackage
    let isCurrentSnapshot: Bool
    let actionState: OutdatedPackageActionState
    let actionLogs: [CommandLogEntry]
    let onRunAction: (OutdatedPackageActionKind, OutdatedPackage) -> Void
    let onCancelAction: () -> Void
    let onClearOutput: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleBlock
                versionCard
                if actionState.command != nil || !actionLogs.isEmpty {
                    actionLogBlock
                }
                upgradeGuidanceCard
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
                    Text(package.title)
                        .font(.largeTitle)
                        .bold()

                    Text(package.fullName)
                        .font(.headline.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(package.kind.title.dropLast())
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())

                    Text(package.currentVersion)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            if !package.statusBadges.isEmpty {
                OutdatedPackageTagFlow(items: package.statusBadges)
            }

            if !isCurrentSnapshot {
                Label(
                    "The latest refresh no longer reports this package as outdated. The detail pane is keeping the last selection visible so you can review the action output.",
                    systemImage: "checkmark.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            actionBlock
        }
    }

    private var versionCard: some View {
        OutdatedPackageCard(title: "Version Delta") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                metadataRow("Installed", package.installedVersionSummary)
                metadataRow("Current", package.currentVersion)

                if let pinnedVersion = package.pinnedVersion, !pinnedVersion.isEmpty {
                    metadataRow("Pinned At", pinnedVersion)
                }
            }
        }
    }

    private var actionBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button("Upgrade Now") {
                    onRunAction(.upgrade, package)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!package.isUpgradeAvailable || actionState.isRunning)
                .keyboardShortcut("u", modifiers: [.command, .option])

                if actionState.isRunning {
                    Button("Cancel", action: onCancelAction)
                        .keyboardShortcut(.cancelAction)
                }
            }

            if actionState != .idle {
                OutdatedPackageActionStatusView(actionState: actionState)
            }
        }
    }

    private var upgradeGuidanceCard: some View {
        OutdatedPackageCard(title: "Upgrade Guidance") {
            VStack(alignment: .leading, spacing: 12) {
                CommandPreviewField(
                    title: "Upgrade Command",
                    command: package.upgradeCommand,
                    copyAccessibilityLabel: "Copy upgrade command"
                )

                if let blockedReason = package.upgradeBlockedReason {
                    Label(blockedReason, systemImage: "pin")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var actionLogBlock: some View {
        OutdatedPackageCard(title: "Upgrade Output") {
            VStack(alignment: .leading, spacing: 12) {
                if let progress = actionState.progress {
                    CommandPreviewField(
                        title: "Executed Command",
                        command: progress.command.command,
                        copyAccessibilityLabel: "Copy executed upgrade command"
                    )
                }

                CommandOutputDisclosure(
                    entries: actionLogs,
                    isRunning: actionState.isRunning,
                    emptyMessage: "Upgrade details will appear here if you choose to inspect Homebrew output."
                )

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

    private func metadataRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

private struct OutdatedPackageActionStatusView: View {
    let actionState: OutdatedPackageActionState

    var body: some View {
        switch actionState {
        case .idle:
            EmptyView()
        case .running(let progress):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("\(progress.command.kind.title) started at \(progress.startedAt.formatted(date: .omitted, time: .standard))")
                    .foregroundStyle(.secondary)
            }
        case .succeeded:
            Label(
                "The upgrade completed successfully.",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        case .failed(_, let message):
            Label(
                CommandPresentation.friendlyFailureDescription(
                    message,
                    fallback: "Homebrew couldn't complete this upgrade."
                ),
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        case .cancelled:
            Label(
                "The upgrade was cancelled.",
                systemImage: "xmark.circle.fill"
            )
            .foregroundStyle(.secondary)
        }
    }
}

private struct OutdatedPackageCard<Content: View>: View {
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

private struct OutdatedPackageTagFlow: View {
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

private struct OutdatedPackageBadgeFlow: View {
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
