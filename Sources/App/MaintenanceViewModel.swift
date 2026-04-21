import Foundation

@MainActor
final class MaintenanceViewModel: ObservableObject {
    @Published var dashboardState: BrewMaintenanceLoadState = .idle
    @Published var selectedOutputSource: BrewMaintenanceOutputSource = .doctor
    @Published var actionState: BrewMaintenanceActionState = .idle
    @Published var actionLogs: [CommandLogEntry] = []

    private let provider: any BrewMaintenanceProviding
    private let commandExecutor: any BrewCommandExecuting
    private var actionTask: Task<Void, Never>?
    private var nextLogIdentifier = 0
    private var pendingLogText: [CommandLogKind: String] = [:]

    init(
        provider: any BrewMaintenanceProviding,
        commandExecutor: any BrewCommandExecuting
    ) {
        self.provider = provider
        self.commandExecutor = commandExecutor
    }

    deinit {
        actionTask?.cancel()
    }

    var dashboard: BrewMaintenanceDashboard? {
        guard case .loaded(let dashboard) = dashboardState else {
            return nil
        }
        return dashboard
    }

    func loadIfNeeded() {
        guard case .idle = dashboardState else {
            return
        }

        refreshDashboard()
    }

    func refreshDashboard() {
        dashboardState = .loading

        Task { @MainActor [provider] in
            do {
                let dashboard = try await provider.fetchDashboard()
                dashboardState = .loaded(dashboard)
            } catch {
                dashboardState = .failed(error.localizedDescription)
            }
        }
    }

    func runAction(_ task: BrewMaintenanceTask) {
        let command = BrewMaintenanceActionCommand(task: task, arguments: task.arguments)
        let progress = BrewMaintenanceActionProgress(command: command, startedAt: Date())

        actionTask?.cancel()
        actionTask = nil
        resetActionOutput()
        actionState = .running(progress)
        selectedOutputSource = .liveAction
        appendLog(.system, "Preparing \(task.title.lowercased()).")

        actionTask = Task { @MainActor [commandExecutor] in
            do {
                let result = try await commandExecutor.execute(arguments: command.arguments) { [weak self] kind, text in
                    self?.appendLog(kind, text)
                }
                flushPendingLogs()
                appendLog(.system, "\(task.title) finished with exit code \(result.exitCode).")
                actionState = .succeeded(progress.finished(at: Date()), result)
                reloadDashboardAfterAction()
            } catch is CancellationError {
                flushPendingLogs()
                appendLog(.system, "\(task.title) cancelled.")
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

    func outputText(for source: BrewMaintenanceOutputSource) -> String {
        switch source {
        case .liveAction:
            if actionLogs.isEmpty {
                return "No command output yet."
            }
            return actionLogs.map(renderLogLine).joined(separator: "\n")
        case .config:
            return dashboard?.config.rawOutput ?? "Config output will appear after the first refresh."
        case .doctor:
            return dashboard?.doctor.rawOutput ?? "Doctor output will appear after the first refresh."
        case .cleanup:
            return dashboard?.cleanup.rawOutput.isEmpty == false
                ? dashboard?.cleanup.rawOutput ?? ""
                : "Cleanup preview returned no output."
        case .autoremove:
            return dashboard?.autoremove.rawOutput.isEmpty == false
                ? dashboard?.autoremove.rawOutput ?? ""
                : "Autoremove preview returned no output."
        }
    }

    private func reloadDashboardAfterAction() {
        Task { @MainActor [provider] in
            do {
                let dashboard = try await provider.fetchDashboard()
                dashboardState = .loaded(dashboard)
            } catch {
                appendLog(.system, error.localizedDescription)
            }
        }
    }

    private func resetActionOutput() {
        nextLogIdentifier = 0
        pendingLogText = [:]
        actionLogs = []
    }

    private func appendLog(_ kind: CommandLogKind, _ text: String) {
        guard !text.isEmpty else {
            return
        }

        let combined = (pendingLogText[kind] ?? "") + text
        let segments = combined.split(separator: "\n", omittingEmptySubsequences: false)

        if combined.hasSuffix("\n") {
            pendingLogText[kind] = nil
            for segment in segments where !segment.isEmpty {
                addLogEntry(kind: kind, text: String(segment))
            }
            return
        }

        pendingLogText[kind] = segments.last.map(String.init)
        for segment in segments.dropLast() where !segment.isEmpty {
            addLogEntry(kind: kind, text: String(segment))
        }
    }

    private func flushPendingLogs() {
        let pending = pendingLogText
        pendingLogText = [:]

        for kind in CommandLogKind.allCases {
            guard let text = pending[kind], !text.isEmpty else {
                continue
            }

            addLogEntry(kind: kind, text: text)
        }
    }

    private func addLogEntry(kind: CommandLogKind, text: String) {
        actionLogs.append(
            CommandLogEntry(
                id: nextLogIdentifier,
                kind: kind,
                text: text,
                timestamp: Date()
            )
        )
        nextLogIdentifier += 1
    }

    private func renderLogLine(_ entry: CommandLogEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: entry.timestamp))] \(entry.kind.rawValue.uppercased())  \(entry.text)"
    }
}

extension MaintenanceViewModel {
    static func live() -> MaintenanceViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)

        return MaintenanceViewModel(
            provider: BrewMaintenanceProvider(
                brewLocator: brewLocator,
                runner: runner
            ),
            commandExecutor: BrewCommandExecutor(
                brewLocator: brewLocator,
                runner: runner
            )
        )
    }
}
