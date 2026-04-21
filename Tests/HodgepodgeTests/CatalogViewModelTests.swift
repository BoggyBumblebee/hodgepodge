import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class CatalogViewModelTests: XCTestCase {
    func testLoadIfNeededLoadsPackagesAndFirstDetail() async {
        let package = CatalogPackageSummary.fixture()
        let detail = CatalogPackageDetail(
            kind: .formula,
            slug: "wget",
            title: "wget",
            fullName: "wget",
            aliases: [],
            oldNames: [],
            description: "Internet file retriever",
            homepage: package.homepage,
            version: "1.25.0",
            tap: "homebrew/core",
            license: "GPL-3.0-or-later",
            downloadURL: nil,
            checksum: nil,
            autoUpdates: nil,
            versionDetails: [
                CatalogDetailMetric(title: "Current", value: "1.25.0"),
                CatalogDetailMetric(title: "Stable", value: "1.25.0")
            ],
            dependencies: ["openssl@3"],
            dependencySections: [
                CatalogDetailSection(title: "Runtime Dependencies", items: ["openssl@3"], style: .tags)
            ],
            conflicts: [],
            lifecycleSections: [],
            platformSections: [],
            caveats: nil,
            artifacts: [],
            artifactSections: [],
            analytics: []
        )
        let apiClient = MockCatalogAPIClient(packages: .success([package]), details: [package.id: .success(detail)])
        let viewModel = CatalogViewModel(apiClient: apiClient)

        viewModel.loadIfNeeded()
        await waitUntil {
            viewModel.detailState == .loaded(detail)
        }

        XCTAssertEqual(viewModel.filteredPackages, [package])
        XCTAssertEqual(viewModel.selectedPackage, package)
        XCTAssertEqual(viewModel.detailState, .loaded(detail))
        XCTAssertEqual(apiClient.fetchCatalogCallCount, 1)
        XCTAssertEqual(apiClient.fetchDetailCallCount, 1)
    }

    func testFilteredPackagesRespectSearchAndScope() {
        let formula = CatalogPackageSummary.fixture(homepage: nil)
        let cask = CatalogPackageSummary.fixture(
            kind: .cask,
            slug: "docker-desktop",
            title: "Docker Desktop",
            subtitle: "Container desktop app",
            version: "4.68.0",
            homepage: nil,
            tap: "homebrew/cask"
        )
        let viewModel = CatalogViewModel(apiClient: MockCatalogAPIClient(packages: .success([]), details: [:]))
        viewModel.packagesState = .loaded([formula, cask])

        viewModel.searchText = "docker"
        XCTAssertEqual(viewModel.filteredPackages, [cask])

        viewModel.searchText = ""
        viewModel.scope = .formula
        XCTAssertEqual(viewModel.filteredPackages, [formula])
    }

    func testFilteredPackagesRespectActiveFiltersAndSort() {
        let formula = CatalogPackageSummary.fixture(
            slug: "alpha",
            title: "Alpha",
            tap: "homebrew/core",
            hasCaveats: true
        )
        let cask = CatalogPackageSummary.fixture(
            kind: .cask,
            slug: "zulu",
            title: "Zulu",
            subtitle: "Auto-updating cask",
            version: "5.0",
            homepage: nil,
            tap: "homebrew/cask",
            autoUpdates: true
        )
        let deprecated = CatalogPackageSummary.fixture(
            slug: "beta",
            title: "Beta",
            version: "0.9",
            homepage: nil,
            tap: "homebrew/core",
            isDeprecated: true
        )
        let viewModel = CatalogViewModel(apiClient: MockCatalogAPIClient(packages: .success([]), details: [:]))
        viewModel.packagesState = .loaded([cask, deprecated, formula])

        viewModel.activeFilters = [.hasCaveats]
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Alpha"])

        viewModel.activeFilters = [.autoUpdates]
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Zulu"])

        viewModel.activeFilters = []
        viewModel.sortOption = .version
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Beta", "Alpha", "Zulu"])

        viewModel.sortOption = .tap
        XCTAssertEqual(viewModel.filteredPackages.map(\.title), ["Zulu", "Alpha", "Beta"])
    }

    func testSelectPackageUsesCachedDetailOnSecondSelection() async {
        let first = CatalogPackageSummary.fixture(homepage: nil)
        let second = CatalogPackageSummary.fixture(
            kind: .cask,
            slug: "docker-desktop",
            title: "Docker Desktop",
            subtitle: "Container desktop app",
            version: "4.68.0",
            homepage: nil,
            tap: "homebrew/cask"
        )
        let detail = CatalogPackageDetail(
            kind: .cask,
            slug: "docker-desktop",
            title: "Docker Desktop",
            fullName: "docker-desktop",
            aliases: [],
            oldNames: [],
            description: "Container desktop app",
            homepage: nil,
            version: "4.68.0",
            tap: "homebrew/cask",
            license: nil,
            downloadURL: nil,
            checksum: nil,
            autoUpdates: true,
            versionDetails: [
                CatalogDetailMetric(title: "Current", value: "4.68.0"),
                CatalogDetailMetric(title: "Stable", value: "4.68.0")
            ],
            dependencies: [],
            dependencySections: [],
            conflicts: [],
            lifecycleSections: [],
            platformSections: [],
            caveats: nil,
            artifacts: [],
            artifactSections: [],
            analytics: []
        )
        let apiClient = MockCatalogAPIClient(
            packages: .success([first, second]),
            details: [second.id: .success(detail)]
        )
        let viewModel = CatalogViewModel(apiClient: apiClient)

        viewModel.packagesState = .loaded([first, second])
        viewModel.selectPackage(second)
        await waitUntil {
            viewModel.detailState == .loaded(detail)
        }
        viewModel.selectPackage(second)
        await waitUntil {
            apiClient.fetchDetailCallCount == 1
        }

        XCTAssertEqual(viewModel.detailState, .loaded(detail))
        XCTAssertEqual(apiClient.fetchDetailCallCount, 1)
    }

    func testRefreshCatalogStoresFailureMessage() async {
        let viewModel = CatalogViewModel(
            apiClient: MockCatalogAPIClient(
                packages: .failure(HomebrewAPIClientError.requestFailed(503)),
                details: [:]
            )
        )

        viewModel.refreshCatalog()
        await waitUntil {
            viewModel.packagesState == .failed("The Homebrew API request failed with status code 503.")
        }

        XCTAssertEqual(
            viewModel.packagesState,
            .failed("The Homebrew API request failed with status code 503.")
        )
        XCTAssertEqual(viewModel.detailState, .idle)
    }

    func testToggleAndClearFiltersUpdateState() {
        let viewModel = CatalogViewModel(apiClient: MockCatalogAPIClient(packages: .success([]), details: [:]))

        XCTAssertFalse(viewModel.isFilterActive(.hasCaveats))

        viewModel.toggleFilter(.hasCaveats)
        XCTAssertTrue(viewModel.isFilterActive(.hasCaveats))
        XCTAssertEqual(viewModel.activeFilterCount, 1)

        viewModel.toggleFilter(.hasCaveats)
        XCTAssertFalse(viewModel.isFilterActive(.hasCaveats))

        viewModel.activeFilters = [.deprecated, .disabled]
        viewModel.clearFilters()
        XCTAssertTrue(viewModel.activeFilters.isEmpty)
    }

    func testRefreshSelectedDetailReloadsWhenSelectionExists() async {
        let package = CatalogPackageSummary.fixture()
        let originalDetail = CatalogPackageDetail.fixture(
            dependencies: ["openssl@3"],
            dependencySections: [
                CatalogDetailSection(title: "Runtime Dependencies", items: ["openssl@3"], style: .tags)
            ]
        )
        let refreshedDetail = CatalogPackageDetail.fixture(
            dependencies: ["curl"],
            dependencySections: [
                CatalogDetailSection(title: "Runtime Dependencies", items: ["curl"], style: .tags)
            ]
        )
        let apiClient = CyclingCatalogAPIClient(details: [originalDetail, refreshedDetail])
        let viewModel = CatalogViewModel(apiClient: apiClient)

        viewModel.packagesState = .loaded([package])
        viewModel.selectPackage(package)
        await waitUntil {
            viewModel.detailState == .loaded(originalDetail)
        }
        XCTAssertEqual(viewModel.detailState, .loaded(originalDetail))

        viewModel.refreshSelectedDetail()
        await waitUntil {
            viewModel.detailState == .loaded(refreshedDetail)
        }

        XCTAssertEqual(viewModel.detailState, .loaded(refreshedDetail))
        XCTAssertEqual(apiClient.fetchDetailCallCount, 2)
    }

    func testRefreshSelectedDetailResetsToIdleWhenNothingSelected() {
        let viewModel = CatalogViewModel(apiClient: MockCatalogAPIClient(packages: .success([]), details: [:]))

        viewModel.refreshSelectedDetail()

        XCTAssertEqual(viewModel.detailState, .idle)
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
}

private final class CyclingCatalogAPIClient: HomebrewAPIClienting, @unchecked Sendable {
    let details: [CatalogPackageDetail]
    private(set) var fetchDetailCallCount = 0

    init(details: [CatalogPackageDetail]) {
        self.details = details
    }

    func fetchCatalog() async throws -> [CatalogPackageSummary] {
        []
    }

    func fetchDetail(for package: CatalogPackageSummary) async throws -> CatalogPackageDetail {
        defer { fetchDetailCallCount += 1 }
        return details[min(fetchDetailCallCount, details.count - 1)]
    }
}

@MainActor
private final class MockCatalogAPIClient: HomebrewAPIClienting, @unchecked Sendable {
    let packages: Result<[CatalogPackageSummary], Error>
    let details: [String: Result<CatalogPackageDetail, Error>]
    private(set) var fetchCatalogCallCount = 0
    private(set) var fetchDetailCallCount = 0

    init(
        packages: Result<[CatalogPackageSummary], Error>,
        details: [String: Result<CatalogPackageDetail, Error>]
    ) {
        self.packages = packages
        self.details = details
    }

    func fetchCatalog() async throws -> [CatalogPackageSummary] {
        fetchCatalogCallCount += 1
        return try packages.get()
    }

    func fetchDetail(for package: CatalogPackageSummary) async throws -> CatalogPackageDetail {
        fetchDetailCallCount += 1

        guard let result = details[package.id] else {
            throw HomebrewAPIClientError.requestFailed(404)
        }

        return try result.get()
    }
}
