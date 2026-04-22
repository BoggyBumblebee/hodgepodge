import AppKit
import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class AppKitIntegrationTests: XCTestCase {
    func testWorkspaceURLOpenerDelegatesToWorkspace() {
        let workspace = MockWorkspace()
        let opener = WorkspaceURLOpener(workspace: workspace)
        let url = URL(string: "https://example.com/help")!

        let result = opener.open(url)

        XCTAssertTrue(result)
        XCTAssertEqual(workspace.openedURLs, [url])
    }

    func testAppIconResolverPrefersApplicationIcon() {
        let expectedIcon = NSImage(size: NSSize(width: 128, height: 128))
        let resolvedIcon = AppIconResolver.resolvedApplicationIcon(
            bundle: MockBundleImageQuery(bundlePath: "/Bundle", image: makeInvalidImage()),
            workspace: MockWorkspaceFileIconProvider(icon: makeInvalidImage()),
            application: MockApplicationIconProvider(icon: expectedIcon)
        )

        XCTAssertEqual(resolvedIcon, expectedIcon)
    }

    func testAppIconResolverFallsBackToWorkspaceIcon() {
        let expectedIcon = NSImage(size: NSSize(width: 64, height: 64))
        let resolvedIcon = AppIconResolver.resolvedApplicationIcon(
            bundle: MockBundleImageQuery(bundlePath: "/Bundle", image: makeInvalidImage()),
            workspace: MockWorkspaceFileIconProvider(icon: expectedIcon),
            application: MockApplicationIconProvider(icon: nil)
        )

        XCTAssertEqual(resolvedIcon, expectedIcon)
    }

    func testAppIconResolverFallsBackToBundledIcon() {
        let expectedIcon = NSImage(size: NSSize(width: 32, height: 32))
        let bundle = MockBundleImageQuery(bundlePath: "/Bundle", image: expectedIcon)
        let resolvedIcon = AppIconResolver.resolvedApplicationIcon(
            bundle: bundle,
            workspace: MockWorkspaceFileIconProvider(icon: makeInvalidImage()),
            application: MockApplicationIconProvider(icon: nil)
        )

        XCTAssertEqual(resolvedIcon, expectedIcon)
        XCTAssertEqual(bundle.requestedNames, ["AppBrandIcon"])
    }

    func testAppIconResolverPrefersBundledBrandIconOverWorkspaceFallback() {
        let expectedIcon = NSImage(size: NSSize(width: 48, height: 48))
        let bundle = MockBundleImageQuery(
            bundlePath: "/Bundle",
            imageForName: { name in
                name == "AppBrandIcon" ? expectedIcon : nil
            }
        )

        let resolvedIcon = AppIconResolver.resolvedApplicationIcon(
            bundle: bundle,
            workspace: MockWorkspaceFileIconProvider(icon: NSImage(size: NSSize(width: 16, height: 16))),
            application: MockApplicationIconProvider(icon: nil)
        )

        XCTAssertEqual(resolvedIcon, expectedIcon)
        XCTAssertEqual(bundle.requestedNames, ["AppBrandIcon"])
    }

    func testStandardAboutPanelPresenterUsesResolvedIconAndAppName() {
        let application = MockAboutPanelApplication()
        let expectedIcon = NSImage(size: NSSize(width: 32, height: 32))
        let presenter = StandardAboutPanelPresenter(
            application: application,
            iconResolver: { expectedIcon }
        )

        presenter.presentAboutPanel()

        XCTAssertTrue(application.didActivate)
        XCTAssertEqual(application.receivedOptions?[.applicationName] as? String, "Hodgepodge")
        XCTAssertEqual(application.receivedOptions?[.applicationIcon] as? NSImage, expectedIcon)
    }

    func testStandardAboutPanelPresenterOmitsIconWhenUnavailable() {
        let application = MockAboutPanelApplication()
        let presenter = StandardAboutPanelPresenter(
            application: application,
            iconResolver: { nil }
        )

        presenter.presentAboutPanel()

        XCTAssertNil(application.receivedOptions?[.applicationIcon])
    }

    func testErrorDescriptionsAreUserFriendly() {
        XCTAssertEqual(
            HelpDocumentResolverError.helpDocumentMissing.errorDescription,
            "Help documentation could not be found in the application bundle."
        )
        XCTAssertEqual(
            BrewLocatorError.brewNotFound.errorDescription,
            "Homebrew was not found. Install Homebrew or point the app at a valid brew executable."
        )
        XCTAssertEqual(
            CommandRunnerError.nonZeroExitCode(
                CommandResult(stdout: "", stderr: "boom\n", exitCode: 1)
            ).errorDescription,
            "boom"
        )
        XCTAssertEqual(
            CommandRunnerError.nonZeroExitCode(
                CommandResult(stdout: "", stderr: "", exitCode: 5)
            ).errorDescription,
            "The command failed with exit code 5."
        )
        XCTAssertEqual(
            CommandRunnerError.unreadablePipe.errorDescription,
            "The command output could not be read."
        )
    }

    private func makeInvalidImage() -> NSImage {
        NSImage(size: .zero)
    }
}

private final class MockWorkspace: WorkspaceOpening {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }
}

private struct MockApplicationIconProvider: ApplicationIconImageProviding {
    let icon: NSImage?

    var resolvedApplicationIconImage: NSImage? {
        icon
    }
}

private final class MockWorkspaceFileIconProvider: WorkspaceFileIconProviding {
    let iconToReturn: NSImage

    init(icon: NSImage) {
        self.iconToReturn = icon
    }

    func icon(forFile path: String) -> NSImage {
        iconToReturn
    }
}

private final class MockBundleImageQuery: BundleImageResourceQuerying {
    let bundlePath: String
    let imageForName: (String) -> NSImage?
    private(set) var requestedNames: [String] = []

    init(bundlePath: String, image: NSImage?) {
        self.bundlePath = bundlePath
        self.imageForName = { _ in image }
    }

    init(bundlePath: String, imageForName: @escaping (String) -> NSImage?) {
        self.bundlePath = bundlePath
        self.imageForName = imageForName
    }

    func image(named name: String) -> NSImage? {
        requestedNames.append(name)
        return imageForName(name)
    }
}

private final class MockAboutPanelApplication: AboutPanelApplicationControlling {
    private(set) var didActivate = false
    private(set) var receivedOptions: [NSApplication.AboutPanelOptionKey: Any]?

    func activate(ignoringOtherApps flag: Bool) {
        didActivate = flag
    }

    func orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey: Any]) {
        receivedOptions = options
    }
}
