import Foundation

struct BrewfileDumpCommand: Equatable, Sendable {
    let scope: CatalogScope
    let destinationURL: URL

    var arguments: [String] {
        var arguments = ["bundle", "dump", "--file", destinationURL.path, "--force"]

        switch scope {
        case .all:
            break
        case .formula:
            arguments.append("--formula")
        case .cask:
            arguments.append("--cask")
        }

        return arguments
    }

    var command: String {
        "brew \(arguments.joined(separator: " "))"
    }

    var title: String {
        "Generate Brewfile"
    }

    var scopeDescription: String {
        switch scope {
        case .all:
            "Export Homebrew's full installed Brewfile snapshot, including taps when Homebrew includes them."
        case .formula:
            "Export only installed formulae to a Brewfile."
        case .cask:
            "Export only installed casks to a Brewfile."
        }
    }

    var suggestedFileName: String {
        switch scope {
        case .all:
            "Brewfile"
        case .formula:
            "Brewfile-formulae"
        case .cask:
            "Brewfile-casks"
        }
    }
}

typealias InstalledPackagesBrewfileExportCommand = BrewfileDumpCommand
typealias InstalledPackagesBrewfileExportProgress = CommandExecutionProgress<BrewfileDumpCommand>
typealias InstalledPackagesBrewfileExportState = CommandExecutionState<BrewfileDumpCommand>
