import XCTest
@testable import Hodgepodge

final class HomebrewCompatibilityDetectorTests: XCTestCase {
    func testSnapshotParsesCurrentHelpSurface() {
        let snapshot = HomebrewCompatibilityDetector.snapshot(
            version: "5.1.7",
            infoHelp: """
            Usage: brew info [options]
                  --json                       Print a JSON representation. Currently the
                                               default value for version is v1 for
                                               formula. For formula and cask use v2.
            """,
            outdatedHelp: """
            Usage: brew outdated [options]
                  --json                       Print output in JSON format. There are two
                                               versions: v1 and v2. v2 prints outdated formulae and
                                               casks.
            """,
            tapInfoHelp: """
            Usage: brew tap-info [--installed] [--json] [tap ...]
                  --json                       Print a JSON representation of tap.
                                               Currently the default and only accepted value
                                               for version is v1.
            """,
            servicesHelp: """
            [sudo] brew services [list] [--json] [--debug]:
            [sudo] brew services info (formula|--all) [--json]:
            """,
            bundleHelp: """
            brew bundle add name [...]:
                Add entries to your Brewfile. Adds formulae by default. Use --cask,
                --tap, --vscode, --go, --cargo, --uv, --flatpak, --krew and
                --npm to add the corresponding entry instead.
                  --no-upgrade
                  --formula, --formulae, --brews
                  --cask, --casks
            """
        )

        XCTAssertEqual(snapshot.infoJSONArgument, .versioned("v2"))
        XCTAssertEqual(snapshot.outdatedJSONArgument, .versioned("v2"))
        XCTAssertEqual(snapshot.tapInfoJSONArgument, .versioned("v1"))
        XCTAssertTrue(snapshot.servicesListSupportsJSON)
        XCTAssertTrue(snapshot.servicesInfoSupportsJSON)
        XCTAssertTrue(snapshot.bundleSupportsNoUpgrade)
        XCTAssertTrue(snapshot.bundleSupportsFormulaDump)
        XCTAssertTrue(snapshot.bundleSupportsCaskDump)
        XCTAssertTrue(snapshot.supportedBundleAddKinds.contains(.brew))
        XCTAssertTrue(snapshot.supportedBundleAddKinds.contains(.uv))
        XCTAssertTrue(snapshot.supportedBundleRemoveKinds.contains(.brew))
        XCTAssertTrue(snapshot.supportedBundleRemoveKinds.contains(.cask))
    }

    func testSnapshotFallsBackToPlainTapInfoJSONWhenVersionHintIsMissing() {
        let snapshot = HomebrewCompatibilityDetector.snapshot(
            version: "5.1.7",
            infoHelp: "--json",
            outdatedHelp: "--json",
            tapInfoHelp: """
            Usage: brew tap-info [--installed] [--json] [tap ...]
                  --json                       Print a JSON representation of tap.
            """,
            servicesHelp: "",
            bundleHelp: ""
        )

        XCTAssertEqual(snapshot.tapInfoJSONArgument, .plain)
        XCTAssertNil(snapshot.outdatedJSONArgument)
    }

    func testSnapshotRecognizesServicesListJSONWhenListIsOptionalInHelp() {
        let snapshot = HomebrewCompatibilityDetector.snapshot(
            version: "5.1.7",
            infoHelp: "",
            outdatedHelp: "",
            tapInfoHelp: "",
            servicesHelp: """
            [sudo] brew services [list] [--json] [--debug]:
            [sudo] brew services info (formula|--all) [--json]:
            """,
            bundleHelp: ""
        )

        XCTAssertTrue(snapshot.servicesListSupportsJSON)
        XCTAssertTrue(snapshot.servicesInfoSupportsJSON)
    }

    func testSnapshotNormalizesWrappedTapInfoHelpBeforeVersionDetection() {
        let snapshot = HomebrewCompatibilityDetector.snapshot(
            version: "5.1.7",
            infoHelp: "",
            outdatedHelp: "",
            tapInfoHelp: """
            Usage: brew tap-info [--installed] [--json] [tap ...]
                  --json                       Print a JSON representation of tap.
                                               Currently the default and only accepted value
                                               for version is v1.
            """,
            servicesHelp: "",
            bundleHelp: ""
        )

        XCTAssertEqual(snapshot.tapInfoJSONArgument, .versioned("v1"))
    }
}
