import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class InstalledPackagesViewModelTests: XCTestCase {
    func testLoadIfNeededLoadsPackagesAndSelectsFirstPackage() async {
        let packages = [
            makePackage(
                title: "wget",
                version: "1.25.0",
                installedAt: Date(timeIntervalSince1970: 100)
            ),
            makePackage(
                kind: .cask,
                slug: "docker-desktop",
                title: "Docker Desktop",
                version: "4.68.0",
                installedAt: Date(timeIntervalSince1970: 200)
            )
        ]
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success(packages))
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.packagesState == .loaded(packages)
        }

        XCTAssertEqual(viewModel.filteredPackages, [packages[1], packages[0]])
        XCTAssertEqual(viewModel.selectedPackage, packages[1])
    }

    func testFilteredPackagesRespectSearchScopeFiltersAndSort() {
        let packages = [
            makePackage(
                slug: "alpha",
                title: "Alpha",
                version: "1.0.0",
                installedAt: Date(timeIntervalSince1970: 100),
                isInstalledOnRequest: true,
                isLeaf: true
            ),
            makePackage(
                kind: .cask,
                slug: "docker-desktop",
                title: "Docker Desktop",
                version: "4.68.0",
                tap: "homebrew/cask",
                installedAt: Date(timeIntervalSince1970: 300),
                autoUpdates: true
            ),
            makePackage(
                slug: "beta",
                title: "Beta",
                version: "2.0.0",
                installedAt: Date(timeIntervalSince1970: 200),
                isInstalledAsDependency: true
            )
        ]
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success(packages))
        )
        viewModel.packagesState = .loaded(packages)

        viewModel.searchText = "docker"
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Docker Desktop"])

        viewModel.searchText = ""
        viewModel.scope = .formula
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Beta", "Alpha"])

        viewModel.scope = .all
        viewModel.activeFilters = [.installedAsDependency]
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Beta"])

        viewModel.activeFilters = [.leaves]
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Alpha"])

        viewModel.activeFilters = []
        viewModel.sortOption = .name
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Alpha", "Beta", "Docker Desktop"])
    }

    func testRefreshPackagesStoresFailureMessage() async {
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(
                result: .failure(HomebrewAPIClientError.requestFailed(503))
            )
        )

        viewModel.refreshPackages()
        await waitUntil {
            viewModel.packagesState == .failed("The Homebrew API request failed with status code 503.")
        }

        XCTAssertEqual(
            viewModel.packagesState,
            .failed("The Homebrew API request failed with status code 503.")
        )
        XCTAssertNil(viewModel.selectedPackage)
    }

    func testToggleAndClearFiltersUpdateState() {
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success([]))
        )

        XCTAssertFalse(viewModel.isFilterActive(.pinned))

        viewModel.toggleFilter(.pinned)
        XCTAssertTrue(viewModel.isFilterActive(.pinned))
        XCTAssertEqual(viewModel.activeFilterCount, 1)

        viewModel.toggleFilter(.pinned)
        XCTAssertFalse(viewModel.isFilterActive(.pinned))

        viewModel.activeFilters = [.linked, .outdated]
        viewModel.clearFilters()
        XCTAssertTrue(viewModel.activeFilters.isEmpty)
    }

    func testLoadIfNeededDoesNotRefreshWhenAlreadyLoaded() async {
        let provider = CountingInstalledPackagesProvider(
            result: .success([makePackage()])
        )
        let viewModel = InstalledPackagesViewModel(provider: provider)
        viewModel.packagesState = .loaded([makePackage()])

        viewModel.loadIfNeeded()
        await Task.yield()

        XCTAssertEqual(provider.fetchCallCount, 0)
    }

    func testRefreshPackagesPreservesMatchingSelection() async {
        let original = makePackage(
            slug: "wget",
            title: "wget",
            version: "1.25.0",
            installedAt: Date(timeIntervalSince1970: 100)
        )
        let refreshed = makePackage(
            slug: "wget",
            title: "wget",
            version: "1.25.1",
            installedAt: Date(timeIntervalSince1970: 200)
        )
        let provider = CyclingInstalledPackagesProvider(results: [[original], [refreshed]])
        let viewModel = InstalledPackagesViewModel(provider: provider)

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.selectedPackage?.version == "1.25.0"
        }

        viewModel.refreshPackages()
        await waitUntil {
            viewModel.selectedPackage?.version == "1.25.1"
        }

        XCTAssertEqual(viewModel.selectedPackage, refreshed)
    }

    func testStateCountsReflectPackageStateInventory() {
        let packages = [
            makePackage(isPinned: true, isLinked: true, isInstalledOnRequest: true, isLeaf: true),
            makePackage(slug: "beta", title: "Beta", isInstalledAsDependency: true),
            makePackage(kind: .cask, slug: "docker-desktop", title: "Docker Desktop", autoUpdates: true)
        ]
        let viewModel = InstalledPackagesViewModel(
            provider: MockInstalledPackagesProvider(result: .success(packages))
        )
        viewModel.packagesState = .loaded(packages)

        XCTAssertEqual(
            viewModel.stateCounts,
            [
                InstalledPackageStateCount(title: "On Request", count: 1),
                InstalledPackageStateCount(title: "Dependency", count: 1),
                InstalledPackageStateCount(title: "Leaves", count: 1),
                InstalledPackageStateCount(title: "Pinned", count: 1)
            ]
        )
    }

    private func waitUntil(
        maxIterations: Int = 50,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @MainActor () -> Bool
    ) async {
        for _ in 0..<maxIterations {
            if condition() {
                return
            }
            await Task.yield()
        }

        XCTFail("Condition was not met in time.", file: file, line: line)
    }

    private func makePackage(
        kind: CatalogPackageKind = .formula,
        slug: String = "wget",
        title: String = "wget",
        version: String = "1.25.0",
        tap: String = "homebrew/core",
        installedAt: Date? = Date(timeIntervalSince1970: 100),
        isPinned: Bool = false,
        isLinked: Bool? = nil,
        isInstalledOnRequest: Bool = false,
        isInstalledAsDependency: Bool = false,
        autoUpdates: Bool = false,
        isLeaf: Bool = false
    ) -> InstalledPackage {
        InstalledPackage(
            kind: kind,
            slug: slug,
            title: title,
            fullName: slug,
            subtitle: "Test package",
            version: version,
            homepage: nil,
            tap: tap,
            installedVersions: [version],
            installedAt: installedAt,
            linkedVersion: resolvedLinkedVersion(kind: kind, version: version, isLinked: isLinked),
            isPinned: isPinned,
            isLinked: isLinked ?? (kind == .formula),
            isLeaf: isLeaf,
            isOutdated: false,
            isInstalledOnRequest: isInstalledOnRequest,
            isInstalledAsDependency: isInstalledAsDependency,
            autoUpdates: autoUpdates,
            isDeprecated: false,
            isDisabled: false,
            runtimeDependencies: []
        )
    }

    private func resolvedLinkedVersion(
        kind: CatalogPackageKind,
        version: String,
        isLinked: Bool?
    ) -> String? {
        if let isLinked {
            return isLinked ? version : nil
        }

        return kind == .formula ? version : nil
    }
}

private struct MockInstalledPackagesProvider: InstalledPackagesProviding {
    let result: Result<[InstalledPackage], Error>

    func fetchInstalledPackages() async throws -> [InstalledPackage] {
        try result.get()
    }
}

@MainActor
private final class CountingInstalledPackagesProvider: InstalledPackagesProviding, @unchecked Sendable {
    let result: Result<[InstalledPackage], Error>
    private(set) var fetchCallCount = 0

    init(result: Result<[InstalledPackage], Error>) {
        self.result = result
    }

    func fetchInstalledPackages() async throws -> [InstalledPackage] {
        fetchCallCount += 1
        return try result.get()
    }
}

@MainActor
private final class CyclingInstalledPackagesProvider: InstalledPackagesProviding, @unchecked Sendable {
    let results: [[InstalledPackage]]
    private(set) var fetchCallCount = 0

    init(results: [[InstalledPackage]]) {
        self.results = results
    }

    func fetchInstalledPackages() async throws -> [InstalledPackage] {
        defer { fetchCallCount += 1 }
        return results[min(fetchCallCount, results.count - 1)]
    }
}
