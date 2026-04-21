import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class CatalogViewModelTests: XCTestCase {
    func testLoadIfNeededLoadsPackagesAndFirstDetail() async {
        let package = CatalogPackageSummary(
            kind: .formula,
            slug: "wget",
            title: "wget",
            subtitle: "Internet file retriever",
            version: "1.25.0",
            homepage: URL(string: "https://example.com/wget")
        )
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
        await settle()

        XCTAssertEqual(viewModel.filteredPackages, [package])
        XCTAssertEqual(viewModel.selectedPackage, package)
        XCTAssertEqual(viewModel.detailState, .loaded(detail))
        XCTAssertEqual(apiClient.fetchCatalogCallCount, 1)
        XCTAssertEqual(apiClient.fetchDetailCallCount, 1)
    }

    func testFilteredPackagesRespectSearchAndScope() {
        let formula = CatalogPackageSummary(
            kind: .formula,
            slug: "wget",
            title: "wget",
            subtitle: "Internet file retriever",
            version: "1.25.0",
            homepage: nil
        )
        let cask = CatalogPackageSummary(
            kind: .cask,
            slug: "docker-desktop",
            title: "Docker Desktop",
            subtitle: "Container desktop app",
            version: "4.68.0",
            homepage: nil
        )
        let viewModel = CatalogViewModel(apiClient: MockCatalogAPIClient(packages: .success([]), details: [:]))
        viewModel.packagesState = .loaded([formula, cask])

        viewModel.searchText = "docker"
        XCTAssertEqual(viewModel.filteredPackages, [cask])

        viewModel.searchText = ""
        viewModel.scope = .formula
        XCTAssertEqual(viewModel.filteredPackages, [formula])
    }

    func testSelectPackageUsesCachedDetailOnSecondSelection() async {
        let first = CatalogPackageSummary(
            kind: .formula,
            slug: "wget",
            title: "wget",
            subtitle: "Internet file retriever",
            version: "1.25.0",
            homepage: nil
        )
        let second = CatalogPackageSummary(
            kind: .cask,
            slug: "docker-desktop",
            title: "Docker Desktop",
            subtitle: "Container desktop app",
            version: "4.68.0",
            homepage: nil
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
        await settle()
        viewModel.selectPackage(second)
        await settle()

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
        await settle()

        XCTAssertEqual(
            viewModel.packagesState,
            .failed("The Homebrew API request failed with status code 503.")
        )
        XCTAssertEqual(viewModel.detailState, .idle)
    }

    private func settle() async {
        await Task.yield()
        await Task.yield()
        await Task.yield()
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
