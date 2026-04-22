import SwiftUI

struct InstalledPackagesView: View {
    @ObservedObject var viewModel: InstalledPackagesViewModel
    @State private var pendingAction: InstalledPackageActionCommand?

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 420, idealWidth: 520, maxWidth: .infinity)

            detail
                .frame(minWidth: 500, idealWidth: 780, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            viewModel.loadIfNeeded()
        }
        .confirmationDialog(
            pendingAction?.confirmationTitle ?? "",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingAction = nil
                    }
                }
            ),
            presenting: pendingAction
        ) { action in
            Button(action.kind.title) {
                let package = if case .loaded(let packages) = viewModel.packagesState {
                    packages.first(where: { $0.id == action.packageID }) ?? viewModel.selectedPackage
                } else {
                    viewModel.selectedPackage
                }

                if let package {
                    viewModel.runAction(action.kind, for: package)
                }
                pendingAction = nil
            }

            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
        } message: { action in
            Text(action.confirmationMessage)
        }
        .navigationTitle("Installed")
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search installed packages")
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    ForEach(InstalledPackageFilterOption.allCases) { filter in
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
                    ForEach(InstalledPackageSortOption.allCases) { option in
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
            exportCard

            switch viewModel.packagesState {
            case .idle, .loading:
                ProgressView("Loading installed packages...")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message):
                ContentUnavailableView(
                    "Installed Packages Unavailable",
                    systemImage: "shippingbox.circle",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                ScrollViewReader { proxy in
                    List(viewModel.filteredPackages, selection: $viewModel.selectedPackage) { package in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(package.title)
                                            .font(.headline)

                                        if viewModel.isFavorite(package) {
                                            Image(systemName: "star.fill")
                                                .font(.caption)
                                                .foregroundStyle(.yellow)
                                        }
                                    }

                                    Text(package.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Text(package.kind.title.dropLast())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text(package.version)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.tertiary)

                                Spacer()

                                if let installedAt = package.installedAt {
                                    Text(installedAt, format: .relative(presentation: .numeric))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            if !package.statusBadges.isEmpty {
                                InstalledPackageBadgeFlow(items: package.statusBadges)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(package)
                        .id(package.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(package.title), \(package.kind.title.dropLast()), version \(package.version)")
                    }
                    .listStyle(.sidebar)
                    .overlay {
                        if viewModel.filteredPackages.isEmpty {
                            ContentUnavailableView.search(text: viewModel.searchText)
                        }
                    }
                    .task(id: viewModel.selectedPackage?.id) {
                        scrollSelectionIntoView(using: proxy)
                    }
                    .task(id: viewModel.filteredPackages.map(\.id)) {
                        scrollSelectionIntoView(using: proxy)
                    }
                }
            }
        }
        .padding(20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspect what is currently installed on this Mac through Homebrew.")
                .foregroundStyle(.secondary)

            Picker("Package Scope", selection: $viewModel.scope) {
                ForEach(CatalogScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if !viewModel.stateCounts.isEmpty {
                InstalledPackageStateSummary(counts: viewModel.stateCounts)
            }

            HStack(spacing: 12) {
                if case .loaded(let packages) = viewModel.packagesState {
                    Text("\(packages.count) packages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var exportCard: some View {
        GroupBox("Generate Brewfile") {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.exportDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                CommandPreviewField(
                    title: "Export Command",
                    command: viewModel.exportCommandPreview,
                    copyAccessibilityLabel: "Copy Brewfile export command"
                )

                InstalledPackagesExportStatusView(exportState: viewModel.exportState)

                HStack(spacing: 12) {
                    Button("Generate Brewfile") {
                        viewModel.generateBrewfile()
                    }
                    .disabled(viewModel.hasRunningExport)

                    if viewModel.hasRunningExport {
                        Button("Cancel", action: viewModel.cancelExport)
                    } else {
                        Button("Clear Output", action: viewModel.clearExportOutput)
                            .disabled(viewModel.exportState == .idle && viewModel.exportLogs.isEmpty)
                    }
                }

                if viewModel.exportState != .idle || !viewModel.exportLogs.isEmpty {
                    CommandOutputDisclosure(
                        entries: viewModel.exportLogs,
                        isRunning: viewModel.hasRunningExport,
                        emptyMessage: "Export details will appear here if you choose to inspect Homebrew output."
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
                "Installed Package Details Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("Refresh the installed package inventory to try again.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            if let package = viewModel.selectedPackage {
                InstalledPackageDetailView(
                    package: package,
                    isFavorite: viewModel.isFavorite(package),
                    isCurrentSnapshot: viewModel.isPackageInCurrentSnapshot(package),
                    actionState: viewModel.actionState(for: package),
                    actionLogs: viewModel.actionLogs(for: package),
                    onToggleFavorite: {
                        viewModel.toggleFavorite(package)
                    },
                    onRunAction: handleAction(_:for:),
                    onCancelAction: viewModel.cancelAction,
                    onClearOutput: viewModel.clearActionOutput,
                    dependencySnapshot: viewModel.dependencySnapshot(for: package),
                    onSelectPackage: viewModel.selectPackage(id:)
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    "Select a Package",
                    systemImage: "shippingbox",
                    description: Text("Choose an installed formula or cask to inspect its local state.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func filterBinding(_ filter: InstalledPackageFilterOption) -> Binding<Bool> {
        Binding(
            get: { viewModel.isFilterActive(filter) },
            set: { isActive in
                if isActive != viewModel.isFilterActive(filter) {
                    viewModel.toggleFilter(filter)
                }
            }
        )
    }

    private func handleAction(_ action: InstalledPackageActionKind, for package: InstalledPackage) {
        if action.requiresConfirmation {
            pendingAction = package.actionCommand(for: action)
        } else {
            viewModel.runAction(action, for: package)
        }
    }

    private func scrollSelectionIntoView(using proxy: ScrollViewProxy) {
        guard let selectedID = viewModel.selectedPackage?.id,
              viewModel.filteredPackages.contains(where: { $0.id == selectedID }) else {
            return
        }

        Task { @MainActor in
            proxy.scrollTo(selectedID, anchor: .center)
        }
    }
}

private struct InstalledPackagesExportStatusView: View {
    let exportState: InstalledPackagesBrewfileExportState

    var body: some View {
        switch exportState {
        case .idle:
            Text("Use Homebrew's `bundle dump` command to export the currently selected Installed scope.")
                .foregroundStyle(.secondary)
        case .running(let progress):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Generating since \(progress.startedAt.formatted(date: .omitted, time: .standard))")
                    .foregroundStyle(.secondary)
            }
        case .succeeded:
            Label(
                "Brewfile generated successfully.",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        case .failed(_, let message):
            Label(
                CommandPresentation.friendlyFailureDescription(
                    message,
                    fallback: "Brewfile generation couldn't complete."
                ),
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        case .cancelled:
            Label(
                "Brewfile generation was cancelled.",
                systemImage: "xmark.circle.fill"
            )
            .foregroundStyle(.secondary)
        }
    }
}

private struct InstalledPackageDetailView: View {
    let package: InstalledPackage
    let isFavorite: Bool
    let isCurrentSnapshot: Bool
    let actionState: InstalledPackageActionState
    let actionLogs: [CommandLogEntry]
    let onToggleFavorite: () -> Void
    let onRunAction: (InstalledPackageActionKind, InstalledPackage) -> Void
    let onCancelAction: () -> Void
    let onClearOutput: () -> Void
    let dependencySnapshot: InstalledPackageDependencySnapshot?
    let onSelectPackage: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleBlock
                metadataCard
                packageStateCard
                packageActionsCard
                actionOutputCard

                if let dependencySnapshot {
                    dependencySummaryCard(snapshot: dependencySnapshot)

                    ForEach(dependencySnapshot.dependencyGroups) { group in
                        InstalledPackageCard(title: group.title) {
                            InstalledPackageTagFlow(items: group.items)
                        }
                    }

                    if dependencySnapshot.hasDependencyTree {
                        dependencyTreeCard(snapshot: dependencySnapshot)
                    }

                    if dependencySnapshot.hasDependentTree {
                        dependentTreeCard(snapshot: dependencySnapshot)
                    }
                }

                if !package.installedVersions.isEmpty {
                    installedVersionsCard
                }

                if !package.runtimeDependencies.isEmpty {
                    InstalledPackageCard(title: "Runtime Dependencies") {
                        InstalledPackageTagFlow(items: package.runtimeDependencies)
                    }
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
                    HStack(alignment: .center, spacing: 8) {
                        Text(package.title)
                            .font(.largeTitle)
                            .bold()

                        if let homepage = package.homepage {
                            HomepageLinkIcon(
                                url: homepage,
                                accessibilityLabel: "Open package homepage"
                            )
                        }
                    }

                    if package.fullName != package.title {
                        Text(package.fullName)
                            .font(.headline.monospaced())
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }

                    Text(package.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Button(action: onToggleFavorite) {
                        Label(
                            isFavorite ? "Favorite" : "Add Favorite",
                            systemImage: isFavorite ? "star.fill" : "star"
                        )
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                    .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                    .buttonStyle(.borderless)

                    Text(package.kind.title.dropLast())
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())

                    Text(package.version)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var metadataCard: some View {
        InstalledPackageCard(title: "Metadata") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                metadataRow("Slug", package.slug)
                metadataRow("Tap", package.tap)
                metadataRow("Installed Version", package.version)

                if let linkedVersion = package.linkedVersion, !linkedVersion.isEmpty {
                    metadataRow("Linked Keg", linkedVersion)
                }

                if let installedAt = package.installedAt {
                    metadataRow("Installed At", installedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
    }

    private var packageStateCard: some View {
        InstalledPackageCard(title: "Package State") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                ForEach(package.packageStateRows, id: \.title) { row in
                    metadataRow(row.title, row.value)
                }
            }
        }
    }

    private var packageActionsCard: some View {
        InstalledPackageCard(title: "Package Actions") {
            VStack(alignment: .leading, spacing: 16) {
                Text(package.actionDescription)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 12) {
                    ForEach(package.availableActionKinds) { action in
                        actionButton(for: action)
                    }
                }

                InstalledPackageActionStatusView(actionState: actionState)
            }
        }
    }

    private func dependencySummaryCard(snapshot: InstalledPackageDependencySnapshot) -> some View {
        InstalledPackageCard(title: "Dependency Summary") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(snapshot.summaryMetrics) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(metric.value)
                            .font(.title2.monospacedDigit())
                            .bold()

                        Text(metric.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
            }
        }
    }

    private func dependencyTreeCard(snapshot: InstalledPackageDependencySnapshot) -> some View {
        InstalledPackageCard(title: "Dependency Tree") {
            InstalledPackageTreeView(
                rows: snapshot.dependencyTree,
                onSelectPackage: onSelectPackage
            )
        }
    }

    private func dependentTreeCard(snapshot: InstalledPackageDependencySnapshot) -> some View {
        InstalledPackageCard(title: "Dependents") {
            InstalledPackageTreeView(
                rows: snapshot.dependentTree,
                onSelectPackage: onSelectPackage
            )
        }
    }

    private var installedVersionsCard: some View {
        InstalledPackageCard(title: "Installed Versions") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(package.installedVersions, id: \.self) { version in
                    Text(version)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var actionOutputCard: some View {
        if actionState != .idle || !actionLogs.isEmpty {
            InstalledPackageCard(title: "Action Output") {
                VStack(alignment: .leading, spacing: 12) {
                if actionState.isRunning {
                    Button("Cancel", action: onCancelAction)
                } else {
                    Button("Clear Output", action: onClearOutput)
                }

                CommandOutputDisclosure(
                    entries: actionLogs,
                    isRunning: actionState.isRunning,
                    emptyMessage: "Action details will appear here if you choose to inspect Homebrew output."
                )
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

    @ViewBuilder
    private func actionButton(for action: InstalledPackageActionKind) -> some View {
        if action.requiresConfirmation {
            Button(action.title) {
                onRunAction(action, package)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("\(action.title) \(package.title)")
        } else {
            Button(action.title) {
                onRunAction(action, package)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("\(action.title) \(package.title)")
        }
    }

}

private struct InstalledPackageActionStatusView: View {
    let actionState: InstalledPackageActionState

    var body: some View {
        switch actionState {
        case .idle:
            Text("Run package management actions here using your local Homebrew installation.")
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
                "The package action completed successfully.",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        case .failed(_, let message):
            Label(
                CommandPresentation.friendlyFailureDescription(
                    message,
                    fallback: "Homebrew couldn't complete this package action."
                ),
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        case .cancelled:
            Label(
                "The package action was cancelled.",
                systemImage: "xmark.circle.fill"
            )
            .foregroundStyle(.secondary)
        }
    }
}

private struct InstalledPackageStateSummary: View {
    let counts: [InstalledPackageStateCount]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
            ForEach(counts) { count in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(count.count)")
                        .font(.title2.monospacedDigit())
                        .bold()

                    Text(count.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Package state summary")
    }
}

private struct InstalledPackageTreeView: View {
    let rows: [InstalledPackageTreeRow]
    let onSelectPackage: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows) { row in
                Button {
                    onSelectPackage(row.packageID)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Color.clear
                            .frame(width: CGFloat(row.depth) * 18, height: 1)

                        Image(systemName: row.depth == 0 ? "arrow.turn.down.right" : "arrow.turn.right.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(row.title)
                            .font(.body.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("Open installed package \(row.title)")
                .help("Open \(row.title)")
            }
        }
    }
}

private struct InstalledPackageCard<Content: View>: View {
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

private struct InstalledPackageTagFlow: View {
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

private struct InstalledPackageBadgeFlow: View {
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
