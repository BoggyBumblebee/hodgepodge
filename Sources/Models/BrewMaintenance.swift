import Foundation

enum BrewMaintenanceTask: String, CaseIterable, Identifiable, Equatable, Sendable {
    case update
    case doctor
    case config
    case cleanup
    case autoremove

    var id: String { rawValue }

    var title: String {
        switch self {
        case .update:
            "Update"
        case .doctor:
            "Doctor"
        case .config:
            "Config"
        case .cleanup:
            "Cleanup"
        case .autoremove:
            "Autoremove"
        }
    }

    var subtitle: String {
        switch self {
        case .update:
            "Fetch the latest Homebrew metadata and tap changes."
        case .doctor:
            "Run Homebrew diagnostics and review warnings."
        case .config:
            "Inspect the active Homebrew environment on this Mac."
        case .cleanup:
            "Remove old downloads and stale cached artifacts."
        case .autoremove:
            "Remove unneeded dependencies that are no longer required."
        }
    }

    var systemImageName: String {
        switch self {
        case .update:
            "arrow.clockwise.circle"
        case .doctor:
            "stethoscope"
        case .config:
            "gearshape.2"
        case .cleanup:
            "trash"
        case .autoremove:
            "shippingbox.circle"
        }
    }

    var actionLabel: String {
        switch self {
        case .update:
            "Run Update"
        case .doctor:
            "Run Doctor"
        case .config:
            "Refresh Config"
        case .cleanup:
            "Run Cleanup"
        case .autoremove:
            "Run Autoremove"
        }
    }

    var arguments: [String] {
        switch self {
        case .update:
            ["update"]
        case .doctor:
            ["doctor"]
        case .config:
            ["config"]
        case .cleanup:
            ["cleanup"]
        case .autoremove:
            ["autoremove"]
        }
    }

    var requiresConfirmation: Bool {
        switch self {
        case .cleanup, .autoremove:
            true
        case .update, .doctor, .config:
            false
        }
    }

    var confirmationTitle: String {
        "\(title)?"
    }

    var confirmationMessage: String {
        switch self {
        case .cleanup:
            "Hodgepodge will run `brew cleanup` and remove stale downloads and cached artifacts from your local Homebrew installation."
        case .autoremove:
            "Hodgepodge will run `brew autoremove` and remove unneeded dependencies from your local Homebrew installation."
        case .update, .doctor, .config:
            "Hodgepodge will run `brew \(arguments.joined(separator: " "))` using your local Homebrew installation."
        }
    }
}

struct BrewMaintenanceActionCommand: Equatable, Sendable {
    let task: BrewMaintenanceTask
    let arguments: [String]

    var command: String {
        "brew \(arguments.joined(separator: " "))"
    }
}

typealias BrewMaintenanceActionProgress = CommandExecutionProgress<BrewMaintenanceActionCommand>
typealias BrewMaintenanceActionState = CommandExecutionState<BrewMaintenanceActionCommand>

struct BrewMaintenanceDashboard: Equatable, Sendable {
    let config: BrewConfigSnapshot
    let doctor: BrewDoctorSnapshot
    let cleanup: BrewMaintenanceDryRunSnapshot
    let autoremove: BrewMaintenanceDryRunSnapshot
    let capturedAt: Date

    var summaryMetrics: [BrewMaintenanceMetric] {
        [
            BrewMaintenanceMetric(title: "Warnings", value: "\(doctor.warningCount)", accent: doctor.warningCount == 0 ? .positive : .caution),
            BrewMaintenanceMetric(title: "Cleanup Items", value: "\(cleanup.itemCount)", accent: cleanup.itemCount == 0 ? .neutral : .caution),
            BrewMaintenanceMetric(title: "Autoremove Items", value: "\(autoremove.itemCount)", accent: autoremove.itemCount == 0 ? .neutral : .caution),
            BrewMaintenanceMetric(title: "Brew", value: config.version ?? "Unknown", accent: .neutral)
        ]
    }
}

struct BrewMaintenanceMetric: Identifiable, Equatable, Sendable {
    enum Accent: String, Equatable, Sendable {
        case neutral
        case positive
        case caution
    }

    let title: String
    let value: String
    let accent: Accent

    var id: String {
        title
    }
}

struct BrewConfigSnapshot: Equatable, Sendable {
    let values: [String: String]
    let rawOutput: String

    var version: String? {
        values["HOMEBREW_VERSION"]
    }

    var prefix: String? {
        values["HOMEBREW_PREFIX"]
    }

    var macOS: String? {
        values["macOS"]
    }

    var xcode: String? {
        values["Xcode"]
    }

    var summaryRows: [BrewMaintenanceDetailRow] {
        [
            BrewMaintenanceDetailRow(title: "Version", value: version),
            BrewMaintenanceDetailRow(title: "Prefix", value: prefix),
            BrewMaintenanceDetailRow(title: "macOS", value: macOS),
            BrewMaintenanceDetailRow(title: "Xcode", value: xcode),
            BrewMaintenanceDetailRow(title: "Branch", value: values["Branch"]),
            BrewMaintenanceDetailRow(title: "Core Tap JSON", value: values["Core tap JSON"])
        ].compactMap { $0.value == nil ? nil : $0 }
    }
}

struct BrewDoctorSnapshot: Equatable, Sendable {
    let warningCount: Int
    let warnings: [String]
    let rawOutput: String

    var statusTitle: String {
        warningCount == 0 ? "Healthy" : "\(warningCount) warning" + (warningCount == 1 ? "" : "s")
    }

    var summaryText: String {
        if warningCount == 0 {
            return "Homebrew doctor did not report any warnings in the latest snapshot."
        }

        return warnings.first ?? "Homebrew doctor reported warnings."
    }
}

struct BrewMaintenanceDryRunSnapshot: Equatable, Sendable {
    let task: BrewMaintenanceTask
    let itemCount: Int
    let spaceFreedEstimate: String?
    let warnings: [String]
    let items: [String]
    let rawOutput: String

    var statusTitle: String {
        itemCount == 0 ? "Nothing queued" : "\(itemCount) item" + (itemCount == 1 ? "" : "s")
    }

    var summaryText: String {
        if let warning = warnings.first {
            return warning
        }

        if let spaceFreedEstimate, itemCount > 0 {
            return "Would free \(spaceFreedEstimate)."
        }

        return itemCount == 0
            ? "No items are currently queued for \(task.rawValue)."
            : items.first ?? "Homebrew found items to remove."
    }
}

struct BrewMaintenanceDetailRow: Identifiable, Equatable, Sendable {
    let title: String
    let value: String?

    var id: String {
        title
    }
}

enum BrewMaintenanceOutputSource: String, CaseIterable, Identifiable, Equatable, Sendable {
    case liveAction
    case config
    case doctor
    case cleanup
    case autoremove

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liveAction:
            "Live Action"
        case .config:
            "Config"
        case .doctor:
            "Doctor"
        case .cleanup:
            "Cleanup Preview"
        case .autoremove:
            "Autoremove Preview"
        }
    }
}

enum BrewMaintenanceLoadState: Equatable {
    case idle
    case loading
    case loaded(BrewMaintenanceDashboard)
    case failed(String)
}

enum BrewMaintenanceParser {
    static func configSnapshot(from output: String) -> BrewConfigSnapshot {
        let values = output
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: String]()) { result, line in
                let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2 else {
                    return
                }

                result[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
            }

        return BrewConfigSnapshot(values: values, rawOutput: output)
    }

    static func doctorSnapshot(from output: String) -> BrewDoctorSnapshot {
        let warnings = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { $0.hasPrefix("Warning:") }
            .map { line in
                line.replacingOccurrences(of: "Warning:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

        return BrewDoctorSnapshot(
            warningCount: warnings.count,
            warnings: warnings,
            rawOutput: output
        )
    }

    static func dryRunSnapshot(task: BrewMaintenanceTask, from output: String) -> BrewMaintenanceDryRunSnapshot {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        let warnings = lines
            .filter { $0.hasPrefix("Warning:") }
            .map {
                $0.replacingOccurrences(of: "Warning:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        let items = lines
            .filter { $0.hasPrefix("Would remove:") || $0.hasPrefix("Removing:") }
            .map { line in
                line
                    .replacingOccurrences(of: "Would remove:", with: "")
                    .replacingOccurrences(of: "Removing:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        let spaceFreedEstimate = lines.last(where: { $0.localizedCaseInsensitiveContains("disk space") })
            .flatMap(extractSpaceFreed(from:))

        return BrewMaintenanceDryRunSnapshot(
            task: task,
            itemCount: items.count,
            spaceFreedEstimate: spaceFreedEstimate,
            warnings: warnings,
            items: items,
            rawOutput: output
        )
    }

    private static func extractSpaceFreed(from line: String) -> String? {
        guard let range = line.range(of: "approximately ", options: .caseInsensitive),
              let endRange = line.range(of: " of disk space", options: .caseInsensitive) else {
            return nil
        }

        return String(line[range.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
