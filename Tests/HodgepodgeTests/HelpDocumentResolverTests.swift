import XCTest
@testable import Hodgepodge

final class HelpDocumentResolverTests: XCTestCase {
    func testResolverPrefersHelpSubdirectoryAndAppendsAnchor() throws {
        let resolver = HelpDocumentResolver(
            bundle: MockBundle(
                helpURL: URL(fileURLWithPath: "/Bundle/Help/index.html"),
                fallbackURL: URL(fileURLWithPath: "/Bundle/index.html")
            )
        )

        let url = try resolver.helpURL(anchor: .quickStart)

        XCTAssertEqual(url.absoluteString, "file:///Bundle/Help/index.html#quick-start")
    }

    func testResolverFallsBackToRootIndex() throws {
        let resolver = HelpDocumentResolver(
            bundle: MockBundle(
                helpURL: nil,
                fallbackURL: URL(fileURLWithPath: "/Bundle/index.html")
            )
        )

        let url = try resolver.helpURL(anchor: .troubleshooting)

        XCTAssertEqual(url.absoluteString, "file:///Bundle/index.html#troubleshooting")
    }

    func testResolverThrowsWhenNoHelpDocumentExists() {
        let resolver = HelpDocumentResolver(bundle: MockBundle(helpURL: nil, fallbackURL: nil))

        XCTAssertThrowsError(try resolver.helpURL(anchor: .home)) { error in
            XCTAssertEqual(error as? HelpDocumentResolverError, .helpDocumentMissing)
        }
    }
}

private struct MockBundle: BundleResourceQuerying {
    let helpURL: URL?
    let fallbackURL: URL?

    func url(forResource name: String?, withExtension ext: String?, subdirectory subpath: String?) -> URL? {
        helpURL
    }

    func url(forResource name: String?, withExtension ext: String?) -> URL? {
        fallbackURL
    }
}
