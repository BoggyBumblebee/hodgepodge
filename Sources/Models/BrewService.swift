import Foundation

struct BrewService: Identifiable, Equatable, Hashable, Sendable {
    let name: String
    let serviceName: String
    let status: String
    let isRunning: Bool
    let isLoaded: Bool
    let isSchedulable: Bool
    let pid: Int?
    let exitCode: Int?
    let user: String?
    let file: String?
    let isRegistered: Bool
    let loadedFile: String?
    let command: String?
    let workingDirectory: String?
    let rootDirectory: String?
    let logPath: String?
    let errorLogPath: String?
    let interval: String?
    let cron: String?

    var id: String { serviceName }

    var title: String {
        name
    }

    var subtitle: String {
        if serviceName == name {
            return file ?? serviceName
        }

        return serviceName
    }

    var statusTitle: String {
        switch status.lowercased() {
        case "started":
            "Started"
        case "scheduled":
            "Scheduled"
        case "error":
            "Error"
        case "none":
            "Stopped"
        default:
            status.capitalized
        }
    }

    var statusBadges: [String] {
        var badges: [String] = [statusTitle]
        if isRunning {
            badges.append("Running")
        }
        if isLoaded {
            badges.append("Loaded")
        }
        if isRegistered {
            badges.append("Registered")
        }
        if isSchedulable {
            badges.append("Schedulable")
        }
        if let exitCode {
            badges.append("Exit \(exitCode)")
        }
        return badges
    }

    var summaryRows: [BrewServiceDetailRow] {
        [
            BrewServiceDetailRow(title: "User", value: user ?? "Unavailable"),
            BrewServiceDetailRow(title: "PID", value: pid.map(String.init) ?? "Not running"),
            BrewServiceDetailRow(title: "Loaded", value: yesNo(isLoaded)),
            BrewServiceDetailRow(title: "Registered", value: yesNo(isRegistered)),
            BrewServiceDetailRow(title: "Schedulable", value: yesNo(isSchedulable))
        ]
    }

    var locationRows: [BrewServiceDetailRow] {
        [
            BrewServiceDetailRow(title: "Plist", value: file ?? "Unavailable"),
            BrewServiceDetailRow(title: "Loaded Plist", value: loadedFile ?? "Unavailable"),
            BrewServiceDetailRow(title: "Working Directory", value: workingDirectory ?? "Unavailable"),
            BrewServiceDetailRow(title: "Root Directory", value: rootDirectory ?? "Unavailable"),
            BrewServiceDetailRow(title: "Log Path", value: logPath ?? "Unavailable"),
            BrewServiceDetailRow(title: "Error Log Path", value: errorLogPath ?? "Unavailable")
        ]
    }

    var scheduleRows: [BrewServiceDetailRow] {
        [
            BrewServiceDetailRow(title: "Interval", value: interval ?? "None"),
            BrewServiceDetailRow(title: "Cron", value: cron ?? "None")
        ]
    }

    var availableActions: [BrewServiceActionKind] {
        if isRunning {
            return [.restart, .stop]
        }
        return [.start]
    }

    func command(for action: BrewServiceActionKind) -> BrewServiceActionCommand {
        BrewServiceActionCommand(
            kind: action,
            serviceID: id,
            serviceName: name,
            displayName: title,
            arguments: ["services", action.rawValue, name]
        )
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }
}

struct BrewServiceDetailRow: Identifiable, Equatable, Sendable {
    let title: String
    let value: String

    var id: String {
        title
    }
}

enum BrewServiceFilterOption: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case running
    case loaded
    case registered
    case failed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .running:
            "Running"
        case .loaded:
            "Loaded"
        case .registered:
            "Registered"
        case .failed:
            "Needs Attention"
        }
    }
}

enum BrewServiceSortOption: String, CaseIterable, Equatable, Identifiable, Sendable {
    case name
    case status
    case user
    case processID

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            "Name"
        case .status:
            "Status"
        case .user:
            "User"
        case .processID:
            "Process ID"
        }
    }
}

struct BrewServiceStateCount: Identifiable, Equatable, Sendable {
    let title: String
    let count: Int

    var id: String {
        title
    }
}

enum BrewServiceActionKind: String, CaseIterable, Equatable, Identifiable, Sendable {
    case start
    case stop
    case restart

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var requiresConfirmation: Bool {
        switch self {
        case .start:
            false
        case .stop, .restart:
            true
        }
    }
}

struct BrewServiceActionCommand: Equatable, Sendable {
    let kind: BrewServiceActionKind
    let serviceID: String
    let serviceName: String
    let displayName: String
    let arguments: [String]

    var command: String {
        "brew \(arguments.joined(separator: " "))"
    }

    var confirmationTitle: String {
        "\(kind.title) \(displayName)?"
    }

    var confirmationMessage: String {
        "Hodgepodge will run `\(command)` using your local Homebrew installation."
    }
}

typealias BrewServiceActionProgress = CommandExecutionProgress<BrewServiceActionCommand>
typealias BrewServiceActionState = CommandExecutionState<BrewServiceActionCommand>
