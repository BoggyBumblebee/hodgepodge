import Foundation

enum BrewfileActionKind: String, CaseIterable, Identifiable, Equatable, Sendable {
    case check
    case install
    case dump

    var id: String { rawValue }

    var title: String {
        switch self {
        case .check:
            "Bundle Check"
        case .install:
            "Bundle Install"
        case .dump:
            "Bundle Dump"
        }
    }

    var actionLabel: String {
        switch self {
        case .check:
            "Run Check"
        case .install:
            "Install"
        case .dump:
            "Export Brewfile..."
        }
    }

    var subtitle: String {
        switch self {
        case .check:
            "Verify that every dependency in this Brewfile is installed on the current Mac."
        case .install:
            "Install and upgrade the dependencies declared in this Brewfile."
        case .dump:
            "Export Homebrew's current installed snapshot to a Brewfile."
        }
    }

    var systemImageName: String {
        switch self {
        case .check:
            "checklist"
        case .install:
            "square.and.arrow.down"
        case .dump:
            "square.and.arrow.up"
        }
    }

    var requiresConfirmation: Bool {
        switch self {
        case .check:
            false
        case .install:
            true
        case .dump:
            false
        }
    }
}

struct BrewfileActionCommand: Equatable, Sendable {
    let kind: BrewfileActionKind
    let fileURL: URL
    let arguments: [String]

    init(kind: BrewfileActionKind, fileURL: URL) {
        self.kind = kind
        self.fileURL = fileURL

        switch kind {
        case .check:
            self.arguments = ["bundle", "check", "--file", fileURL.path, "--verbose", "--no-upgrade"]
        case .install:
            self.arguments = ["bundle", "install", "--file", fileURL.path, "--verbose"]
        case .dump:
            self.arguments = BrewfileDumpCommand(
                scope: .all,
                destinationURL: fileURL
            ).arguments
        }
    }

    var command: String {
        "brew \(arguments.joined(separator: " "))"
    }

    var confirmationTitle: String {
        switch kind {
        case .check:
            return kind.title
        case .install:
            return "Install Brewfile Dependencies?"
        case .dump:
            return "Export Brewfile"
        }
    }

    var confirmationMessage: String {
        "Hodgepodge will run `\(command)` using your local Homebrew installation."
    }
}

typealias BrewfileActionProgress = CommandExecutionProgress<BrewfileActionCommand>
typealias BrewfileActionState = CommandExecutionState<BrewfileActionCommand>
