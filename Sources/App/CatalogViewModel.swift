import Foundation

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var packagesState: CatalogPackagesLoadState = .idle
    @Published var detailState: CatalogDetailLoadState = .idle
    @Published var actionState: CatalogPackageActionState = .idle
    @Published var actionLogs: [CatalogPackageActionLogEntry] = []
    @Published var searchText = ""
    @Published var scope: CatalogScope = .all
    @Published var activeFilters: Set<CatalogFilterOption> = []
    @Published var sortOption: CatalogSortOption = .name
    @Published var selectedPackage: CatalogPackageSummary?

    private let apiClient: any HomebrewAPIClienting
    private let commandExecutor: any BrewCommandExecuting
    private var detailCache: [String: CatalogPackageDetail] = [:]
    private var actionTask: Task<Void, Never>?
    private var nextLogIdentifier = 0
    private var pendingLogText: [CatalogPackageActionLogKind: String] = [:]

    init(
        apiClient: any HomebrewAPIClienting,
        commandExecutor: any BrewCommandExecuting
    ) {
        self.apiClient = apiClient
        self.commandExecutor = commandExecutor
    }

    deinit {
        actionTask?.cancel()
    }

    var filteredPackages: [CatalogPackageSummary] {
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
                package.subtitle.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.tap.localizedCaseInsensitiveContains(trimmedQuery)
        }

        return filtered.sorted(by: sorter(for: sortOption))
    }

    var activeFilterCount: Int {
        activeFilters.count
    }

    var hasRunningAction: Bool {
        actionState.isRunning
    }

    func loadIfNeeded() {
        guard case .idle = packagesState else {
            return
        }

        refreshCatalog()
    }

    func refreshCatalog() {
        packagesState = .loading

        Task { @MainActor [apiClient] in
            do {
                let packages = try await apiClient.fetchCatalog()
                packagesState = .loaded(packages)

                if let selectedPackage, packages.contains(selectedPackage) {
                    await loadDetail(for: selectedPackage)
                } else {
                    let replacement = packages.first
                    selectedPackage = replacement
                    if let replacement {
                        await loadDetail(for: replacement)
                    } else {
                        detailState = .idle
                    }
                }
            } catch {
                packagesState = .failed(error.localizedDescription)
                detailState = .idle
            }
        }
    }

    func selectPackage(_ package: CatalogPackageSummary?) {
        selectedPackage = package

        guard let package else {
            detailState = .idle
            return
        }

        Task { @MainActor in
            await loadDetail(for: package)
        }
    }

    func refreshSelectedDetail() {
        guard let selectedPackage else {
            detailState = .idle
            return
        }

        detailCache.removeValue(forKey: selectedPackage.id)
        Task { @MainActor in
            await loadDetail(for: selectedPackage)
        }
    }

    private func loadDetail(for package: CatalogPackageSummary) async {
        if let cached = detailCache[package.id] {
            detailState = .loaded(cached)
            return
        }

        detailState = .loading(package)

        do {
            let detail = try await apiClient.fetchDetail(for: package)
            detailCache[package.id] = detail
            guard selectedPackage == package else {
                return
            }
            detailState = .loaded(detail)
        } catch {
            guard selectedPackage == package else {
                return
            }
            detailState = .failed(package, error.localizedDescription)
        }
    }

    func toggleFilter(_ filter: CatalogFilterOption) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
    }

    func clearFilters() {
        activeFilters.removeAll()
    }

    func isFilterActive(_ filter: CatalogFilterOption) -> Bool {
        activeFilters.contains(filter)
    }

    func runAction(_ actionKind: CatalogPackageActionKind, for detail: CatalogPackageDetail) {
        let command = detail.actionCommand(for: actionKind)
        let progress = CatalogPackageActionProgress(command: command, startedAt: Date())

        actionTask?.cancel()
        actionTask = nil
        resetActionOutput()
        actionState = .running(progress)
        appendLog(.system, "Preparing \(actionKind.title.lowercased()) for \(detail.title).")

        actionTask = Task { @MainActor [commandExecutor] in
            do {
                let result = try await commandExecutor.execute(command: command) { [weak self] kind, text in
                    self?.appendLog(kind, text)
                }
                flushPendingLogs()
                appendLog(.system, "\(actionKind.title) finished with exit code \(result.exitCode).")
                actionState = .succeeded(progress.finished(at: Date()), result)
            } catch is CancellationError {
                flushPendingLogs()
                appendLog(.system, "\(actionKind.title) cancelled.")
                actionState = .cancelled(progress.finished(at: Date()))
            } catch {
                flushPendingLogs()
                appendLog(.system, error.localizedDescription)
                actionState = .failed(progress.finished(at: Date()), error.localizedDescription)
            }

            actionTask = nil
        }
    }

    func cancelAction() {
        actionTask?.cancel()
    }

    func clearActionOutput() {
        actionTask?.cancel()
        actionTask = nil
        resetActionOutput()
        actionState = .idle
    }

    func actionState(for detail: CatalogPackageDetail) -> CatalogPackageActionState {
        guard actionState.command?.packageID == detail.packageID else {
            return .idle
        }

        return actionState
    }

    func actionLogs(for detail: CatalogPackageDetail) -> [CatalogPackageActionLogEntry] {
        guard actionState.command?.packageID == detail.packageID else {
            return []
        }

        return actionLogs
    }

    private func matchesActiveFilters(for package: CatalogPackageSummary) -> Bool {
        activeFilters.allSatisfy { filter in
            switch filter {
            case .hasCaveats:
                package.hasCaveats
            case .deprecated:
                package.isDeprecated
            case .disabled:
                package.isDisabled
            case .autoUpdates:
                package.autoUpdates
            }
        }
    }

    private func sorter(for option: CatalogSortOption) -> (CatalogPackageSummary, CatalogPackageSummary) -> Bool {
        switch option {
        case .name:
            return { lhs, rhs in
                Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .packageType:
            return { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .version:
            return { lhs, rhs in
                let result = lhs.version.localizedStandardCompare(rhs.version)
                if result != .orderedSame {
                    return result == .orderedAscending
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

    private static func compare(_ lhs: String, _ rhs: String, fallback: Bool) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result != .orderedSame {
            return result == .orderedAscending
        }
        return fallback
    }

    private func appendLog(_ kind: CatalogPackageActionLogKind, _ text: String, timestamp: Date = Date()) {
        switch kind {
        case .system:
            let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                return
            }
            appendLogLine(kind, line, timestamp: timestamp)
        case .stdout, .stderr:
            var buffered = pendingLogText[kind, default: ""]
            buffered.append(text)

            let lines = buffered.components(separatedBy: .newlines)
            pendingLogText[kind] = lines.last ?? ""

            for line in lines.dropLast() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    continue
                }
                appendLogLine(kind, trimmed, timestamp: timestamp)
            }
        }
    }

    private func appendLogLine(_ kind: CatalogPackageActionLogKind, _ line: String, timestamp: Date = Date()) {
        actionLogs.append(
            CatalogPackageActionLogEntry(
                id: nextLogIdentifier,
                kind: kind,
                text: line,
                timestamp: timestamp
            )
        )
        nextLogIdentifier += 1
    }

    private func flushPendingLogs() {
        for kind in [CatalogPackageActionLogKind.stdout, .stderr] {
            let line = pendingLogText[kind, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }

            appendLogLine(kind, line)
        }

        pendingLogText.removeAll()
    }

    private func resetActionOutput() {
        actionLogs.removeAll()
        nextLogIdentifier = 0
        pendingLogText.removeAll()
    }
}

extension CatalogViewModel {
    static func live() -> CatalogViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)

        return CatalogViewModel(
            apiClient: HomebrewAPIClient(),
            commandExecutor: BrewCommandExecutor(
                brewLocator: brewLocator,
                runner: runner
            )
        )
    }
}
