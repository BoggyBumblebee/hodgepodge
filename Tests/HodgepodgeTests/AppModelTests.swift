import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class AppModelTests: XCTestCase {
    func testLoadIfNeededRefreshesWhenIdle() async {
        let expectedInstallation = HomebrewInstallation.fixture()
        let brewLocator = MockBrewLocator(result: .success(expectedInstallation))
        let model = AppModel(
            brewLocator: brewLocator,
            helpResolver: MockHelpResolver(),
            urlOpener: MockURLOpener(),
            aboutPanelPresenter: MockAboutPanelPresenter()
        )

        model.loadIfNeeded()
        await settleAsyncState()

        XCTAssertEqual(model.installationState, .loaded(expectedInstallation))
    }

    func testLoadIfNeededDoesNotRefreshWhenAlreadyLoaded() async {
        let brewLocator = MockBrewLocator(result: .success(.fixture()))
        let model = AppModel(
            brewLocator: brewLocator,
            helpResolver: MockHelpResolver(),
            urlOpener: MockURLOpener(),
            aboutPanelPresenter: MockAboutPanelPresenter()
        )
        model.installationState = .loaded(.fixture(version: "existing"))

        model.loadIfNeeded()
        await settleAsyncState()

        XCTAssertEqual(brewLocator.locateCallCount, 0)
    }

    func testRefreshInstallationStoresFailureMessage() async {
        let brewLocator = MockBrewLocator(result: .failure(BrewLocatorError.brewNotFound))
        let model = AppModel(
            brewLocator: brewLocator,
            helpResolver: MockHelpResolver(),
            urlOpener: MockURLOpener(),
            aboutPanelPresenter: MockAboutPanelPresenter()
        )

        model.refreshInstallation()
        await settleAsyncState()

        XCTAssertEqual(
            model.installationState,
            .failed("Homebrew was not found. Install Homebrew or point the app at a valid brew executable.")
        )
    }

    func testOpenAboutPanelDelegatesToPresenter() {
        let presenter = MockAboutPanelPresenter()
        let model = AppModel(
            brewLocator: MockBrewLocator(result: .success(.fixture())),
            helpResolver: MockHelpResolver(),
            urlOpener: MockURLOpener(),
            aboutPanelPresenter: presenter
        )

        model.openAboutPanel()

        XCTAssertEqual(presenter.presentCallCount, 1)
    }

    func testOpenHelpStoresLastOpenedURLWhenOpenSucceeds() {
        let helpURL = URL(fileURLWithPath: "/Bundle/Help/index.html")
        let urlOpener = MockURLOpener(openResult: true)
        let model = AppModel(
            brewLocator: MockBrewLocator(result: .success(.fixture())),
            helpResolver: MockHelpResolver(result: .success(helpURL)),
            urlOpener: urlOpener,
            aboutPanelPresenter: MockAboutPanelPresenter()
        )

        model.openHelp(anchor: .home)

        XCTAssertEqual(model.lastOpenedHelpURL, helpURL)
        XCTAssertEqual(urlOpener.openedURLs, [helpURL])
    }

    func testOpenHelpStoresFailureWhenURLCannotBeOpened() {
        let helpURL = URL(fileURLWithPath: "/Bundle/Help/index.html")
        let model = AppModel(
            brewLocator: MockBrewLocator(result: .success(.fixture())),
            helpResolver: MockHelpResolver(result: .success(helpURL)),
            urlOpener: MockURLOpener(openResult: false),
            aboutPanelPresenter: MockAboutPanelPresenter()
        )

        model.openHelp(anchor: .quickStart)

        XCTAssertEqual(model.installationState, .failed("Help could not be opened from the app bundle."))
    }

    func testOpenHelpStoresResolverFailure() {
        let model = AppModel(
            brewLocator: MockBrewLocator(result: .success(.fixture())),
            helpResolver: MockHelpResolver(result: .failure(HelpDocumentResolverError.helpDocumentMissing)),
            urlOpener: MockURLOpener(),
            aboutPanelPresenter: MockAboutPanelPresenter()
        )

        model.openHelp(anchor: .troubleshooting)

        XCTAssertEqual(
            model.installationState,
            .failed("Help documentation could not be found in the application bundle.")
        )
    }

private func settleAsyncState() async {
        await Task.yield()
        await Task.yield()
    }
}

private final class MockBrewLocator: BrewLocating {
    let result: Result<HomebrewInstallation, Error>
    private(set) var locateCallCount = 0

    init(result: Result<HomebrewInstallation, Error>) {
        self.result = result
    }

    func locate() async throws -> HomebrewInstallation {
        locateCallCount += 1
        return try result.get()
    }
}

private struct MockHelpResolver: HelpDocumentResolving {
    let result: Result<URL, Error>

    init(result: Result<URL, Error> = .success(URL(fileURLWithPath: "/Bundle/Help/index.html"))) {
        self.result = result
    }

    func helpURL(anchor: HelpAnchor) throws -> URL {
        try result.get()
    }
}

private final class MockURLOpener: URLOpening {
    let openResult: Bool
    private(set) var openedURLs: [URL] = []

    init(openResult: Bool = true) {
        self.openResult = openResult
    }

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return openResult
    }
}

private final class MockAboutPanelPresenter: AboutPanelPresenting {
    private(set) var presentCallCount = 0

    func presentAboutPanel() {
        presentCallCount += 1
    }
}
