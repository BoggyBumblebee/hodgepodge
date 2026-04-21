import AppKit
import SwiftUI

struct CatalogView: View {
    @ObservedObject var viewModel: CatalogViewModel

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
            viewModel.loadIfNeeded()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

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
                actionState: viewModel.actionState(for: detail),
                actionLogs: viewModel.actionLogs(for: detail),
                hasRunningAction: viewModel.hasRunningAction,
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
    let actionState: CatalogPackageActionState
    let actionLogs: [CatalogPackageActionLogEntry]
    let hasRunningAction: Bool
    let refreshAction: () -> Void
    let runAction: (CatalogPackageActionKind, CatalogPackageDetail) -> Void
    let cancelAction: () -> Void
    let clearActionOutput: () -> Void

    @State private var pendingConfirmation: CatalogPackageActionCommand?

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
                    pendingConfirmation = detail.actionCommand(for: .install)
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasRunningAction)
                .accessibilityLabel("Install package")

                Button("Fetch") {
                    runAction(.fetch, detail)
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
        case .running(let command):
            statusBanner(
                text: "\(command.kind.title) is running...",
                systemImage: "terminal",
                color: .blue
            )
        case .succeeded(let command, let result):
            statusBanner(
                text: "\(command.kind.title) completed with exit code \(result.exitCode).",
                systemImage: "checkmark.circle.fill",
                color: .green
            )
        case .failed(let command, let message):
            statusBanner(
                text: "\(command.kind.title) failed: \(message)",
                systemImage: "xmark.octagon.fill",
                color: .red
            )
        case .cancelled(let command):
            statusBanner(
                text: "\(command.kind.title) was cancelled.",
                systemImage: "stop.circle.fill",
                color: .orange
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
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(actionLogs) { entry in
                                Text(entry.text)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(logColor(for: entry.kind))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if !actionState.isRunning {
                    Button("Clear Output", action: clearActionOutput)
                        .accessibilityLabel("Clear command output")
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

    private func statusBanner(text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(color)
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

    private func logColor(for kind: CatalogPackageActionLogKind) -> Color {
        switch kind {
        case .system:
            .secondary
        case .stdout:
            .primary
        case .stderr:
            .red
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
}

private struct DetailCard<Content: View>: View {
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
