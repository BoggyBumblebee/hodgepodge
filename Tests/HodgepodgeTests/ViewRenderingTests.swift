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

        model.selectedSection = .overview
        XCTAssertNotNil(render(RootView(model: model, catalogModel: catalogModel)))

        model.selectedSection = .catalog
        XCTAssertNotNil(render(RootView(model: model, catalogModel: catalogModel)))
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
        let package = CatalogPackageSummary(
            kind: .formula,
            slug: "wget",
            title: "wget",
            subtitle: "Internet file retriever",
            version: "1.25.0",
            homepage: nil
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
        viewModel.selectedPackage = package
        viewModel.detailState = .loaded(detail)

        XCTAssertNotNil(render(CatalogView(viewModel: viewModel)))
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
        CatalogViewModel(apiClient: ViewTestCatalogAPIClient())
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
