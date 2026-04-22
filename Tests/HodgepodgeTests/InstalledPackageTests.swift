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
        XCTAssertEqual(InstalledPackageFilterOption.favorites.title, "Favorites")
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

    func testDependencyGroupsIncludeOnlyPopulatedSections() {
        let package = makePackage(
            directDependencies: ["fmt"],
            buildDependencies: ["cmake"],
            testDependencies: ["swiftlint"],
            requirements: ["xcode 15.3 (build)"],
            directRuntimeDependencies: ["fmt"],
            runtimeDependencies: ["fmt", "zlib"]
        )

        XCTAssertEqual(
            package.dependencyGroups.map(\.title),
            ["Direct Runtime Dependencies", "Declared Dependencies", "Build Dependencies", "Test Dependencies", "Requirements"]
        )
        XCTAssertEqual(package.dependencyGroups.first?.items, ["fmt"])
    }

    func testDependencySnapshotFlagsOnlyTreeCardsWithContent() {
        let emptySnapshot = InstalledPackageDependencySnapshot(
            summaryMetrics: [],
            dependencyGroups: [],
            dependencyTree: [],
            dependentTree: []
        )
        XCTAssertFalse(emptySnapshot.hasDependencyTree)
        XCTAssertFalse(emptySnapshot.hasDependentTree)

        let populatedSnapshot = InstalledPackageDependencySnapshot(
            summaryMetrics: [],
            dependencyGroups: [],
            dependencyTree: [
                InstalledPackageTreeRow(
                    id: "formula:wget->formula:openssl@3",
                    packageID: "formula:openssl@3",
                    title: "openssl@3",
                    depth: 0
                )
            ],
            dependentTree: [
                InstalledPackageTreeRow(
                    id: "formula:wget<-formula:curl",
                    packageID: "formula:curl",
                    title: "curl",
                    depth: 0
                )
            ]
        )
        XCTAssertTrue(populatedSnapshot.hasDependencyTree)
        XCTAssertTrue(populatedSnapshot.hasDependentTree)
    }

    func testAvailableActionKindsReflectFormulaAndCaskState() {
        let linkedPinnedFormula = makePackage(isPinned: true, isLinked: true)
        XCTAssertEqual(
            linkedPinnedFormula.availableActionKinds,
            [.reinstall, .unlink, .unpin, .uninstall]
        )

        let unlinkedFormula = makePackage(isPinned: false, isLinked: false)
        XCTAssertEqual(
            unlinkedFormula.availableActionKinds,
            [.reinstall, .link, .pin, .uninstall]
        )

        let cask = makePackage(kind: .cask)
        XCTAssertEqual(cask.availableActionKinds, [.reinstall, .uninstall])
    }

    func testActionCommandsUseHomebrewCompatibleArguments() {
        let formula = makePackage(isPinned: true, isLinked: true)
        XCTAssertEqual(formula.actionCommand(for: .reinstall).arguments, ["reinstall", "wget"])
        XCTAssertEqual(formula.actionCommand(for: .unlink).arguments, ["unlink", "wget"])
        XCTAssertEqual(formula.actionCommand(for: .unpin).arguments, ["unpin", "wget"])
        XCTAssertEqual(formula.actionCommand(for: .uninstall).arguments, ["uninstall", "wget"])

        let cask = makePackage(kind: .cask)
        XCTAssertEqual(cask.actionCommand(for: .reinstall).arguments, ["reinstall", "--cask", "wget"])
        XCTAssertEqual(cask.actionCommand(for: .uninstall).arguments, ["uninstall", "--cask", "wget"])
    }

    func testActionDescriptionsAndConfirmationMetadataStayUserFriendly() {
        XCTAssertTrue(InstalledPackageActionKind.reinstall.requiresConfirmation)
        XCTAssertTrue(InstalledPackageActionKind.uninstall.requiresConfirmation)
        XCTAssertFalse(InstalledPackageActionKind.link.requiresConfirmation)
        XCTAssertEqual(InstalledPackageActionKind.pin.title, "Pin")
        XCTAssertEqual(InstalledPackageActionKind.unpin.title, "Unpin")

        let formula = makePackage(kind: .formula, isPinned: false, isLinked: false)
        XCTAssertEqual(
            formula.actionDescription,
            "Manage how this formula is linked and pinned, or reinstall and uninstall it locally."
        )

        let reinstallCommand = formula.actionCommand(for: .reinstall)
        XCTAssertEqual(reinstallCommand.confirmationTitle, "Reinstall wget?")
        XCTAssertTrue(reinstallCommand.confirmationMessage.contains("removes and installs the package again"))
        XCTAssertEqual(reinstallCommand.command, "brew reinstall wget")

        let cask = makePackage(kind: .cask)
        XCTAssertEqual(
            cask.actionDescription,
            "Reinstall or uninstall this cask from your local Homebrew setup."
        )

        let uninstallCommand = cask.actionCommand(for: .uninstall)
        XCTAssertEqual(uninstallCommand.confirmationTitle, "Uninstall wget?")
        XCTAssertTrue(uninstallCommand.confirmationMessage.contains("removes the package from this Mac"))
        XCTAssertEqual(uninstallCommand.command, "brew uninstall --cask wget")
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
        isDisabled: Bool = false,
        directDependencies: [String] = [],
        buildDependencies: [String] = [],
        testDependencies: [String] = [],
        recommendedDependencies: [String] = [],
        optionalDependencies: [String] = [],
        requirements: [String] = [],
        directRuntimeDependencies: [String] = [],
        runtimeDependencies: [String] = []
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
            directDependencies: directDependencies,
            buildDependencies: buildDependencies,
            testDependencies: testDependencies,
            recommendedDependencies: recommendedDependencies,
            optionalDependencies: optionalDependencies,
            requirements: requirements,
            directRuntimeDependencies: directRuntimeDependencies,
            runtimeDependencies: runtimeDependencies
        )
    }
}
