import XCTest
@testable import Hodgepodge

final class OutdatedPackageTests: XCTestCase {
    func testStatusBadgesIncludePinnedWhenPresent() {
        XCTAssertEqual(
            OutdatedPackage.fixture(isPinned: true, pinnedVersion: "1.24.5").statusBadges,
            ["Pinned"]
        )
        XCTAssertTrue(OutdatedPackage.fixture().statusBadges.isEmpty)
    }

    func testUpgradeReadinessDescriptionPrefersPinnedVersionMessage() {
        XCTAssertEqual(
            OutdatedPackage.fixture(isPinned: true, pinnedVersion: "1.24.5").upgradeReadinessDescription,
            "Pinned at 1.24.5. Unpin before upgrading."
        )
        XCTAssertEqual(
            OutdatedPackage.fixture(isPinned: true, pinnedVersion: nil).upgradeReadinessDescription,
            "Pinned. Unpin before upgrading."
        )
        XCTAssertEqual(
            OutdatedPackage.fixture().upgradeReadinessDescription,
            "Ready to upgrade to 1.25.0."
        )
    }

    func testInstalledVersionSummaryAndUpgradeCommandAreStable() {
        XCTAssertEqual(
            OutdatedPackage.fixture(installedVersions: ["1.24.4", "1.24.5"]).installedVersionSummary,
            "1.24.4, 1.24.5"
        )
        XCTAssertEqual(
            OutdatedPackage.fixture(kind: .cask, slug: "docker-desktop").upgradeCommand,
            "brew upgrade --cask docker-desktop"
        )
        XCTAssertEqual(
            OutdatedPackage.fixture(installedVersions: []).primaryInstalledVersion,
            "Unknown"
        )
    }

    func testOutdatedPackageFilterAndSortTitlesAreStable() {
        XCTAssertEqual(OutdatedPackageFilterOption.pinned.title, "Pinned")
        XCTAssertEqual(OutdatedPackageSortOption.name.title, "Name")
        XCTAssertEqual(OutdatedPackageSortOption.currentVersion.title, "Current Version")
        XCTAssertEqual(OutdatedPackageSortOption.packageType.title, "Package Type")
    }
}
