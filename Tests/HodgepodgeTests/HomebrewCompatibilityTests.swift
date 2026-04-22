import XCTest
@testable import Hodgepodge

final class HomebrewCompatibilityTests: XCTestCase {
    func testHomebrewVersionParsingAndComparisonUseNumericComponents() {
        let stable = HomebrewVersion(parsing: "Homebrew 5.1.7")
        let newer = HomebrewVersion(parsing: "5.2")
        let patchRelease = HomebrewVersion(parsing: "5.1.7_1")

        XCTAssertEqual(stable.rawValue, "Homebrew 5.1.7")
        XCTAssertLessThan(stable, newer)
        XCTAssertFalse(stable < patchRelease)
        XCTAssertFalse(patchRelease < stable)
    }

    func testErrorDescriptionsRemainUserFriendly() {
        XCTAssertEqual(
            HomebrewCompatibilityError.unsupportedInstalledJSON(version: "4.0").errorDescription,
            "Homebrew 4.0 doesn’t expose the installed-package JSON format Hodgepodge needs."
        )
        XCTAssertEqual(
            HomebrewCompatibilityError.unsupportedOutdatedJSON(version: "4.0").errorDescription,
            "Homebrew 4.0 doesn’t expose the outdated-package JSON format Hodgepodge needs."
        )
        XCTAssertEqual(
            HomebrewCompatibilityError.unsupportedServicesJSON(version: "4.0").errorDescription,
            "Homebrew 4.0 doesn’t expose JSON output for services."
        )
        XCTAssertEqual(
            HomebrewCompatibilityError.unsupportedBundleCheckNoUpgrade(version: "4.0").errorDescription,
            "Homebrew 4.0 doesn’t support the Brewfile check flags Hodgepodge expects."
        )
        XCTAssertEqual(
            HomebrewCompatibilityError.unsupportedBundleDumpScope(scope: .formula, version: "4.0").errorDescription,
            "Homebrew 4.0 can’t export a Brewfile limited to formulae."
        )
        XCTAssertEqual(
            HomebrewCompatibilityError.unsupportedBundleAdd(kind: .uv, version: "4.0").errorDescription,
            "Homebrew 4.0 can’t add uv entries through brew bundle."
        )
        XCTAssertEqual(
            HomebrewCompatibilityError.unsupportedBundleRemove(kind: .mas, version: "4.0").errorDescription,
            "Homebrew 4.0 can’t remove app store entries through brew bundle."
        )
    }

    func testInstalledOutdatedAndTapInfoArgumentsRespectConfiguredJSONFlags() throws {
        let snapshot = HomebrewCompatibilitySnapshot(
            version: HomebrewVersion(parsing: "5.1.7"),
            infoJSONArgument: .plain,
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

        XCTAssertEqual(try snapshot.installedInfoArguments(), ["info", "--json", "--installed"])
        XCTAssertEqual(try snapshot.outdatedArguments(), ["outdated", "--json=v2"])
        XCTAssertEqual(snapshot.tapInfoArguments(for: ["homebrew/core"]), ["tap-info", "--json=v1", "homebrew/core"])
        XCTAssertNoThrow(try snapshot.validateServicesJSONSupport())
    }

    func testCompatibilitySnapshotThrowsWhenCriticalCapabilitiesAreMissing() {
        let snapshot = HomebrewCompatibilitySnapshot(
            version: HomebrewVersion(parsing: "4.0"),
            infoJSONArgument: nil,
            outdatedJSONArgument: nil,
            tapInfoJSONArgument: .plain,
            servicesListSupportsJSON: false,
            servicesInfoSupportsJSON: true,
            bundleSupportsNoUpgrade: false,
            bundleSupportsFormulaDump: false,
            bundleSupportsCaskDump: false,
            supportedBundleAddKinds: [.brew],
            supportedBundleRemoveKinds: [.brew]
        )

        XCTAssertEqual(
            try? snapshot.installedInfoArguments(),
            nil
        )
        XCTAssertEqual(
            try? snapshot.outdatedArguments(),
            nil
        )

        do {
            try snapshot.validateServicesJSONSupport()
            XCTFail("Expected services JSON validation to fail.")
        } catch {
            XCTAssertEqual(
                error as? HomebrewCompatibilityError,
                .unsupportedServicesJSON(version: "4.0")
            )
        }
    }

    func testNormalizedArgumentsAllowSupportedBundleCommandsThrough() throws {
        let snapshot = HomebrewCompatibilitySnapshot.modernDefault(version: "5.1.7")

        XCTAssertEqual(
            try snapshot.normalized(arguments: ["bundle", "check", "--file", "/tmp/Brewfile", "--no-upgrade"]),
            ["bundle", "check", "--file", "/tmp/Brewfile", "--no-upgrade"]
        )
        XCTAssertEqual(
            try snapshot.normalized(arguments: ["bundle", "dump", "--file", "/tmp/Brewfile", "--force", "--formula"]),
            ["bundle", "dump", "--file", "/tmp/Brewfile", "--force", "--formula"]
        )
        XCTAssertEqual(
            try snapshot.normalized(arguments: ["bundle", "add", "uv", "--uv", "--file", "/tmp/Brewfile"]),
            ["bundle", "add", "uv", "--uv", "--file", "/tmp/Brewfile"]
        )
        XCTAssertEqual(
            try snapshot.normalized(arguments: ["bundle", "remove", "wget", "--formula", "--file", "/tmp/Brewfile"]),
            ["bundle", "remove", "wget", "--formula", "--file", "/tmp/Brewfile"]
        )
        XCTAssertEqual(
            try snapshot.normalized(arguments: ["fetch", "wget"]),
            ["fetch", "wget"]
        )
    }

    func testNormalizedArgumentsRejectUnsupportedBundleFlagsAndKinds() {
        let snapshot = HomebrewCompatibilitySnapshot(
            version: HomebrewVersion(parsing: "4.0"),
            infoJSONArgument: .plain,
            outdatedJSONArgument: .plain,
            tapInfoJSONArgument: .plain,
            servicesListSupportsJSON: true,
            servicesInfoSupportsJSON: true,
            bundleSupportsNoUpgrade: false,
            bundleSupportsFormulaDump: false,
            bundleSupportsCaskDump: false,
            supportedBundleAddKinds: [.brew, .tap],
            supportedBundleRemoveKinds: [.tap]
        )

        XCTAssertEqual(
            normalizedError(from: snapshot, arguments: ["bundle", "check", "--file", "/tmp/Brewfile", "--no-upgrade"]),
            .unsupportedBundleCheckNoUpgrade(version: "4.0")
        )
        XCTAssertEqual(
            normalizedError(from: snapshot, arguments: ["bundle", "dump", "--file", "/tmp/Brewfile", "--formula"]),
            .unsupportedBundleDumpScope(scope: .formula, version: "4.0")
        )
        XCTAssertEqual(
            normalizedError(from: snapshot, arguments: ["bundle", "dump", "--file", "/tmp/Brewfile", "--cask"]),
            .unsupportedBundleDumpScope(scope: .cask, version: "4.0")
        )
        XCTAssertEqual(
            normalizedError(from: snapshot, arguments: ["bundle", "add", "uv", "--uv", "--file", "/tmp/Brewfile"]),
            .unsupportedBundleAdd(kind: .uv, version: "4.0")
        )
        XCTAssertEqual(
            normalizedError(from: snapshot, arguments: ["bundle", "remove", "wget", "--formula", "--file", "/tmp/Brewfile"]),
            .unsupportedBundleRemove(kind: .brew, version: "4.0")
        )
    }

    func testNormalizedArgumentsRejectFormulaAddWhenFormulaeAreNotSupportedByDefault() {
        let snapshot = HomebrewCompatibilitySnapshot(
            version: HomebrewVersion(parsing: "4.0"),
            infoJSONArgument: .plain,
            outdatedJSONArgument: .plain,
            tapInfoJSONArgument: .plain,
            servicesListSupportsJSON: true,
            servicesInfoSupportsJSON: true,
            bundleSupportsNoUpgrade: true,
            bundleSupportsFormulaDump: true,
            bundleSupportsCaskDump: true,
            supportedBundleAddKinds: [.tap],
            supportedBundleRemoveKinds: Set(BrewfileEntryKind.allCases.filter(\.supportsBundleRemove))
        )

        XCTAssertEqual(
            normalizedError(from: snapshot, arguments: ["bundle", "add", "wget", "--file", "/tmp/Brewfile"]),
            .unsupportedBundleAdd(kind: .brew, version: "4.0")
        )
    }

    private func normalizedError(
        from snapshot: HomebrewCompatibilitySnapshot,
        arguments: [String]
    ) -> HomebrewCompatibilityError? {
        do {
            _ = try snapshot.normalized(arguments: arguments)
            return nil
        } catch {
            return error as? HomebrewCompatibilityError
        }
    }
}
