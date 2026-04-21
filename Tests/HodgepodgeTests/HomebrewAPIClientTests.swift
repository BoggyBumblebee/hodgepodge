import Foundation
import XCTest
@testable import Hodgepodge

final class HomebrewAPIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchCatalogMergesAndSortsFormulaeAndCasks() async throws {
        let client = makeClient { request in
            switch request.url?.lastPathComponent {
            case "formula.json":
                return .ok(
                    """
                    [
                      {
                        "name": "wget",
                        "desc": "Internet file retriever",
                        "homepage": "https://example.com/wget",
                        "versions": { "stable": "1.25.0" }
                      }
                    ]
                    """
                )
            case "cask.json":
                return .ok(
                    """
                    [
                      {
                        "token": "docker-desktop",
                        "name": ["Docker Desktop"],
                        "desc": "Container desktop app",
                        "homepage": "https://example.com/docker",
                        "version": "4.68.0"
                      }
                    ]
                    """
                )
            default:
                return .notFound
            }
        }

        let packages = try await client.fetchCatalog()

        XCTAssertEqual(packages.map(\.title), ["Docker Desktop", "wget"])
        XCTAssertEqual(packages.map(\.kind), [.cask, .formula])
        XCTAssertEqual(packages[0].installCommand, "brew install --cask docker-desktop")
        XCTAssertEqual(packages[1].installCommand, "brew install wget")
    }

    func testFetchCatalogAllowsNullCaskDescription() async throws {
        let client = makeClient { request in
            switch request.url?.lastPathComponent {
            case "formula.json":
                return .ok("[]")
            case "cask.json":
                return .ok(
                    """
                    [
                      {
                        "token": "apptrap",
                        "name": ["AppTrap"],
                        "desc": null,
                        "homepage": "https://onnati.net/apptrap/",
                        "version": "1.3"
                      }
                    ]
                    """
                )
            default:
                return .notFound
            }
        }

        let packages = try await client.fetchCatalog()

        XCTAssertEqual(packages.count, 1)
        XCTAssertEqual(packages[0].title, "AppTrap")
        XCTAssertEqual(packages[0].subtitle, "No description available.")
    }

    func testFetchFormulaDetailDecodesMetadata() async throws {
        let client = makeClient { request in
            switch request.url?.path {
            case "/api/formula/wget.json":
                return .ok(
                    """
                    {
                      "name": "wget",
                      "aliases": ["wget2"],
                      "desc": "Internet file retriever",
                      "homepage": "https://example.com/wget",
                      "versions": { "stable": "1.25.0" },
                      "tap": "homebrew/core",
                      "license": "GPL-3.0-or-later",
                      "dependencies": ["libidn2", "openssl@3"],
                      "conflicts_with": ["wgetpaste"],
                      "caveats": "Enable IPv6 manually."
                    }
                    """
                )
            default:
                return .notFound
            }
        }

        let detail = try await client.fetchDetail(
            for: CatalogPackageSummary(
                kind: .formula,
                slug: "wget",
                title: "wget",
                subtitle: "Internet file retriever",
                version: "1.25.0",
                homepage: URL(string: "https://example.com/wget")
            )
        )

        XCTAssertEqual(detail.slug, "wget")
        XCTAssertEqual(detail.aliases, ["wget2"])
        XCTAssertEqual(detail.dependencies, ["libidn2", "openssl@3"])
        XCTAssertEqual(detail.conflicts, ["wgetpaste"])
        XCTAssertEqual(detail.license, "GPL-3.0-or-later")
        XCTAssertEqual(detail.caveats, "Enable IPv6 manually.")
    }

    func testFetchCaskDetailFlattensArtifacts() async throws {
        let client = makeClient { request in
            switch request.url?.path {
            case "/api/cask/docker-desktop.json":
                return .ok(
                    """
                    {
                      "token": "docker-desktop",
                      "name": ["Docker Desktop", "Docker CE"],
                      "desc": "Container desktop app",
                      "homepage": "https://example.com/docker",
                      "version": "4.68.0",
                      "tap": "homebrew/cask",
                      "caveats": "Requires Rosetta in some cases.",
                      "depends_on": {
                        "formula": ["docker-compose"],
                        "cask": ["visual-studio-code"]
                      },
                      "artifacts": [
                        { "app": ["Docker.app"] },
                        { "zap": ["~/Library/Group Containers/group.com.docker"] }
                      ]
                    }
                    """
                )
            default:
                return .notFound
            }
        }

        let detail = try await client.fetchDetail(
            for: CatalogPackageSummary(
                kind: .cask,
                slug: "docker-desktop",
                title: "Docker Desktop",
                subtitle: "Container desktop app",
                version: "4.68.0",
                homepage: URL(string: "https://example.com/docker")
            )
        )

        XCTAssertEqual(detail.aliases, ["Docker CE"])
        XCTAssertEqual(detail.dependencies, ["docker-compose", "visual-studio-code"])
        XCTAssertEqual(detail.artifacts, ["app: Docker.app", "zap: ~/Library/Group Containers/group.com.docker"])
        XCTAssertNil(detail.license)
    }

    func testFetchCaskDetailAllowsNullDescription() async throws {
        let client = makeClient { request in
            switch request.url?.path {
            case "/api/cask/apptrap.json":
                return .ok(
                    """
                    {
                      "token": "apptrap",
                      "name": ["AppTrap"],
                      "desc": null,
                      "homepage": "https://onnati.net/apptrap/",
                      "version": "1.3",
                      "tap": "homebrew/cask",
                      "caveats": null,
                      "depends_on": {
                        "formula": ["mas"]
                      },
                      "artifacts": [
                        { "app": ["AppTrap.prefPane"] }
                      ]
                    }
                    """
                )
            default:
                return .notFound
            }
        }

        let detail = try await client.fetchDetail(
            for: CatalogPackageSummary(
                kind: .cask,
                slug: "apptrap",
                title: "AppTrap",
                subtitle: "No description available.",
                version: "1.3",
                homepage: URL(string: "https://onnati.net/apptrap/")
            )
        )

        XCTAssertEqual(detail.description, "No description available.")
        XCTAssertEqual(detail.dependencies, ["mas"])
        XCTAssertEqual(detail.artifacts, ["app: AppTrap.prefPane"])
    }

    func testFetchCatalogThrowsForHTTPFailure() async {
        let client = makeClient { _ in .status(503, "{}") }

        do {
            _ = try await client.fetchCatalog()
            XCTFail("Expected request failure.")
        } catch {
            XCTAssertEqual(error as? HomebrewAPIClientError, .requestFailed(503))
        }
    }

    private func makeClient(handler: @escaping @Sendable (URLRequest) -> MockURLProtocol.Response) -> HomebrewAPIClient {
        MockURLProtocol.handler = handler

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]

        return HomebrewAPIClient(
            session: URLSession(configuration: configuration),
            baseURL: URL(string: "https://formulae.brew.sh/api/")!
        )
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    enum Response {
        case status(Int, String)

        static func ok(_ body: String) -> Response {
            .status(200, body)
        }

        static let notFound = Response.status(404, "{}")
    }

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> Response)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let handler = Self.handler,
            let url = request.url
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let response = handler(request)
        let (statusCode, body): (Int, String)

        switch response {
        case .status(let code, let responseBody):
            statusCode = code
            body = responseBody
        }

        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
