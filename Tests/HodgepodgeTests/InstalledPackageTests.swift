import Foundation
import XCTest
@testable import Hodgepodge

final class InstalledPackageTests: XCTestCase {
    func testStatusBadgesIncludeEnabledFlagsInDisplayOrder() {
        let package = makePackage(
            isPinned: true,
            isLinked: true,
            isLeaf: true,
            isOutdated: true,
            isInstalledOnRequest: true,
            isInstalledAsDependency: true,
            autoUpdates: true,
            isDeprecated: true,
            isDisabled: true
        )

        XCTAssertEqual(
            package.statusBadges,
            ["Pinned", "Linked", "Leaf", "Outdated", "On Request", "Dependency", "Auto Updates", "Deprecated", "Disabled"]
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
        XCTAssertEqual(InstalledPackageFilterOption.leaves.title, "Leaves")
        XCTAssertEqual(InstalledPackageFilterOption.outdated.title, "Outdated")
        XCTAssertEqual(InstalledPackageFilterOption.installedOnRequest.title, "On Request")
        XCTAssertEqual(InstalledPackageFilterOption.installedAsDependency.title, "Dependency")
        XCTAssertEqual(InstalledPackageFilterOption.autoUpdates.title, "Auto Updates")
        XCTAssertEqual(InstalledPackageSortOption.name.title, "Name")
        XCTAssertEqual(InstalledPackageSortOption.installDate.title, "Install Date")
        XCTAssertEqual(InstalledPackageSortOption.packageType.title, "Package Type")
        XCTAssertEqual(InstalledPackageSortOption.tap.title, "Tap")
    }

    func testPackageStateRowsReflectFormulaAndCaskState() {
        let formula = makePackage(
            isPinned: true,
            isLinked: true,
            isLeaf: true,
            isInstalledOnRequest: true
        )
        XCTAssertEqual(
            formula.packageStateRows.map(\.title),
            ["Pinned", "Linked", "Leaf", "Outdated", "Deprecated", "Disabled", "Install Source"]
        )
        XCTAssertEqual(formula.packageStateRows.first(where: { $0.title == "Leaf" })?.value, "Yes")

        let cask = makePackage(kind: .cask, autoUpdates: true)
        XCTAssertEqual(
            cask.packageStateRows.map(\.title),
            ["Pinned", "Auto Updates", "Outdated", "Deprecated", "Disabled"]
        )
        XCTAssertEqual(cask.packageStateRows.first(where: { $0.title == "Auto Updates" })?.value, "Yes")
    }

    private func makePackage(
        kind: CatalogPackageKind = .formula,
        isPinned: Bool = false,
        isLinked: Bool = false,
        isLeaf: Bool = false,
        isOutdated: Bool = false,
        isInstalledOnRequest: Bool = false,
        isInstalledAsDependency: Bool = false,
        autoUpdates: Bool = false,
        isDeprecated: Bool = false,
        isDisabled: Bool = false
    ) -> InstalledPackage {
        InstalledPackage(
            kind: kind,
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
            isLeaf: isLeaf,
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
