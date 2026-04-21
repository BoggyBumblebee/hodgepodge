import SwiftUI

struct CatalogView: View {
    @ObservedObject var viewModel: CatalogViewModel

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)

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
            CatalogDetailView(detail: detail) {
                viewModel.refreshSelectedDetail()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var selectionBinding: Binding<CatalogPackageSummary?> {
        Binding(
            get: { viewModel.selectedPackage },
            set: { viewModel.selectPackage($0) }
        )
    }
}

private struct CatalogDetailView: View {
    let detail: CatalogPackageDetail
    let refreshAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleBlock
                metadataGrid

                if !detail.aliases.isEmpty {
                    tagSection("Aliases", items: detail.aliases)
                }

                if !detail.dependencies.isEmpty {
                    tagSection("Dependencies", items: detail.dependencies)
                }

                if !detail.conflicts.isEmpty {
                    tagSection("Conflicts", items: detail.conflicts)
                }

                if !detail.artifacts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionTitle("Artifacts")
                        ForEach(detail.artifacts, id: \.self) { artifact in
                            Text(artifact)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }

                if let caveats = detail.caveats, !caveats.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionTitle("Caveats")
                        Text(caveats)
                            .textSelection(.enabled)
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
                    Text(detail.title)
                        .font(.largeTitle)
                        .bold()

                    Text(detail.description)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(detail.kind.title.dropLast())
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }

            HStack(spacing: 12) {
                if let homepage = detail.homepage {
                    Link("Open Homepage", destination: homepage)
                }

                Button("Refresh Detail", action: refreshAction)

                Text(detail.installCommand)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .textSelection(.enabled)
            }
        }
    }

    private var metadataGrid: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
            metadataRow("Slug", detail.slug)
            metadataRow("Version", detail.version)
            metadataRow("Tap", detail.tap)
            metadataRow("License", detail.license ?? "Not specified")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
        )
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

    private func tagSection(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)

            FlowLayout(items: items) { item in
                Text(item)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                    .textSelection(.enabled)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3)
            .bold()
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
