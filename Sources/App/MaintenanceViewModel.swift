import Foundation

@MainActor
final class MaintenanceViewModel: ObservableObject {
    @Published var dashboardState: BrewMaintenanceLoadState = .idle
    @Published var selectedOutputSource: BrewMaintenanceOutputSource = .doctor
    @Published var actionState: BrewMaintenanceActionState = .idle
    @Published var actionLogs: [CommandLogEntry] = []

    private let provider: any BrewMaintenanceProviding
    private let commandExecutor: any BrewCommandExecuting
    private let notificationScheduler: any CommandNotificationScheduling
    private var actionTask: Task<Void, Never>?
    private var logBuffer = CommandLogBuffer()

    init(
        provider: any BrewMaintenanceProviding,
        commandExecutor: any BrewCommandExecuting,
        notificationScheduler: any CommandNotificationScheduling = NullCommandNotificationScheduler()
    ) {
        self.provider = provider
        self.commandExecutor = commandExecutor
        self.notificationScheduler = notificationScheduler
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
                await notifyActionSucceeded(task: task)
                reloadDashboardAfterAction()
            } catch is CancellationError {
                flushPendingLogs()
                appendLog(.system, "\(task.title) cancelled.")
                actionState = .cancelled(progress.finished(at: Date()))
                await notifyActionCancelled(task: task)
            } catch {
                flushPendingLogs()
                appendLog(.system, error.localizedDescription)
                actionState = .failed(progress.finished(at: Date()), error.localizedDescription)
                await notifyActionFailed(task: task, error: error)
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
        logBuffer.reset()
        actionLogs = []
    }

    private func appendLog(_ kind: CommandLogKind, _ text: String) {
        logBuffer.append(kind, text)
        actionLogs = logBuffer.entries
    }

    private func flushPendingLogs() {
        logBuffer.flush()
        actionLogs = logBuffer.entries
    }

    private func renderLogLine(_ entry: CommandLogEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: entry.timestamp))] \(entry.kind.rawValue.uppercased())  \(entry.text)"
    }

    private func notifyActionSucceeded(task: BrewMaintenanceTask) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(task.title) Complete",
                body: "\(task.title) completed successfully."
            )
        )
    }

    private func notifyActionCancelled(task: BrewMaintenanceTask) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(task.title) Cancelled",
                body: "\(task.title) was cancelled before it finished."
            )
        )
    }

    private func notifyActionFailed(
        task: BrewMaintenanceTask,
        error: Error
    ) async {
        await notificationScheduler.schedule(
            CommandNotification(
                title: "\(task.title) Failed",
                body: CommandPresentation.friendlyFailureDescription(
                    error.localizedDescription,
                    fallback: "\(task.title) couldn’t be completed."
                )
            )
        )
    }
}

extension MaintenanceViewModel {
    static func live(
        notificationScheduler: any CommandNotificationScheduling = CommandNotificationScheduler.live()
    ) -> MaintenanceViewModel {
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
            ),
            notificationScheduler: notificationScheduler
        )
    }
}
