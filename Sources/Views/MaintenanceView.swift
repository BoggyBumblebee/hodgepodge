import SwiftUI

struct MaintenanceView: View {
    @ObservedObject var viewModel: MaintenanceViewModel
    @State private var pendingAction: BrewMaintenanceTask?

    var body: some View {
        HSplitView {
            dashboardPane
                .frame(minWidth: 480, idealWidth: 620, maxWidth: 760)

            outputPane
                .frame(minWidth: 360, idealWidth: 460, maxWidth: .infinity)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            viewModel.loadIfNeeded()
        }
        .confirmationDialog(
            pendingAction?.confirmationTitle ?? "Confirm Maintenance Action",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingAction = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingAction {
                Button(pendingAction.actionLabel, role: .destructive) {
                    viewModel.runAction(pendingAction)
                    self.pendingAction = nil
                }
            }

            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
        } message: {
            Text(pendingAction?.confirmationMessage ?? "")
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("Output Source", selection: $viewModel.selectedOutputSource) {
                    ForEach(BrewMaintenanceOutputSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    viewModel.refreshDashboard()
                } label: {
                    Label("Refresh Snapshot", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }

    @ViewBuilder
    private var dashboardPane: some View {
        switch viewModel.dashboardState {
        case .idle, .loading:
            ProgressView("Loading maintenance snapshot...")
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)

        case .failed(let message):
            ContentUnavailableView(
                "Maintenance Dashboard Unavailable",
                systemImage: "stethoscope",
                description: Text(message)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)

        case .loaded(let dashboard):
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(dashboard: dashboard)
                    metricGrid(metrics: dashboard.summaryMetrics)
                    actionGrid
                    doctorCard(snapshot: dashboard.doctor)
                    dryRunCard(snapshot: dashboard.cleanup)
                    dryRunCard(snapshot: dashboard.autoremove)
                    configCard(snapshot: dashboard.config)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var outputPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review dry-run snapshots or live command logs from maintenance actions.")
                .foregroundStyle(.secondary)

            if let progress = viewModel.actionState.progress {
                maintenanceStatusCard(progress: progress, state: viewModel.actionState)
            }

            GroupBox {
                ScrollView {
                    Text(viewModel.outputText(for: viewModel.selectedOutputSource))
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } label: {
                Label(viewModel.selectedOutputSource.title, systemImage: "terminal")
            }

            HStack {
                if viewModel.actionState.isRunning {
                    Button("Cancel Action") {
                        viewModel.cancelAction()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                Spacer()

                Button("Clear Live Output") {
                    viewModel.clearActionOutput()
                }
                .disabled(viewModel.actionLogs.isEmpty && viewModel.actionState == .idle)
            }
        }
        .padding(24)
    }

    private func header(dashboard: BrewMaintenanceDashboard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keep the local Homebrew environment healthy with diagnostics, previews, and careful maintenance actions.")
                .foregroundStyle(.secondary)

            Text("Last captured \(dashboard.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func metricGrid(metrics: [BrewMaintenanceMetric]) -> some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 120), spacing: 12)
        ], spacing: 12) {
            ForEach(metrics) { metric in
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(metric.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(metric.value)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(metricColor(metric.accent))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var actionGrid: some View {
        GroupBox("Actions") {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180), spacing: 12)
            ], spacing: 12) {
                ForEach(BrewMaintenanceTask.allCases) { task in
                    Button {
                        runAction(task)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(task.title, systemImage: task.systemImageName)
                                .font(.headline)

                            Text(task.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(task.actionLabel)
                }
            }
        }
    }

    private func doctorCard(snapshot: BrewDoctorSnapshot) -> some View {
        GroupBox("Doctor") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(snapshot.statusTitle)
                        .font(.headline)
                    Spacer()
                    Text(snapshot.warningCount == 0 ? "Healthy" : "Needs Attention")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((snapshot.warningCount == 0 ? Color.green : Color.orange).opacity(0.15), in: Capsule())
                }

                Text(snapshot.summaryText)
                    .foregroundStyle(.secondary)

                if !snapshot.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(snapshot.warnings.prefix(5).enumerated()), id: \.offset) { _, warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .font(.callout)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dryRunCard(snapshot: BrewMaintenanceDryRunSnapshot) -> some View {
        GroupBox(snapshot.task.title + " Preview") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(snapshot.statusTitle)
                        .font(.headline)
                    Spacer()
                    if let estimate = snapshot.spaceFreedEstimate {
                        Text(estimate)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Text(snapshot.summaryText)
                    .foregroundStyle(.secondary)

                if !snapshot.items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(snapshot.items.prefix(4).enumerated()), id: \.offset) { _, item in
                            Text(item)
                                .font(.callout.monospaced())
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func configCard(snapshot: BrewConfigSnapshot) -> some View {
        GroupBox("Config") {
            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 140), alignment: .leading),
                GridItem(.flexible(minimum: 240), alignment: .leading)
            ], alignment: .leading, spacing: 10) {
                ForEach(snapshot.summaryRows) { row in
                    Text(row.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(row.value ?? "Unavailable")
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func maintenanceStatusCard(
        progress: BrewMaintenanceActionProgress,
        state: BrewMaintenanceActionState
    ) -> some View {
        GroupBox("Live Action") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(progress.command.task.title)
                        .font(.headline)
                    Spacer()
                    Text(statusTitle(for: state))
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())
                }

                CommandPreviewField(
                    title: "Executed Command",
                    command: progress.command.command,
                    copyAccessibilityLabel: "Copy maintenance command"
                )

                Text("Elapsed \(progress.elapsedTime(), format: .number.precision(.fractionLength(1)))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metricColor(_ accent: BrewMaintenanceMetric.Accent) -> Color {
        switch accent {
        case .neutral:
            .primary
        case .positive:
            .green
        case .caution:
            .orange
        }
    }

    private func statusTitle(for state: BrewMaintenanceActionState) -> String {
        switch state {
        case .idle:
            "Idle"
        case .running:
            "Running"
        case .succeeded:
            "Completed"
        case .failed:
            "Failed"
        case .cancelled:
            "Cancelled"
        }
    }

    private func runAction(_ task: BrewMaintenanceTask) {
        if task.requiresConfirmation {
            pendingAction = task
        } else {
            viewModel.runAction(task)
        }
    }
}
