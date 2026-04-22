import AppKit
import SwiftUI

struct CatalogView: View {
    @ObservedObject var viewModel: CatalogViewModel
    @State private var isPresentingSaveSearch = false
    @State private var savedSearchName = ""

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 420, idealWidth: 510, maxWidth: 560)

            detail
                .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            viewModel.loadCatalogIfNeeded()
        }
        .sheet(isPresented: $isPresentingSaveSearch) {
            CatalogSavedSearchSheet(
                name: $savedSearchName,
                onSave: {
                    viewModel.saveCurrentSearch(named: savedSearchName)
                    savedSearchName = ""
                    isPresentingSaveSearch = false
                },
                onCancel: {
                    savedSearchName = ""
                    isPresentingSaveSearch = false
                }
            )
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            savedSearchesCard

            switch viewModel.packagesState {
            case .idle, .loading:
                ProgressView("Loading package catalog...")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            case .failed(let message):
                ContentUnavailableView(
                    "Catalog Unavailable",
                    systemImage: "network.slash",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                List(viewModel.filteredPackages, selection: selectionBinding) { package in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(package.title)
                                .font(.headline)

                            if viewModel.isFavorite(package) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }

                            Spacer()
                            Text(package.kind.title.dropLast())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(package.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        Text(package.version)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 6) {
                            if package.hasCaveats {
                                summaryBadge("Caveats", color: .orange)
                            }
                            if package.isDeprecated {
                                summaryBadge("Deprecated", color: .yellow)
                            }
                            if package.isDisabled {
                                summaryBadge("Disabled", color: .red)
                            }
                            if package.autoUpdates {
                                summaryBadge("Auto Updates", color: .blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(package)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(package.title), \(package.kind.title.dropLast()), version \(package.version)")
                }
                .listStyle(.sidebar)
                .overlay {
                    if viewModel.filteredPackages.isEmpty {
                        ContentUnavailableView.search(text: viewModel.searchText)
                    }
                }
            }
        }
        .padding(20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Catalog")
                .font(.largeTitle)
                .bold()

            Text("Browse Homebrew formulae and casks from the hosted API.")
                .foregroundStyle(.secondary)

            TextField("Search formulae and casks", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search packages")

            Picker("Package Scope", selection: $viewModel.scope) {
                ForEach(CatalogScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button("Save Search...") {
                    savedSearchName = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                    isPresentingSaveSearch = true
                }
                .disabled(!viewModel.hasSearchConfiguration)

                Menu {
                    ForEach(CatalogFilterOption.allCases) { filter in
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
                .accessibilityLabel("Catalog filters")

                Picker("Sort Packages", selection: $viewModel.sortOption) {
                    ForEach(CatalogSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 180)

                Button("Refresh Catalog") {
                    viewModel.refreshCatalog()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                if case .loaded(let packages) = viewModel.packagesState {
                    Text("\(packages.count) packages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var savedSearchesCard: some View {
        GroupBox("Saved Searches") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.savedSearches.isEmpty {
                    Text("Save your current search, scope, filters, and sort order for quick reuse.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.savedSearches) { search in
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                viewModel.applySavedSearch(search)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(search.name)
                                        .font(.headline)
                                    Text(search.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            Button {
                                viewModel.removeSavedSearch(search)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete saved search \(search.name)")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch viewModel.detailState {
        case .idle:
            ContentUnavailableView(
                "Select a Package",
                systemImage: "shippingbox",
                description: Text("Choose a formula or cask to inspect its metadata.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loading(let package):
            ProgressView("Loading \(package.title)...")
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let package, let message):
            ContentUnavailableView(
                "\(package.title) Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let detail):
            CatalogDetailView(
                detail: detail,
                isFavorite: viewModel.isFavorite(detail),
                actionState: viewModel.actionState(for: detail),
                actionLogs: viewModel.actionLogs(for: detail),
                actionHistory: viewModel.actionHistory(for: detail),
                hasRunningAction: viewModel.hasRunningAction,
                toggleFavorite: {
                    viewModel.toggleFavorite(detail)
                },
                refreshAction: {
                    viewModel.refreshSelectedDetail()
                },
                runAction: { actionKind, detail in
                    viewModel.runAction(actionKind, for: detail)
                },
                cancelAction: {
                    viewModel.cancelAction()
                },
                clearActionOutput: {
                    viewModel.clearActionOutput()
                },
                clearActionHistory: {
                    viewModel.clearActionHistory(for: detail)
                },
                clearAllActionHistory: {
                    viewModel.clearAllActionHistory()
                },
                exportActionHistory: {
                    viewModel.exportActionHistory(for: detail)
                },
                exportAllActionHistory: {
                    viewModel.exportAllActionHistory()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var selectionBinding: Binding<CatalogPackageSummary?> {
        Binding(
            get: { viewModel.selectedPackage },
            set: { viewModel.selectPackage($0) }
        )
    }

    private func filterBinding(_ filter: CatalogFilterOption) -> Binding<Bool> {
        Binding(
            get: { viewModel.isFilterActive(filter) },
            set: { isActive in
                if isActive != viewModel.isFilterActive(filter) {
                    viewModel.toggleFilter(filter)
                }
            }
        )
    }

    private func summaryBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct CatalogDetailView: View {
    let detail: CatalogPackageDetail
    let isFavorite: Bool
    let actionState: CatalogPackageActionState
    let actionLogs: [CatalogPackageActionLogEntry]
    let actionHistory: [CatalogPackageActionHistoryEntry]
    let hasRunningAction: Bool
    let toggleFavorite: () -> Void
    let refreshAction: () -> Void
    let runAction: (CatalogPackageActionKind, CatalogPackageDetail) -> Void
    let cancelAction: () -> Void
    let clearActionOutput: () -> Void
    let clearActionHistory: () -> Void
    let clearAllActionHistory: () -> Void
    let exportActionHistory: () -> Void
    let exportAllActionHistory: () -> Void

    @State private var pendingConfirmation: CatalogPackageActionCommand?
    @State private var pendingHistoryClearTarget: ActionHistoryClearTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleBlock
                metricsSection("Versions", metrics: detail.versionDetails)
                metadataGrid

                if !detail.aliases.isEmpty || !detail.oldNames.isEmpty {
                    DetailCard {
                        VStack(alignment: .leading, spacing: 16) {
                            if !detail.aliases.isEmpty {
                                sectionContentTitle("Aliases")
                                tagFlow(items: detail.aliases)
                            }

                            if !detail.oldNames.isEmpty {
                                sectionContentTitle("Old Names")
                                tagFlow(items: detail.oldNames)
                            }
                        }
                    }
                }

                detailSections(detail.dependencySections)
                detailSections(detail.lifecycleSections)
                detailSections(detail.platformSections)

                if let caveats = detail.caveats, !caveats.isEmpty {
                    DetailCard(title: "Caveats") {
                        Text(caveats)
                            .textSelection(.enabled)
                    }
                }

                detailSections(detail.artifactSections)
                metricsSection("Analytics", metrics: detail.analytics)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            pendingConfirmation?.confirmationTitle ?? "Install Package",
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            Button(pendingConfirmation?.kind.title ?? "Install") {
                guard let pendingConfirmation else {
                    return
                }

                runAction(pendingConfirmation.kind, detail)
                self.pendingConfirmation = nil
            }

            Button("Cancel", role: .cancel) {
                pendingConfirmation = nil
            }
        } message: {
            Text(pendingConfirmation?.confirmationMessage ?? "")
        }
        .confirmationDialog(
            pendingHistoryClearTarget?.title(for: detail.title) ?? "Clear History",
            isPresented: historyClearConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button(
                pendingHistoryClearTarget?.buttonTitle ?? "Clear",
                role: .destructive
            ) {
                switch pendingHistoryClearTarget {
                case .package:
                    clearActionHistory()
                case .all:
                    clearAllActionHistory()
                case .none:
                    break
                }
                pendingHistoryClearTarget = nil
            }

            Button("Cancel", role: .cancel) {
                pendingHistoryClearTarget = nil
            }
        } message: {
            Text(pendingHistoryClearTarget?.message(for: detail.title) ?? "")
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(detail.title)
                        .font(.largeTitle)
                        .bold()

                    if detail.fullName != detail.title {
                        Text(detail.fullName)
                            .font(.headline.monospaced())
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }

                    Text(detail.description)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        toggleFavorite()
                    } label: {
                        Label(
                            isFavorite ? "Favorite" : "Add Favorite",
                            systemImage: isFavorite ? "star.fill" : "star"
                        )
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                    .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                    .buttonStyle(.borderless)

                    Text(detail.kind.title.dropLast())
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())

                    Text(detail.version)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            actionBlock
        }
    }

    private var actionBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button("Install...") {
                    beginAction(.install)
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasRunningAction)
                .accessibilityLabel("Install package")

                Button("Fetch") {
                    beginAction(.fetch)
                }
                .disabled(hasRunningAction)
                .accessibilityLabel("Fetch package")

                if actionState.isRunning {
                    Button("Cancel", action: cancelAction)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityLabel("Cancel running package command")
                }

                if let homepage = detail.homepage {
                    Link("Open Homepage", destination: homepage)
                        .accessibilityLabel("Open package homepage")
                }

                if let downloadURL = detail.downloadURL {
                    Link("Open Download", destination: downloadURL)
                        .accessibilityLabel("Open package download URL")
                }

                Button("Copy Install Command") {
                    copyToPasteboard(detail.installCommand)
                }
                .accessibilityLabel("Copy install command")

                Button("Copy Fetch Command") {
                    copyToPasteboard(detail.fetchCommand)
                }
                .accessibilityLabel("Copy fetch command")

                Button("Refresh Detail", action: refreshAction)
                    .accessibilityLabel("Refresh package details")
            }

            commandBlock(title: "Install", command: detail.installCommand)
            commandBlock(title: "Fetch", command: detail.fetchCommand)
            actionSummary
            actionHistoryBlock

            if actionState.command != nil {
                actionLogBlock
            }
        }
    }

    @ViewBuilder
    private var actionSummary: some View {
        switch actionState {
        case .idle:
            EmptyView()
        case .running(let progress):
            actionStatusCard(
                progress: progress,
                title: "\(progress.command.kind.title) is running...",
                detail: "Streaming Homebrew output live.",
                systemImage: "terminal",
                color: .blue,
                isRunning: true
            )
        case .succeeded(let progress, _):
            actionStatusCard(
                progress: progress,
                title: "\(progress.command.kind.title) completed.",
                detail: "Homebrew completed the action successfully.",
                systemImage: "checkmark.circle.fill",
                color: .green,
                isRunning: false
            )
        case .failed(let progress, let message):
            actionStatusCard(
                progress: progress,
                title: "\(progress.command.kind.title) failed.",
                detail: CommandPresentation.friendlyFailureDescription(
                    message,
                    fallback: "Homebrew couldn't complete this action."
                ),
                systemImage: "xmark.octagon.fill",
                color: .red,
                isRunning: false
            )
        case .cancelled(let progress):
            actionStatusCard(
                progress: progress,
                title: "\(progress.command.kind.title) was cancelled.",
                detail: "The Homebrew command stopped before completion.",
                systemImage: "stop.circle.fill",
                color: .orange,
                isRunning: false
            )
        }
    }

    private var actionLogBlock: some View {
        DetailCard(title: "Command Output") {
            VStack(alignment: .leading, spacing: 12) {
                if let command = actionState.command {
                    commandBlock(title: "Executed Command", command: command.command)
                }

                if actionLogs.isEmpty {
                    Text("Command output will appear here as Homebrew writes to stdout and stderr.")
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("\(actionLogs.count) log \(actionLogs.count == 1 ? "entry" : "entries")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if actionState.isRunning {
                            Label("Streaming live", systemImage: "waveform")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }

                    ActionLogConsole(entries: actionLogs)
                        .frame(minHeight: 150, maxHeight: 260)
                }

                if !actionState.isRunning {
                    Button("Clear Output", action: clearActionOutput)
                        .accessibilityLabel("Clear command output")
                }
            }
        }
    }

    @ViewBuilder
    private var actionHistoryBlock: some View {
        if !actionHistory.isEmpty {
            DetailCard(title: "Command History") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Text("Recent install and fetch runs for this package.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Menu("Manage History") {
                            Button("Export Package History", action: exportActionHistory)
                            Button("Export All History", action: exportAllActionHistory)

                            Divider()

                            Button("Clear Package History", role: .destructive) {
                                pendingHistoryClearTarget = .package
                            }

                            Button("Clear All History", role: .destructive) {
                                pendingHistoryClearTarget = .all
                            }
                        }
                    }

                    ForEach(actionHistory) { entry in
                        actionHistoryRow(entry)
                    }
                }
            }
        }
    }

    private var metadataGrid: some View {
        DetailCard(title: "Metadata") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                ForEach(detail.metadataDetails) { metric in
                    metadataRow(metric.title, metric.value)
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
    private func metricsSection(_ title: String, metrics: [CatalogDetailMetric]) -> some View {
        if !metrics.isEmpty {
            DetailCard(title: title) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)], alignment: .leading, spacing: 12) {
                    ForEach(metrics) { metric in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(metric.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(metric.value)
                                .font(.headline.monospaced())
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailSections(_ sections: [CatalogDetailSection]) -> some View {
        ForEach(sections) { section in
            DetailCard(title: section.title) {
                switch section.style {
                case .tags:
                    tagFlow(items: section.items)
                case .list:
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(section.items, id: \.self) { item in
                            Text(item)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func tagFlow(items: [String]) -> some View {
        FlowLayout(items: items) { item in
            Text(item)
                .font(.caption.monospaced())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                .textSelection(.enabled)
        }
    }

    private func commandBlock(title: String, command: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(command)
                .font(.caption.monospaced())
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .textSelection(.enabled)
        }
    }

    private func actionStatusCard(
        progress: CatalogPackageActionProgress,
        title: String,
        detail: String,
        systemImage: String,
        color: Color,
        isRunning: Bool
    ) -> some View {
        DetailCard(title: "Action Status") {
            TimelineView(.periodic(from: progress.startedAt, by: 1)) { context in
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        if isRunning {
                            ProgressView()
                                .controlSize(.small)
                        }

                        statusBanner(text: title, systemImage: systemImage, color: color)
                    }

                    Text(detail)
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        actionMetric("Command", progress.command.kind.title)
                        actionMetric("Started", formattedTime(progress.startedAt))
                        actionMetric("Duration", formattedDuration(progress, referenceDate: context.date))
                        actionMetric("Output Lines", "\(actionLogs.count)")
                    }
                }
            }
        }
    }

    private func actionMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.callout.monospaced())
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statusBanner(text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(color)
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }

    private func formattedDuration(
        _ progress: CatalogPackageActionProgress,
        referenceDate: Date
    ) -> String {
        formattedDuration(progress.elapsedTime(at: referenceDate))
    }

    private func formattedDuration(_ elapsed: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]

        return formatter.string(from: elapsed) ?? "00:00"
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3)
            .bold()
    }

    private func sectionContentTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private func beginAction(_ kind: CatalogPackageActionKind) {
        if kind.requiresConfirmation {
            pendingConfirmation = detail.actionCommand(for: kind)
            return
        }

        runAction(kind, detail)
    }

    private func actionHistoryRow(_ entry: CatalogPackageActionHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                statusBadge(for: entry.outcome)

                Text(entry.command.kind.title)
                    .font(.headline)

                Spacer()

                Text(entry.startedAt, format: .dateTime.hour().minute().second())
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(entry.command.command)
                .font(.caption.monospaced())
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .textSelection(.enabled)

            HStack(spacing: 12) {
                actionHistoryMetric("Outcome", entry.outcome.title)
                actionHistoryMetric("Detail", entry.outcome.detail)
                actionHistoryMetric("Duration", formattedDuration(entry.duration))
                actionHistoryMetric("Output", "\(entry.outputLineCount) lines")
            }

            HStack(spacing: 12) {
                Button(entry.command.kind == .install ? "Install Again..." : "Fetch Again") {
                    beginAction(entry.command.kind)
                }
                .disabled(hasRunningAction)

                Button("Copy Command") {
                    copyToPasteboard(entry.command.command)
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func actionHistoryMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.monospaced())
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusBadge(for outcome: CatalogPackageActionHistoryOutcome) -> some View {
        Text(outcome.title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(for: outcome).opacity(0.14), in: Capsule())
            .foregroundStyle(statusColor(for: outcome))
    }

    private func statusColor(for outcome: CatalogPackageActionHistoryOutcome) -> Color {
        switch outcome {
        case .succeeded:
            .green
        case .failed:
            .red
        case .cancelled:
            .orange
        }
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    pendingConfirmation = nil
                }
            }
        )
    }

    private var historyClearConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingHistoryClearTarget != nil },
            set: { isPresented in
                if !isPresented {
                    pendingHistoryClearTarget = nil
                }
            }
        )
    }
}

private enum ActionHistoryClearTarget {
    case package
    case all

    var buttonTitle: String {
        switch self {
        case .package:
            "Clear Package History"
        case .all:
            "Clear All History"
        }
    }

    func title(for packageTitle: String) -> String {
        switch self {
        case .package:
            "Clear \(packageTitle) History?"
        case .all:
            "Clear All Command History?"
        }
    }

    func message(for packageTitle: String) -> String {
        switch self {
        case .package:
            "This removes all saved install and fetch history for \(packageTitle)."
        case .all:
            "This removes all saved install and fetch history across every package."
        }
    }
}

private struct ActionLogConsole: View {
    let entries: [CatalogPackageActionLogEntry]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(entries) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)

                            Text(label(for: entry.kind))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(labelColor(for: entry.kind).opacity(0.15), in: Capsule())
                                .foregroundStyle(labelColor(for: entry.kind))

                            Text(entry.text)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .id(entry.id)
                    }
                }
                .padding(12)
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear {
                scrollToLatest(using: proxy)
            }
            .onChange(of: entries.last?.id) { _, _ in
                scrollToLatest(using: proxy)
            }
        }
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let latestID = entries.last?.id else {
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            proxy.scrollTo(latestID, anchor: .bottom)
        }
    }

    private func label(for kind: CatalogPackageActionLogKind) -> String {
        switch kind {
        case .system:
            "SYSTEM"
        case .stdout:
            "STDOUT"
        case .stderr:
            "STDERR"
        }
    }

    private func labelColor(for kind: CatalogPackageActionLogKind) -> Color {
        switch kind {
        case .system:
            .secondary
        case .stdout:
            .blue
        case .stderr:
            .red
        }
    }
}

struct DetailCard<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.title3)
                    .bold()
            }

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

private struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content

    init(items: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 10) {
            ForEach(Array(items), id: \.self) { item in
                content(item)
            }
        }
    }
}

private struct CatalogSavedSearchSheet: View {
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Search")
                .font(.title2.bold())

            Text("Save the current search text, scope, filters, and sort order for quick reuse.")
                .foregroundStyle(.secondary)

            TextField("Search name", text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Saved search name")

            HStack {
                Spacer()

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 420)
    }
}
