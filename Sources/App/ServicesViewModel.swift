import Foundation

enum BrewServicesLoadState: Equatable {
    case idle
    case loading
    case loaded([BrewService])
    case failed(String)
}

@MainActor
final class ServicesViewModel: ObservableObject {
    @Published var servicesState: BrewServicesLoadState = .idle
    @Published var searchText = ""
    @Published var activeFilters: Set<BrewServiceFilterOption> = []
    @Published var sortOption: BrewServiceSortOption = .name
    @Published var selectedService: BrewService?
    @Published var actionState: BrewServiceActionState = .idle
    @Published var actionLogs: [CommandLogEntry] = []

    private let provider: any BrewServicesProviding
    private let commandExecutor: any BrewCommandExecuting
    private var actionTask: Task<Void, Never>?
    private var logBuffer = CommandLogBuffer()

    init(
        provider: any BrewServicesProviding,
        commandExecutor: any BrewCommandExecuting
    ) {
        self.provider = provider
        self.commandExecutor = commandExecutor
    }

    deinit {
        actionTask?.cancel()
    }

    var filteredServices: [BrewService] {
        guard case .loaded(let services) = servicesState else {
            return []
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = services.filter { service in
            guard matchesActiveFilters(for: service) else {
                return false
            }

            guard !trimmedQuery.isEmpty else {
                return true
            }

            return service.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                service.subtitle.localizedCaseInsensitiveContains(trimmedQuery) ||
                (service.user?.localizedCaseInsensitiveContains(trimmedQuery) ?? false) ||
                (service.command?.localizedCaseInsensitiveContains(trimmedQuery) ?? false) ||
                (service.file?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        }

        return filtered.sorted(by: sorter(for: sortOption))
    }

    var activeFilterCount: Int {
        activeFilters.count
    }

    var stateCounts: [BrewServiceStateCount] {
        guard case .loaded(let services) = servicesState else {
            return []
        }

        return [
            BrewServiceStateCount(title: "Running", count: services.filter(\.isRunning).count),
            BrewServiceStateCount(title: "Loaded", count: services.filter(\.isLoaded).count),
            BrewServiceStateCount(title: "Registered", count: services.filter(\.isRegistered).count),
            BrewServiceStateCount(title: "Needs Attention", count: services.filter(hasAttentionState).count)
        ]
    }

    var hasRunningAction: Bool {
        actionState.isRunning
    }

    func loadIfNeeded() {
        guard case .idle = servicesState else {
            return
        }

        refreshServices()
    }

    func refreshServices() {
        servicesState = .loading
        loadServices(preservingSelectionID: selectedService?.id)
    }

    func toggleFilter(_ filter: BrewServiceFilterOption) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
    }

    func clearFilters() {
        activeFilters.removeAll()
    }

    func isFilterActive(_ filter: BrewServiceFilterOption) -> Bool {
        activeFilters.contains(filter)
    }

    func runAction(_ actionKind: BrewServiceActionKind, for service: BrewService) {
        let command = service.command(for: actionKind)
        let progress = BrewServiceActionProgress(command: command, startedAt: Date())

        actionTask?.cancel()
        actionTask = nil
        resetActionOutput()
        actionState = .running(progress)
        appendLog(.system, "Preparing \(actionKind.title.lowercased()) for \(service.title).")

        actionTask = Task { @MainActor [commandExecutor] in
            do {
                let result = try await commandExecutor.execute(arguments: command.arguments) { [weak self] kind, text in
                    self?.appendLog(kind, text)
                }
                flushPendingLogs()
                appendLog(.system, "\(actionKind.title) finished with exit code \(result.exitCode).")
                let completedProgress = progress.finished(at: Date())
                actionState = .succeeded(completedProgress, result)
                reloadServicesAfterAction(preservingSelectionID: service.id)
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

    func actionState(for service: BrewService) -> BrewServiceActionState {
        guard actionState.command?.serviceID == service.id else {
            return .idle
        }

        return actionState
    }

    func actionLogs(for service: BrewService) -> [CommandLogEntry] {
        guard actionState.command?.serviceID == service.id else {
            return []
        }

        return actionLogs
    }

    private func loadServices(preservingSelectionID: String?) {
        Task { @MainActor [provider] in
            do {
                let services = try await provider.fetchServices()
                servicesState = .loaded(services)
                selectedService = selection(
                    in: services,
                    preservingSelectionID: preservingSelectionID
                )
            } catch {
                servicesState = .failed(error.localizedDescription)
                selectedService = nil
            }
        }
    }

    private func reloadServicesAfterAction(preservingSelectionID: String) {
        Task { @MainActor [provider] in
            do {
                let services = try await provider.fetchServices()
                servicesState = .loaded(services)
                selectedService = selection(
                    in: services,
                    preservingSelectionID: preservingSelectionID
                )
            } catch {
                appendLog(.system, error.localizedDescription)
            }
        }
    }

    private func selection(
        in services: [BrewService],
        preservingSelectionID: String?
    ) -> BrewService? {
        if let preservingSelectionID,
           let selected = services.first(where: { $0.id == preservingSelectionID }) {
            return selected
        }

        return services.sorted(by: sorter(for: sortOption)).first
    }

    private func matchesActiveFilters(for service: BrewService) -> Bool {
        activeFilters.allSatisfy { filter in
            switch filter {
            case .running:
                service.isRunning
            case .loaded:
                service.isLoaded
            case .registered:
                service.isRegistered
            case .failed:
                hasAttentionState(service)
            }
        }
    }

    private func hasAttentionState(_ service: BrewService) -> Bool {
        service.exitCode != nil || (!service.isRunning && service.status.lowercased() == "error")
    }

    private func sorter(for option: BrewServiceSortOption) -> (BrewService, BrewService) -> Bool {
        switch option {
        case .name:
            return { lhs, rhs in
                Self.compare(lhs.title, rhs.title, fallback: lhs.id < rhs.id)
            }
        case .status:
            return { lhs, rhs in
                let result = lhs.statusTitle.localizedCaseInsensitiveCompare(rhs.statusTitle)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.id < rhs.id)
            }
        case .user:
            return { lhs, rhs in
                let lhsUser = lhs.user ?? ""
                let rhsUser = rhs.user ?? ""
                let result = lhsUser.localizedCaseInsensitiveCompare(rhsUser)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.id < rhs.id)
            }
        case .processID:
            return { lhs, rhs in
                switch (lhs.pid, rhs.pid) {
                case let (lhsPID?, rhsPID?) where lhsPID != rhsPID:
                    return lhsPID < rhsPID
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                default:
                    return Self.compare(lhs.title, rhs.title, fallback: lhs.id < rhs.id)
                }
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
}

extension ServicesViewModel {
    static func live() -> ServicesViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)
        let commandExecutor = BrewCommandExecutor(
            brewLocator: brewLocator,
            runner: runner
        )

        return ServicesViewModel(
            provider: BrewServicesProvider(
                brewLocator: brewLocator,
                runner: runner
            ),
            commandExecutor: commandExecutor
        )
    }
}
