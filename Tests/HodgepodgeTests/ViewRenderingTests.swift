import AppKit
import SwiftUI
import XCTest
@testable import Hodgepodge

@MainActor
final class ViewRenderingTests: XCTestCase {
    func testOverviewViewRendersLoadingFailureAndLoadedStates() {
        let model = makeModel()

        model.installationState = .loading
        XCTAssertNotNil(render(OverviewView(model: model)))

        model.installationState = .failed("Broken")
        XCTAssertNotNil(render(OverviewView(model: model)))

        model.installationState = .loaded(.fixture())
        XCTAssertNotNil(render(OverviewView(model: model)))
    }

    func testRootViewRendersOverviewAndPlaceholderSections() {
        let model = makeModel()
        let catalogModel = makeCatalogModel()
        let installedPackagesModel = makeInstalledPackagesModel()
        let outdatedPackagesModel = makeOutdatedPackagesModel()

        model.selectedSection = .overview
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel
            )
        ))

        model.selectedSection = .catalog
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel
            )
        ))

        model.selectedSection = .installed
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel
            )
        ))

        model.selectedSection = .outdated
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel
            )
        ))
    }

    func testPlaceholderFeatureViewRenders() {
        XCTAssertNotNil(render(PlaceholderFeatureView(section: .services)))
    }

    func testHodgepodgeCommandsBuildsMenuCommands() {
        let commands = HodgepodgeCommands(model: makeModel())

        _ = commands.body

        XCTAssertTrue(true)
    }

    func testCatalogViewRendersLoadedAndDetailStates() {
        let package = CatalogPackageSummary.fixture(
            homepage: nil,
            hasCaveats: true
        )
        let detail = CatalogPackageDetail(
            kind: .formula,
            slug: "wget",
            title: "wget",
            fullName: "homebrew/core/wget",
            aliases: ["wget2"],
            oldNames: ["gnu-wget"],
            description: "Internet file retriever",
            homepage: URL(string: "https://example.com/wget"),
            version: "1.25.0",
            tap: "homebrew/core",
            license: "GPL-3.0-or-later",
            downloadURL: URL(string: "https://example.com/wget.tar.gz"),
            checksum: "abc123",
            autoUpdates: nil,
            versionDetails: [
                CatalogDetailMetric(title: "Current", value: "1.25.0"),
                CatalogDetailMetric(title: "Stable", value: "1.25.0"),
                CatalogDetailMetric(title: "Head", value: "HEAD")
            ],
            dependencies: ["openssl@3"],
            dependencySections: [
                CatalogDetailSection(title: "Runtime Dependencies", items: ["openssl@3"], style: .tags),
                CatalogDetailSection(title: "Build Dependencies", items: ["pkgconf"], style: .tags)
            ],
            conflicts: [],
            lifecycleSections: [],
            platformSections: [
                CatalogDetailSection(title: "Bottle Platforms", items: ["arm64_sonoma", "sonoma"], style: .tags)
            ],
            caveats: "IPv6 support is optional.",
            artifacts: [],
            artifactSections: [],
            analytics: [
                CatalogDetailMetric(title: "Installs (30d)", value: "26,952")
            ]
        )
        let viewModel = makeCatalogModel()
        viewModel.packagesState = .loaded([package])
        viewModel.activeFilters = [.hasCaveats]
        viewModel.sortOption = .tap
        viewModel.selectedPackage = package
        viewModel.detailState = .loaded(detail)
        let command = detail.actionCommand(for: .fetch)
        viewModel.actionState = .running(
            CatalogPackageActionProgress(
                command: command,
                startedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        viewModel.actionLogs = [
            CatalogPackageActionLogEntry(
                id: 0,
                kind: .system,
                text: "Preparing fetch for wget.",
                timestamp: Date(timeIntervalSince1970: 1_001)
            ),
            CatalogPackageActionLogEntry(
                id: 1,
                kind: .stdout,
                text: "Downloading...",
                timestamp: Date(timeIntervalSince1970: 1_002)
            )
        ]
        viewModel.actionHistory = [
            CatalogPackageActionHistoryEntry(
                id: 0,
                command: command,
                startedAt: Date(timeIntervalSince1970: 900),
                finishedAt: Date(timeIntervalSince1970: 950),
                outcome: .succeeded(0),
                outputLineCount: 4
            )
        ]

        XCTAssertNotNil(render(CatalogView(viewModel: viewModel)))
    }

    func testInstalledPackagesViewRendersLoadedState() {
        let package = InstalledPackage(
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
            linkedVersion: "1.25.0",
            isPinned: true,
            isLinked: true,
            isLeaf: true,
            isOutdated: false,
            isInstalledOnRequest: true,
            isInstalledAsDependency: false,
            autoUpdates: false,
            isDeprecated: false,
            isDisabled: false,
            directDependencies: ["openssl@3"],
            buildDependencies: ["pkgconf"],
            testDependencies: [],
            recommendedDependencies: [],
            optionalDependencies: [],
            requirements: ["xcode 15.3 (build)"],
            directRuntimeDependencies: ["openssl@3"],
            runtimeDependencies: ["openssl@3"]
        )
        let viewModel = makeInstalledPackagesModel()
        viewModel.packagesState = .loaded([package])
        viewModel.selectedPackage = package

        XCTAssertNotNil(render(InstalledPackagesView(viewModel: viewModel)))
    }

    func testOutdatedPackagesViewRendersLoadedState() {
        let package = OutdatedPackage(
            kind: .formula,
            slug: "wget",
            title: "wget",
            fullName: "homebrew/core/wget",
            installedVersions: ["1.24.5"],
            currentVersion: "1.25.0",
            isPinned: true,
            pinnedVersion: "1.24.5"
        )
        let viewModel = makeOutdatedPackagesModel()
        viewModel.packagesState = .loaded([package])
        viewModel.selectedPackage = package

        XCTAssertNotNil(render(OutdatedPackagesView(viewModel: viewModel)))
    }

    private func makeModel() -> AppModel {
        AppModel(
            brewLocator: ViewTestBrewLocator(),
            helpResolver: ViewTestHelpResolver(),
            urlOpener: ViewTestURLOpener(),
            aboutPanelPresenter: ViewTestAboutPanelPresenter()
        )
    }

    private func makeCatalogModel() -> CatalogViewModel {
        CatalogViewModel(
            apiClient: ViewTestCatalogAPIClient(),
            commandExecutor: ViewTestBrewCommandExecutor()
        )
    }

    private func makeInstalledPackagesModel() -> InstalledPackagesViewModel {
        InstalledPackagesViewModel(
            provider: ViewTestInstalledPackagesProvider()
        )
    }

    private func makeOutdatedPackagesModel() -> OutdatedPackagesViewModel {
        OutdatedPackagesViewModel(
            provider: ViewTestOutdatedPackagesProvider()
        )
    }

    private func render<Content: View>(_ view: Content) -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: view)
        hostingView.layoutSubtreeIfNeeded()
        _ = hostingView.fittingSize
        return hostingView
    }
}

private struct ViewTestBrewLocator: BrewLocating {
    func locate() async throws -> HomebrewInstallation {
        .fixture()
    }
}

private struct ViewTestHelpResolver: HelpDocumentResolving {
    func helpURL(anchor: HelpAnchor) throws -> URL {
        URL(fileURLWithPath: "/Bundle/Help/index.html")
    }
}

private struct ViewTestURLOpener: URLOpening {
    func open(_ url: URL) -> Bool {
        true
    }
}

private struct ViewTestAboutPanelPresenter: AboutPanelPresenting {
    func presentAboutPanel() {}
}

private struct ViewTestCatalogAPIClient: HomebrewAPIClienting, Sendable {
    func fetchCatalog() async throws -> [CatalogPackageSummary] {
        []
    }

    func fetchDetail(for package: CatalogPackageSummary) async throws -> CatalogPackageDetail {
        CatalogPackageDetail(
            kind: package.kind,
            slug: package.slug,
            title: package.title,
            fullName: package.slug,
            aliases: [],
            oldNames: [],
            description: package.subtitle,
            homepage: package.homepage,
            version: package.version,
            tap: "homebrew/core",
            license: nil,
            downloadURL: nil,
            checksum: nil,
            autoUpdates: nil,
            versionDetails: [
                CatalogDetailMetric(title: "Current", value: package.version)
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
    }
}

private struct ViewTestBrewCommandExecutor: BrewCommandExecuting, Sendable {
    func execute(
        command: CatalogPackageActionCommand,
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        await onLog(.system, "$ /opt/homebrew/bin/brew \(command.arguments.joined(separator: " "))")
        return CommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}

private struct ViewTestInstalledPackagesProvider: InstalledPackagesProviding {
    func fetchInstalledPackages() async throws -> [InstalledPackage] {
        []
    }
}

private struct ViewTestOutdatedPackagesProvider: OutdatedPackagesProviding {
    func fetchOutdatedPackages() async throws -> [OutdatedPackage] {
        []
    }
}
