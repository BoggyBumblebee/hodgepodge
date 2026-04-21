import Foundation
import XCTest
@testable import Hodgepodge

final class InstalledPackageTests: XCTestCase {
    func testStatusBadgesIncludeEnabledFlagsInDisplayOrder() {
        let package = makePackage(
            isPinned: true,
            isLinked: true,
            isOutdated: true,
            isInstalledOnRequest: true,
            isInstalledAsDependency: true,
            autoUpdates: true,
            isDeprecated: true,
            isDisabled: true
        )

        XCTAssertEqual(
            package.statusBadges,
            ["Pinned", "Linked", "Outdated", "On Request", "Dependency", "Auto Updates", "Deprecated", "Disabled"]
        )
    }

    func testInstallSourceDescriptionPrefersOnRequestThenDependency() {
        XCTAssertEqual(
            makePackage(isInstalledOnRequest: true, isInstalledAsDependency: true).installSourceDescription,
            "Installed on request"
        )
        XCTAssertEqual(
            makePackage(isInstalledOnRequest: false, isInstalledAsDependency: true).installSourceDescription,
            "Installed as a dependency"
        )
        XCTAssertEqual(
            makePackage(isInstalledOnRequest: false, isInstalledAsDependency: false).installSourceDescription,
            "Install source unavailable"
        )
    }

    func testInstalledPackageFilterAndSortTitlesAreStable() {
        XCTAssertEqual(InstalledPackageFilterOption.pinned.title, "Pinned")
        XCTAssertEqual(InstalledPackageFilterOption.linked.title, "Linked")
        XCTAssertEqual(InstalledPackageFilterOption.outdated.title, "Outdated")
        XCTAssertEqual(InstalledPackageFilterOption.installedOnRequest.title, "On Request")
        XCTAssertEqual(InstalledPackageFilterOption.installedAsDependency.title, "Dependency")
        XCTAssertEqual(InstalledPackageFilterOption.autoUpdates.title, "Auto Updates")
        XCTAssertEqual(InstalledPackageSortOption.name.title, "Name")
        XCTAssertEqual(InstalledPackageSortOption.installDate.title, "Install Date")
        XCTAssertEqual(InstalledPackageSortOption.packageType.title, "Package Type")
        XCTAssertEqual(InstalledPackageSortOption.tap.title, "Tap")
    }

    private func makePackage(
        isPinned: Bool = false,
        isLinked: Bool = false,
        isOutdated: Bool = false,
        isInstalledOnRequest: Bool = false,
        isInstalledAsDependency: Bool = false,
        autoUpdates: Bool = false,
        isDeprecated: Bool = false,
        isDisabled: Bool = false
    ) -> InstalledPackage {
        InstalledPackage(
            kind: .formula,
            slug: "wget",
            title: "wget",
            fullName: "homebrew/core/wget",
            subtitle: "Internet file retriever",
            version: "1.25.0",
            homepage: URL(string: "https://example.com/wget"),
            tap: "homebrew/core",
            installedVersions: ["1.25.0"],
            installedAt: Date(timeIntervalSince1970: 1_700_000_000),
            linkedVersion: isLinked ? "1.25.0" : nil,
            isPinned: isPinned,
            isLinked: isLinked,
            isOutdated: isOutdated,
            isInstalledOnRequest: isInstalledOnRequest,
            isInstalledAsDependency: isInstalledAsDependency,
            autoUpdates: autoUpdates,
            isDeprecated: isDeprecated,
            isDisabled: isDisabled,
            runtimeDependencies: []
        )
    }
}
