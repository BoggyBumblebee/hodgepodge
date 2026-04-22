import Foundation

enum BrewTapLoadState: Equatable {
    case idle
    case loading
    case loaded([BrewTap])
    case failed(String)
}

enum BrewTapSortOption: String, CaseIterable, Identifiable {
    case name
    case packageCount
    case lastCommit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            "Name"
        case .packageCount:
            "Package Count"
        case .lastCommit:
            "Last Commit"
        }
    }
}

enum BrewTapFilterOption: String, CaseIterable, Identifiable, Hashable {
    case official
    case customRemote
    case privateTap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .official:
            "Official"
        case .customRemote:
            "Custom Remote"
        case .privateTap:
            "Private"
        }
    }
}

struct BrewTap: Identifiable, Equatable, Hashable, Sendable {
    let name: String
    let user: String?
    let repo: String?
    let repository: String?
    let path: String
    let isOfficial: Bool
    let formulaNames: [String]
    let caskTokens: [String]
    let formulaFiles: [String]
    let caskFiles: [String]
    let commandFiles: [String]
    let remote: String?
    let customRemote: Bool
    let isPrivate: Bool
    let head: String?
    let lastCommit: String?
    let branch: String?

    var id: String { name }

    var title: String {
        name
    }

    var subtitle: String {
        remote ?? path
    }

    var packageCount: Int {
        formulaNames.count + caskTokens.count
    }

    var statusBadges: [String] {
        var badges: [String] = []
        if isOfficial {
            badges.append("Official")
        }
        if customRemote {
            badges.append("Custom Remote")
        }
        if isPrivate {
            badges.append("Private")
        }
        if let branch, !branch.isEmpty {
            badges.append(branch)
        }
        return badges
    }

    var summaryMetrics: [BrewTapMetric] {
        [
            BrewTapMetric(title: "Formulae", value: "\(formulaNames.count)"),
            BrewTapMetric(title: "Casks", value: "\(caskTokens.count)"),
            BrewTapMetric(title: "Commands", value: "\(commandFiles.count)"),
            BrewTapMetric(title: "Packages", value: "\(packageCount)")
        ]
    }

    var detailRows: [BrewTapDetailRow] {
        [
            BrewTapDetailRow(title: "Remote", value: remote),
            BrewTapDetailRow(title: "Path", value: path),
            BrewTapDetailRow(title: "Branch", value: branch),
            BrewTapDetailRow(title: "Last Commit", value: lastCommit),
            BrewTapDetailRow(title: "HEAD", value: head),
            BrewTapDetailRow(title: "Repository", value: repository)
        ]
        .compactMap { $0.value == nil ? nil : $0 }
    }
}

struct BrewTapMetric: Identifiable, Equatable, Sendable {
    let title: String
    let value: String

    var id: String {
        title
    }
}

struct BrewTapDetailRow: Identifiable, Equatable, Sendable {
    let title: String
    let value: String?

    var id: String {
        title
    }
}

enum BrewTapActionKind: String, CaseIterable, Equatable, Identifiable, Sendable {
    case add
    case untap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .add:
            "Add Tap"
        case .untap:
            "Untap"
        }
    }

    var requiresConfirmation: Bool {
        self == .untap
    }
}

enum BrewTapActionCommand: Equatable, Sendable {
    case add(name: String, remoteURL: String?)
    case untap(name: String, force: Bool)

    var kind: BrewTapActionKind {
        switch self {
        case .add:
            .add
        case .untap:
            .untap
        }
    }

    var tapName: String {
        switch self {
        case .add(let name, _), .untap(let name, _):
            name
        }
    }

    var command: String {
        "brew \(arguments.joined(separator: " "))"
    }

    var arguments: [String] {
        switch self {
        case .add(let name, let remoteURL):
            var arguments = ["tap", name]
            if let remoteURL, !remoteURL.isEmpty {
                arguments.append(remoteURL)
            }
            return arguments
        case .untap(let name, let force):
            var arguments = ["untap"]
            if force {
                arguments.append("--force")
            }
            arguments.append(name)
            return arguments
        }
    }

    var confirmationTitle: String {
        switch self {
        case .add(let name, _):
            "Add \(name)?"
        case .untap(let name, _):
            "Untap \(name)?"
        }
    }

    var confirmationMessage: String {
        "Hodgepodge will run `\(command)` using your local Homebrew installation."
    }
}

typealias BrewTapActionProgress = CommandExecutionProgress<BrewTapActionCommand>
typealias BrewTapActionState = CommandExecutionState<BrewTapActionCommand>
