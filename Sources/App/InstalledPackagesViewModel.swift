import Foundation

@MainActor
final class InstalledPackagesViewModel: ObservableObject {
    @Published var packagesState: InstalledPackagesLoadState = .idle
    @Published var exportState: InstalledPackagesBrewfileExportState = .idle
    @Published var exportLogs: [CommandLogEntry] = []
    @Published var searchText = ""
    @Published var scope: CatalogScope = .all
    @Published var activeFilters: Set<InstalledPackageFilterOption> = []
    @Published var sortOption: InstalledPackageSortOption = .installDate
    @Published var selectedPackage: InstalledPackage?

    private let provider: any InstalledPackagesProviding
    private let commandExecutor: any BrewCommandExecuting
    private let destinationPicker: any BrewfileDumpDestinationPicking
    private let fileManager: FileManager
    private var exportTask: Task<Void, Never>?
    private var logBuffer = CommandLogBuffer()

    init(
        provider: any InstalledPackagesProviding,
        commandExecutor: any BrewCommandExecuting,
        destinationPicker: any BrewfileDumpDestinationPicking,
        fileManager: FileManager = .default
    ) {
        self.provider = provider
        self.commandExecutor = commandExecutor
        self.destinationPicker = destinationPicker
        self.fileManager = fileManager
    }

    deinit {
        exportTask?.cancel()
    }

    var filteredPackages: [InstalledPackage] {
        guard case .loaded(let packages) = packagesState else {
            return []
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = packages.filter { package in
            guard scope.includes(package.kind) else {
                return false
            }

            guard matchesActiveFilters(for: package) else {
                return false
            }

            guard !trimmedQuery.isEmpty else {
                return true
            }

            return package.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.slug.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.fullName.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.subtitle.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.tap.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.version.localizedCaseInsensitiveContains(trimmedQuery)
        }

        return filtered.sorted(by: sorter(for: sortOption))
    }

    var activeFilterCount: Int {
        activeFilters.count
    }

    var stateCounts: [InstalledPackageStateCount] {
        guard case .loaded(let packages) = packagesState else {
            return []
        }

        return [
            InstalledPackageStateCount(title: "On Request", count: packages.filter(\.isInstalledOnRequest).count),
            InstalledPackageStateCount(title: "Dependency", count: packages.filter(\.isInstalledAsDependency).count),
            InstalledPackageStateCount(title: "Leaves", count: packages.filter(\.isLeaf).count),
            InstalledPackageStateCount(title: "Pinned", count: packages.filter(\.isPinned).count)
        ]
    }

    var hasRunningExport: Bool {
        exportState.isRunning
    }

    var exportCommandPreview: String {
        exportCommand(for: URL(fileURLWithPath: "/<selected-path>")).command
    }

    var exportDescription: String {
        exportCommand(for: fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Brewfile"))
            .scopeDescription
    }

    func dependencySnapshot(for package: InstalledPackage) -> InstalledPackageDependencySnapshot? {
        guard case .loaded(let packages) = packagesState else {
            return nil
        }

        let graph = InstalledPackageDependencyGraph(packages: packages)
        return graph.snapshot(for: package)
    }

    func selectPackage(id: String) {
        guard case .loaded(let packages) = packagesState,
              let package = packages.first(where: { $0.id == id }) else {
            return
        }

        selectedPackage = package
    }

    func loadIfNeeded() {
        guard case .idle = packagesState else {
            return
        }

        refreshPackages()
    }

    func refreshPackages() {
        packagesState = .loading

        Task { @MainActor [provider] in
            do {
                let packages = try await provider.fetchInstalledPackages()
                packagesState = .loaded(packages)

                if let selectedPackage,
                   let refreshedSelection = packages.first(where: { $0.id == selectedPackage.id }) {
                    self.selectedPackage = refreshedSelection
                } else {
                    selectedPackage = defaultSelection(from: packages)
                }
            } catch {
                packagesState = .failed(error.localizedDescription)
                selectedPackage = nil
            }
        }
    }

    func toggleFilter(_ filter: InstalledPackageFilterOption) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
    }

    func clearFilters() {
        activeFilters.removeAll()
    }

    func isFilterActive(_ filter: InstalledPackageFilterOption) -> Bool {
        activeFilters.contains(filter)
    }

    func generateBrewfile() {
        let commandTemplate = exportCommand(
            for: fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Brewfile")
        )
        let startingDirectory = fileManager.homeDirectoryForCurrentUser

        guard let destinationURL = destinationPicker.chooseDestination(
            suggestedFileName: commandTemplate.suggestedFileName,
            startingDirectory: startingDirectory
        ) else {
            return
        }

        let command = exportCommand(for: destinationURL)
        let progress = InstalledPackagesBrewfileExportProgress(
            command: command,
            startedAt: Date()
        )

        exportTask?.cancel()
        exportTask = nil
        resetExportOutput()
        exportState = .running(progress)
        appendExportLog(.system, "Preparing Brewfile export for the current \(scope.title.lowercased()) scope.")

        exportTask = Task { @MainActor [commandExecutor] in
            do {
                let result = try await commandExecutor.execute(arguments: command.arguments) { [weak self] kind, text in
                    self?.appendExportLog(kind, text)
                }
                flushPendingExportLogs()
                appendExportLog(.system, "Generated Brewfile at \(destinationURL.path).")
                exportState = .succeeded(progress.finished(at: Date()), result)
            } catch is CancellationError {
                flushPendingExportLogs()
                appendExportLog(.system, "Brewfile export cancelled.")
                exportState = .cancelled(progress.finished(at: Date()))
            } catch {
                flushPendingExportLogs()
                appendExportLog(.system, error.localizedDescription)
                exportState = .failed(progress.finished(at: Date()), error.localizedDescription)
            }

            exportTask = nil
        }
    }

    func cancelExport() {
        exportTask?.cancel()
    }

    func clearExportOutput() {
        exportTask?.cancel()
        exportTask = nil
        resetExportOutput()
        exportState = .idle
    }

    private func matchesActiveFilters(for package: InstalledPackage) -> Bool {
        activeFilters.allSatisfy { filter in
            switch filter {
            case .pinned:
                package.isPinned
            case .linked:
                package.isLinked
            case .leaves:
                package.isLeaf
            case .outdated:
                package.isOutdated
            case .installedOnRequest:
                package.isInstalledOnRequest
            case .installedAsDependency:
                package.isInstalledAsDependency
            case .autoUpdates:
                package.autoUpdates
            }
        }
    }

    private func sorter(for option: InstalledPackageSortOption) -> (InstalledPackage, InstalledPackage) -> Bool {
        switch option {
        case .name:
            return { lhs, rhs in
                Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .installDate:
            return { lhs, rhs in
                switch (lhs.installedAt, rhs.installedAt) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    return lhsDate > rhsDate
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                default:
                    return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
                }
            }
        case .packageType:
            return { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .tap:
            return { lhs, rhs in
                let result = lhs.tap.localizedCaseInsensitiveCompare(rhs.tap)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        }
    }

    private func defaultSelection(from packages: [InstalledPackage]) -> InstalledPackage? {
        packages.sorted(by: sorter(for: sortOption)).first
    }

    private static func compare(_ lhs: String, _ rhs: String, fallback: Bool) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result != .orderedSame {
            return result == .orderedAscending
        }
        return fallback
    }

    private func exportCommand(for destinationURL: URL) -> InstalledPackagesBrewfileExportCommand {
        InstalledPackagesBrewfileExportCommand(
            scope: scope,
            destinationURL: destinationURL
        )
    }

    private func resetExportOutput() {
        logBuffer.reset()
        exportLogs = []
    }

    private func appendExportLog(_ kind: CommandLogKind, _ text: String, timestamp: Date = Date()) {
        logBuffer.append(kind, text, timestamp: timestamp)
        exportLogs = logBuffer.entries
    }

    private func flushPendingExportLogs() {
        logBuffer.flush()
        exportLogs = logBuffer.entries
    }
}

extension InstalledPackagesViewModel {
    static func live() -> InstalledPackagesViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)
        let commandExecutor = BrewCommandExecutor(
            brewLocator: brewLocator,
            runner: runner
        )

        return InstalledPackagesViewModel(
            provider: BrewInstalledPackagesProvider(
                brewLocator: brewLocator,
                runner: runner
            ),
            commandExecutor: commandExecutor,
            destinationPicker: BrewfileDumpDestinationPicker()
        )
    }
}

struct InstalledPackageStateCount: Identifiable, Equatable {
    let title: String
    let count: Int

    var id: String {
        title
    }
}

struct InstalledPackageDependencySnapshot: Equatable {
    let summaryMetrics: [InstalledPackageDependencyMetric]
    let dependencyGroups: [InstalledPackageDependencyGroup]
    let dependencyTree: [InstalledPackageTreeRow]
    let dependentTree: [InstalledPackageTreeRow]
}

struct InstalledPackageDependencyMetric: Identifiable, Equatable {
    let title: String
    let value: String

    var id: String {
        title
    }
}

struct InstalledPackageTreeRow: Identifiable, Equatable {
    let id: String
    let packageID: String
    let title: String
    let depth: Int
}

private struct InstalledPackageDependencyGraph {
    private let packagesByName: [String: InstalledPackage]
    private let packagesByFullName: [String: InstalledPackage]
    private let dependencyLookup: [String: [InstalledPackage]]
    private let dependentLookup: [String: [InstalledPackage]]

    init(packages: [InstalledPackage]) {
        packagesByName = Dictionary(uniqueKeysWithValues: packages.map { ($0.slug, $0) })
        packagesByFullName = Dictionary(uniqueKeysWithValues: packages.map { ($0.fullName, $0) })

        var dependencyLookup: [String: [InstalledPackage]] = [:]
        var dependentLookup: [String: [InstalledPackage]] = [:]

        for package in packages {
            let directDependencies = Self.resolveInstalledPackages(
                for: package,
                packagesByName: packagesByName,
                packagesByFullName: packagesByFullName
            )
            dependencyLookup[package.id] = directDependencies

            for dependency in directDependencies {
                dependentLookup[dependency.id, default: []].append(package)
            }
        }

        self.dependencyLookup = dependencyLookup.mapValues(Self.sortPackages)
        self.dependentLookup = dependentLookup.mapValues(Self.sortPackages)
    }

    func snapshot(for package: InstalledPackage) -> InstalledPackageDependencySnapshot {
        let directDependencies = dependencyLookup[package.id] ?? []
        let directDependents = dependentLookup[package.id] ?? []
        let transitiveDependencies = walkTree(from: package.id, using: dependencyLookup)
        let transitiveDependents = walkTree(from: package.id, using: dependentLookup)

        return InstalledPackageDependencySnapshot(
            summaryMetrics: [
                InstalledPackageDependencyMetric(title: "Direct Dependencies", value: "\(directDependencies.count)"),
                InstalledPackageDependencyMetric(title: "Transitive Dependencies", value: "\(transitiveDependencies.count)"),
                InstalledPackageDependencyMetric(title: "Direct Dependents", value: "\(directDependents.count)"),
                InstalledPackageDependencyMetric(title: "Transitive Dependents", value: "\(transitiveDependents.count)")
            ],
            dependencyGroups: package.dependencyGroups,
            dependencyTree: buildTreeRows(from: package.id, using: dependencyLookup),
            dependentTree: buildTreeRows(from: package.id, using: dependentLookup)
        )
    }

    private func resolveInstalledPackages(for package: InstalledPackage) -> [InstalledPackage] {
        Self.resolveInstalledPackages(
            for: package,
            packagesByName: packagesByName,
            packagesByFullName: packagesByFullName
        )
    }

    private static func resolveInstalledPackages(
        for package: InstalledPackage,
        packagesByName: [String: InstalledPackage],
        packagesByFullName: [String: InstalledPackage]
    ) -> [InstalledPackage] {
        let relationNames: [String] = if package.kind == .formula {
            Array(Set(package.directDependencies + package.directRuntimeDependencies))
        } else {
            []
        }

        return relationNames.compactMap { name in
            resolvePackage(
                named: name,
                packagesByName: packagesByName,
                packagesByFullName: packagesByFullName
            )
        }
    }

    private func resolvePackage(named name: String) -> InstalledPackage? {
        Self.resolvePackage(
            named: name,
            packagesByName: packagesByName,
            packagesByFullName: packagesByFullName
        )
    }

    private static func resolvePackage(
        named name: String,
        packagesByName: [String: InstalledPackage],
        packagesByFullName: [String: InstalledPackage]
    ) -> InstalledPackage? {
        packagesByFullName[name] ?? packagesByName[name]
    }

    private func walkTree(from packageID: String, using lookup: [String: [InstalledPackage]]) -> Set<String> {
        var visited: Set<String> = []
        var stack = lookup[packageID]?.map(\.id) ?? []

        while let next = stack.popLast() {
            if visited.insert(next).inserted {
                stack.append(contentsOf: lookup[next]?.map(\.id) ?? [])
            }
        }

        return visited
    }

    private func buildTreeRows(from packageID: String, using lookup: [String: [InstalledPackage]]) -> [InstalledPackageTreeRow] {
        var rows: [InstalledPackageTreeRow] = []
        var path: [String] = [packageID]

        appendRows(
            for: packageID,
            depth: 0,
            lookup: lookup,
            path: &path,
            rows: &rows
        )

        return rows
    }

    private func appendRows(
        for packageID: String,
        depth: Int,
        lookup: [String: [InstalledPackage]],
        path: inout [String],
        rows: inout [InstalledPackageTreeRow]
    ) {
        for package in lookup[packageID] ?? [] {
            rows.append(
                InstalledPackageTreeRow(
                    id: (path + [package.id]).joined(separator: ">"),
                    packageID: package.id,
                    title: package.title,
                    depth: depth
                )
            )

            if !path.contains(package.id) {
                path.append(package.id)
                appendRows(
                    for: package.id,
                    depth: depth + 1,
                    lookup: lookup,
                    path: &path,
                    rows: &rows
                )
                _ = path.popLast()
            }
        }
    }

    private static func sortPackages(_ packages: [InstalledPackage]) -> [InstalledPackage] {
        packages.sorted { lhs, rhs in
            let result = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if result != .orderedSame {
                return result == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }
}
