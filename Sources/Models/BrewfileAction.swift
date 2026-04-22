import Foundation

enum BrewfileActionKind: String, CaseIterable, Identifiable, Equatable, Sendable {
    case check
    case install
    case dump
    case add
    case remove

    var id: String { rawValue }

    var title: String {
        switch self {
        case .check:
            "Bundle Check"
        case .install:
            "Bundle Install"
        case .dump:
            "Bundle Dump"
        case .add:
            "Bundle Add"
        case .remove:
            "Bundle Remove"
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
        case .add:
            "Add Entry"
        case .remove:
            "Remove Entry"
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
        case .add:
            "Add a new dependency entry to this Brewfile using Homebrew Bundle."
        case .remove:
            "Remove the selected dependency entry from this Brewfile using Homebrew Bundle."
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
        case .add:
            "plus.circle"
        case .remove:
            "minus.circle"
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
        case .add:
            false
        case .remove:
            true
        }
    }
}

struct BrewfileEntryDraft: Equatable, Sendable {
    var kind: BrewfileEntryKind = .brew
    var name = ""

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        kind.supportsBundleAdd && !trimmedName.isEmpty
    }

    func command(fileURL: URL) -> BrewfileActionCommand? {
        guard isValid else {
            return nil
        }

        return BrewfileActionCommand(
            kind: .add,
            fileURL: fileURL,
            entryName: trimmedName,
            entryKind: kind
        )
    }
}

struct BrewfileActionCommand: Equatable, Sendable {
    let kind: BrewfileActionKind
    let fileURL: URL
    let entryName: String?
    let entryKind: BrewfileEntryKind?
    let arguments: [String]

    init(
        kind: BrewfileActionKind,
        fileURL: URL,
        entryName: String? = nil,
        entryKind: BrewfileEntryKind? = nil
    ) {
        self.kind = kind
        self.fileURL = fileURL
        self.entryName = entryName
        self.entryKind = entryKind

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
        case .add:
            guard let entryName,
                  let entryKind,
                  entryKind.supportsBundleAdd else {
                preconditionFailure("Brewfile add commands require a supported entry name and kind.")
            }

            var arguments = ["bundle", "add"]
            if let kindFlag = entryKind.bundleAddFlag {
                arguments.append(kindFlag)
            }
            arguments.append(entryName)
            arguments.append(contentsOf: ["--file", fileURL.path])
            self.arguments = arguments
        case .remove:
            guard let entryName,
                  let entryKind,
                  let kindFlag = entryKind.bundleRemoveFlag else {
                preconditionFailure("Brewfile remove commands require a removable entry name and kind.")
            }

            self.arguments = ["bundle", "remove", kindFlag, entryName, "--file", fileURL.path]
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
        case .add:
            return "Add Brewfile Entry"
        case .remove:
            return "Remove Brewfile Entry?"
        }
    }

    var confirmationMessage: String {
        if let entryName {
            return "Hodgepodge will run `\(command)` to update the Brewfile entry for `\(entryName)`."
        }

        return "Hodgepodge will run `\(command)` using your local Homebrew installation."
    }
}

typealias BrewfileActionProgress = CommandExecutionProgress<BrewfileActionCommand>
typealias BrewfileActionState = CommandExecutionState<BrewfileActionCommand>
