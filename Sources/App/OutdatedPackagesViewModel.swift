import Foundation

@MainActor
final class OutdatedPackagesViewModel: ObservableObject {
    @Published var packagesState: OutdatedPackagesLoadState = .idle
    @Published var actionState: OutdatedPackageActionState = .idle
    @Published var actionLogs: [CommandLogEntry] = []
    @Published var searchText = ""
    @Published var scope: CatalogScope = .all
    @Published var activeFilters: Set<OutdatedPackageFilterOption> = []
    @Published var sortOption: OutdatedPackageSortOption = .name
    @Published var selectedPackage: OutdatedPackage?

    private let provider: any OutdatedPackagesProviding
    private let commandExecutor: any BrewCommandExecuting
    private var actionTask: Task<Void, Never>?
    private var logBuffer = CommandLogBuffer()

    init(
        provider: any OutdatedPackagesProviding,
        commandExecutor: any BrewCommandExecuting
    ) {
        self.provider = provider
        self.commandExecutor = commandExecutor
    }

    deinit {
        actionTask?.cancel()
    }

    var filteredPackages: [OutdatedPackage] {
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
                package.currentVersion.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.installedVersions.joined(separator: " ").localizedCaseInsensitiveContains(trimmedQuery)
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

        refreshPackages()
    }

    func refreshPackages() {
        packagesState = .loading

        Task { @MainActor [provider] in
            do {
                let packages = try await provider.fetchOutdatedPackages()
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

    func toggleFilter(_ filter: OutdatedPackageFilterOption) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
    }

    func clearFilters() {
        activeFilters.removeAll()
    }

    func isFilterActive(_ filter: OutdatedPackageFilterOption) -> Bool {
        activeFilters.contains(filter)
    }

    func runAction(_ actionKind: OutdatedPackageActionKind, for package: OutdatedPackage) {
        guard package.isUpgradeAvailable else {
            return
        }

        let command = package.actionCommand(for: actionKind)
        let progress = OutdatedPackageActionProgress(command: command, startedAt: Date())

        actionTask?.cancel()
        actionTask = nil
        resetActionOutput()
        actionState = .running(progress)
        appendLog(.system, "Preparing \(actionKind.title.lowercased()) for \(package.title).")

        actionTask = Task { @MainActor [commandExecutor] in
            do {
                let result = try await commandExecutor.execute(arguments: command.arguments) { [weak self] kind, text in
                    self?.appendLog(kind, text)
                }
                flushPendingLogs()
                appendLog(.system, "\(actionKind.title) finished with exit code \(result.exitCode).")
                actionState = .succeeded(progress.finished(at: Date()), result)
                reloadPackagesAfterAction(preservingSelection: package)
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

    func actionState(for package: OutdatedPackage) -> OutdatedPackageActionState {
        guard actionState.command?.packageID == package.id else {
            return .idle
        }

        return actionState
    }

    func actionLogs(for package: OutdatedPackage) -> [CommandLogEntry] {
        guard actionState.command?.packageID == package.id else {
            return []
        }

        return actionLogs
    }

    func isPackageInCurrentSnapshot(_ package: OutdatedPackage) -> Bool {
        guard case .loaded(let packages) = packagesState else {
            return false
        }

        return packages.contains(where: { $0.id == package.id })
    }

    private func matchesActiveFilters(for package: OutdatedPackage) -> Bool {
        activeFilters.allSatisfy { filter in
            switch filter {
            case .pinned:
                package.isPinned
            }
        }
    }

    private func sorter(for option: OutdatedPackageSortOption) -> (OutdatedPackage, OutdatedPackage) -> Bool {
        switch option {
        case .name:
            return { lhs, rhs in
                Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .currentVersion:
            return { lhs, rhs in
                let result = lhs.currentVersion.localizedStandardCompare(rhs.currentVersion)
                if result != .orderedSame {
                    return result == .orderedDescending
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .packageType:
            return { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        }
    }

    private func defaultSelection(from packages: [OutdatedPackage]) -> OutdatedPackage? {
        packages.sorted(by: sorter(for: sortOption)).first
    }

    private func reloadPackagesAfterAction(preservingSelection package: OutdatedPackage) {
        Task { @MainActor [provider] in
            do {
                let packages = try await provider.fetchOutdatedPackages()
                packagesState = .loaded(packages)

                if let refreshedSelection = packages.first(where: { $0.id == package.id }) {
                    selectedPackage = refreshedSelection
                } else {
                    selectedPackage = package
                }
            } catch {
                appendLog(.system, error.localizedDescription)
            }
        }
    }

    private func resetActionOutput() {
        logBuffer.reset()
        actionLogs = []
    }

    private func appendLog(_ kind: CommandLogKind, _ text: String, timestamp: Date = Date()) {
        logBuffer.append(kind, text, timestamp: timestamp)
        actionLogs = logBuffer.entries
    }

    private func flushPendingLogs() {
        logBuffer.flush()
        actionLogs = logBuffer.entries
    }

    private static func compare(_ lhs: String, _ rhs: String, fallback: Bool) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result != .orderedSame {
            return result == .orderedAscending
        }
        return fallback
    }
}

extension OutdatedPackagesViewModel {
    static func live() -> OutdatedPackagesViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)
        let commandExecutor = BrewCommandExecutor(
            brewLocator: brewLocator,
            runner: runner
        )

        return OutdatedPackagesViewModel(
            provider: BrewOutdatedPackagesProvider(
                brewLocator: brewLocator,
                runner: runner
            ),
            commandExecutor: commandExecutor
        )
    }
}
