import Foundation

struct HomebrewCompatibilityDetector: @unchecked Sendable {
    private let runner: any CommandRunning

    init(runner: any CommandRunning) {
        self.runner = runner
    }

    func detect(
        executable: String,
        version: String
    ) async -> HomebrewCompatibilitySnapshot {
        let fallback = HomebrewCompatibilitySnapshot.modernDefault(version: version)

        async let infoHelp = helpOutput(executable: executable, arguments: ["info", "--help"])
        async let outdatedHelp = helpOutput(executable: executable, arguments: ["outdated", "--help"])
        async let tapInfoHelp = helpOutput(executable: executable, arguments: ["tap-info", "--help"])
        async let servicesHelp = helpOutput(executable: executable, arguments: ["help", "services"])
        async let bundleHelp = helpOutput(executable: executable, arguments: ["help", "bundle"])

        return await Self.snapshot(
            version: version,
            infoHelp: infoHelp ?? "",
            outdatedHelp: outdatedHelp ?? "",
            tapInfoHelp: tapInfoHelp ?? "",
            servicesHelp: servicesHelp ?? "",
            bundleHelp: bundleHelp ?? "",
            fallback: fallback
        )
    }

    private func helpOutput(
        executable: String,
        arguments: [String]
    ) async -> String? {
        guard let result = try? await runner.run(executable: executable, arguments: arguments) else {
            return nil
        }

        return [result.stdout, result.stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    static func snapshot(
        version: String,
        infoHelp: String,
        outdatedHelp: String,
        tapInfoHelp: String,
        servicesHelp: String,
        bundleHelp: String,
        fallback: HomebrewCompatibilitySnapshot? = nil
    ) -> HomebrewCompatibilitySnapshot {
        let base = fallback ?? .modernDefault(version: version)
        let parsedVersion = HomebrewVersion(parsing: version)
        let normalizedInfoHelp = normalizeWhitespace(in: infoHelp)
        let normalizedOutdatedHelp = normalizeWhitespace(in: outdatedHelp)
        let normalizedTapInfoHelp = normalizeWhitespace(in: tapInfoHelp)
        let normalizedServicesHelp = normalizeWhitespace(in: servicesHelp)
        let normalizedBundleHelp = normalizeWhitespace(in: bundleHelp)

        return HomebrewCompatibilitySnapshot(
            version: parsedVersion,
            infoJSONArgument: infoHelp.isEmpty
                ? base.infoJSONArgument
                : detectInfoJSONArgument(in: normalizedInfoHelp),
            outdatedJSONArgument: outdatedHelp.isEmpty
                ? base.outdatedJSONArgument
                : detectOutdatedJSONArgument(in: normalizedOutdatedHelp),
            tapInfoJSONArgument: tapInfoHelp.isEmpty
                ? base.tapInfoJSONArgument
                : (detectTapInfoJSONArgument(in: normalizedTapInfoHelp) ?? base.tapInfoJSONArgument),
            servicesListSupportsJSON: servicesHelp.isEmpty
                ? base.servicesListSupportsJSON
                : detectServicesJSONSupport(in: normalizedServicesHelp, subcommand: "list"),
            servicesInfoSupportsJSON: servicesHelp.isEmpty
                ? base.servicesInfoSupportsJSON
                : detectServicesJSONSupport(in: normalizedServicesHelp, subcommand: "info"),
            bundleSupportsNoUpgrade: bundleHelp.isEmpty
                ? base.bundleSupportsNoUpgrade
                : detectBundleSupport(in: normalizedBundleHelp, token: "--no-upgrade"),
            bundleSupportsFormulaDump: bundleHelp.isEmpty
                ? base.bundleSupportsFormulaDump
                : detectBundleSupport(in: normalizedBundleHelp, token: "--formula"),
            bundleSupportsCaskDump: bundleHelp.isEmpty
                ? base.bundleSupportsCaskDump
                : detectBundleSupport(in: normalizedBundleHelp, token: "--cask"),
            supportedBundleAddKinds: detectSupportedBundleAddKinds(in: normalizedBundleHelp, fallback: base.supportedBundleAddKinds),
            supportedBundleRemoveKinds: detectSupportedBundleRemoveKinds(in: normalizedBundleHelp, fallback: base.supportedBundleRemoveKinds)
        )
    }

    private static func detectInfoJSONArgument(in help: String) -> HomebrewJSONArgument? {
        guard help.contains("--json") else {
            return nil
        }

        if help.localizedCaseInsensitiveContains("use v2") || help.contains("--json=v2") {
            return .versioned("v2")
        }

        return .plain
    }

    private static func detectOutdatedJSONArgument(in help: String) -> HomebrewJSONArgument? {
        if help.localizedCaseInsensitiveContains("v2 prints outdated formulae and") {
            return .versioned("v2")
        }

        return nil
    }

    private static func detectTapInfoJSONArgument(in help: String) -> HomebrewJSONArgument? {
        guard help.contains("--json") else {
            return nil
        }

        if help.localizedCaseInsensitiveContains("only accepted value for version is v1") || help.contains("--json=v1") {
            return .versioned("v1")
        }

        return .plain
    }

    private static func detectServicesJSONSupport(
        in help: String,
        subcommand: String
    ) -> Bool {
        let normalizedSubcommand = subcommand.lowercased()

        switch normalizedSubcommand {
        case "list":
            return help.localizedCaseInsensitiveContains("brew services [list] [--json]") ||
                help.localizedCaseInsensitiveContains("brew services list [--json]") ||
                help.localizedCaseInsensitiveContains("brew services [list]") && help.localizedCaseInsensitiveContains("[--json]")
        case "info":
            return help.localizedCaseInsensitiveContains("brew services info") &&
                help.localizedCaseInsensitiveContains("[--json]")
        default:
            return false
        }
    }

    private static func detectBundleSupport(in help: String, token: String) -> Bool {
        help.contains(token)
    }

    private static func detectSupportedBundleAddKinds(
        in help: String,
        fallback: Set<BrewfileEntryKind>
    ) -> Set<BrewfileEntryKind> {
        detectSupportedBundleKinds(
            in: help,
            fallback: fallback,
            flagProvider: \.bundleAddFlag,
            includeFormulaByDefault: help.localizedCaseInsensitiveContains("Adds formulae by default")
        )
    }

    private static func detectSupportedBundleRemoveKinds(
        in help: String,
        fallback: Set<BrewfileEntryKind>
    ) -> Set<BrewfileEntryKind> {
        detectSupportedBundleKinds(
            in: help,
            fallback: fallback,
            flagProvider: \.bundleRemoveFlag,
            includeFormulaByDefault: false
        )
    }

    private static func detectSupportedBundleKinds(
        in help: String,
        fallback: Set<BrewfileEntryKind>,
        flagProvider: (BrewfileEntryKind) -> String?,
        includeFormulaByDefault: Bool
    ) -> Set<BrewfileEntryKind> {
        let detectedKinds = Set(
            BrewfileEntryKind.allCases.filter { kind in
                guard let flag = flagProvider(kind) else {
                    return includeFormulaByDefault && kind == .brew
                }

                return help.contains(flag)
            }
        )

        return detectedKinds.isEmpty ? fallback : detectedKinds
    }

    private static func normalizeWhitespace(in string: String) -> String {
        string
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
