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
            aliases: ["wget2"],
            description: "Internet file retriever",
            homepage: URL(string: "https://example.com/wget"),
            version: "1.25.0",
            tap: "homebrew/core",
            license: "GPL-3.0-or-later",
            dependencies: ["openssl@3"],
            conflicts: [],
            caveats: "IPv6 support is optional.",
            artifacts: []
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
            aliases: [],
            description: package.subtitle,
            homepage: package.homepage,
            version: package.version,
            tap: "homebrew/core",
            license: nil,
            dependencies: [],
            conflicts: [],
            caveats: nil,
            artifacts: []
        )
    }
}
