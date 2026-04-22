import Foundation

enum HomebrewCompatibilityError: LocalizedError, Equatable {
    case unsupportedInstalledJSON(version: String)
    case unsupportedOutdatedJSON(version: String)
    case unsupportedServicesJSON(version: String)
    case unsupportedBundleCheckNoUpgrade(version: String)
    case unsupportedBundleDumpScope(scope: CatalogScope, version: String)
    case unsupportedBundleAdd(kind: BrewfileEntryKind, version: String)
    case unsupportedBundleRemove(kind: BrewfileEntryKind, version: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedInstalledJSON(let version):
            "Homebrew \(version) doesn’t expose the installed-package JSON format Hodgepodge needs."
        case .unsupportedOutdatedJSON(let version):
            "Homebrew \(version) doesn’t expose the outdated-package JSON format Hodgepodge needs."
        case .unsupportedServicesJSON(let version):
            "Homebrew \(version) doesn’t expose JSON output for services."
        case .unsupportedBundleCheckNoUpgrade(let version):
            "Homebrew \(version) doesn’t support the Brewfile check flags Hodgepodge expects."
        case .unsupportedBundleDumpScope(let scope, let version):
            "Homebrew \(version) can’t export a Brewfile limited to \(scope.title.lowercased())."
        case .unsupportedBundleAdd(let kind, let version):
            "Homebrew \(version) can’t add \(kind.title.lowercased()) entries through brew bundle."
        case .unsupportedBundleRemove(let kind, let version):
            "Homebrew \(version) can’t remove \(kind.title.lowercased()) entries through brew bundle."
        }
    }
}

struct HomebrewVersion: Equatable, Comparable, Sendable {
    let rawValue: String
    private let components: [Int]

    init(rawValue: String, components: [Int]) {
        self.rawValue = rawValue
        self.components = components
    }

    init(parsing string: String) {
        let rawValue = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let numericPortion = rawValue
            .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .first(where: { !$0.isEmpty }) ?? rawValue

        let components = numericPortion
            .split(separator: ".")
            .compactMap { Int($0) }

        self.init(rawValue: rawValue, components: components.isEmpty ? [0] : components)
    }

    static func < (lhs: HomebrewVersion, rhs: HomebrewVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)

        for index in 0..<maxCount {
            let lhsValue = lhs.components.indices.contains(index) ? lhs.components[index] : 0
            let rhsValue = rhs.components.indices.contains(index) ? rhs.components[index] : 0

            if lhsValue != rhsValue {
                return lhsValue < rhsValue
            }
        }

        return false
    }
}

enum HomebrewJSONArgument: Equatable, Sendable {
    case plain
    case versioned(String)

    var option: String {
        switch self {
        case .plain:
            "--json"
        case .versioned(let version):
            "--json=\(version)"
        }
    }
}

struct HomebrewCompatibilitySnapshot: Equatable, Sendable {
    let version: HomebrewVersion
    let infoJSONArgument: HomebrewJSONArgument?
    let outdatedJSONArgument: HomebrewJSONArgument?
    let tapInfoJSONArgument: HomebrewJSONArgument
    let servicesListSupportsJSON: Bool
    let servicesInfoSupportsJSON: Bool
    let bundleSupportsNoUpgrade: Bool
    let bundleSupportsFormulaDump: Bool
    let bundleSupportsCaskDump: Bool
    let supportedBundleAddKinds: Set<BrewfileEntryKind>
    let supportedBundleRemoveKinds: Set<BrewfileEntryKind>

    static func modernDefault(version: String) -> HomebrewCompatibilitySnapshot {
        let parsedVersion = HomebrewVersion(parsing: version)

        return HomebrewCompatibilitySnapshot(
            version: parsedVersion,
            infoJSONArgument: .versioned("v2"),
            outdatedJSONArgument: .versioned("v2"),
            tapInfoJSONArgument: .versioned("v1"),
            servicesListSupportsJSON: true,
            servicesInfoSupportsJSON: true,
            bundleSupportsNoUpgrade: true,
            bundleSupportsFormulaDump: true,
            bundleSupportsCaskDump: true,
            supportedBundleAddKinds: Set(BrewfileEntryKind.addableCases),
            supportedBundleRemoveKinds: Set(BrewfileEntryKind.allCases.filter(\.supportsBundleRemove))
        )
    }

    func installedInfoArguments() throws -> [String] {
        guard let infoJSONArgument else {
            throw HomebrewCompatibilityError.unsupportedInstalledJSON(version: version.rawValue)
        }

        return ["info", infoJSONArgument.option, "--installed"]
    }

    func outdatedArguments() throws -> [String] {
        guard let outdatedJSONArgument else {
            throw HomebrewCompatibilityError.unsupportedOutdatedJSON(version: version.rawValue)
        }

        return ["outdated", outdatedJSONArgument.option]
    }

    func tapInfoArguments(for tapNames: [String]) -> [String] {
        ["tap-info", tapInfoJSONArgument.option] + tapNames
    }

    func validateServicesJSONSupport() throws {
        guard servicesListSupportsJSON, servicesInfoSupportsJSON else {
            throw HomebrewCompatibilityError.unsupportedServicesJSON(version: version.rawValue)
        }
    }

    func normalized(arguments: [String]) throws -> [String] {
        guard arguments.count >= 2 else {
            return arguments
        }

        if arguments[0] == "bundle" {
            return try normalizeBundleArguments(arguments)
        }

        return arguments
    }

    private func normalizeBundleArguments(_ arguments: [String]) throws -> [String] {
        guard let subcommand = arguments[safe: 1] else {
            return arguments
        }

        switch subcommand {
        case "check":
            if arguments.contains("--no-upgrade"), !bundleSupportsNoUpgrade {
                throw HomebrewCompatibilityError.unsupportedBundleCheckNoUpgrade(version: version.rawValue)
            }
            return arguments
        case "dump":
            if arguments.contains("--formula"), !bundleSupportsFormulaDump {
                throw HomebrewCompatibilityError.unsupportedBundleDumpScope(scope: .formula, version: version.rawValue)
            }
            if arguments.contains("--cask"), !bundleSupportsCaskDump {
                throw HomebrewCompatibilityError.unsupportedBundleDumpScope(scope: .cask, version: version.rawValue)
            }
            return arguments
        case "add":
            guard let unsupportedKind = unsupportedBundleKind(
                in: arguments,
                commandKind: .add,
                supportedKinds: supportedBundleAddKinds
            ) else {
                return arguments
            }
            throw HomebrewCompatibilityError.unsupportedBundleAdd(kind: unsupportedKind, version: version.rawValue)
        case "remove":
            guard let unsupportedKind = unsupportedBundleKind(
                in: arguments,
                commandKind: .remove,
                supportedKinds: supportedBundleRemoveKinds
            ) else {
                return arguments
            }
            throw HomebrewCompatibilityError.unsupportedBundleRemove(kind: unsupportedKind, version: version.rawValue)
        default:
            return arguments
        }
    }

    private func unsupportedBundleKind(
        in arguments: [String],
        commandKind: BrewfileActionKind,
        supportedKinds: Set<BrewfileEntryKind>
    ) -> BrewfileEntryKind? {
        for kind in BrewfileEntryKind.allCases {
            let flag: String? = switch commandKind {
            case .add:
                kind.bundleAddFlag
            case .remove:
                kind.bundleRemoveFlag
            default:
                nil
            }

            guard let flag, arguments.contains(flag), !supportedKinds.contains(kind) else {
                continue
            }

            return kind
        }

        let containsExplicitAddKindFlag = arguments.contains { argument in
            BrewfileEntryKind.allCases.contains { kind in
                kind.bundleAddFlag == argument
            }
        }

        if commandKind == .add, !supportedKinds.contains(.brew), !containsExplicitAddKindFlag {
            return .brew
        }

        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
