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
                      "full_name": "homebrew/core/wget",
                      "aliases": ["wget2"],
                      "oldnames": ["gnu-wget"],
                      "desc": "Internet file retriever",
                      "homepage": "https://example.com/wget",
                      "versions": { "stable": "1.25.0", "head": "HEAD", "bottle": true },
                      "tap": "homebrew/core",
                      "license": "GPL-3.0-or-later",
                      "dependencies": ["libidn2", "openssl@3"],
                      "build_dependencies": ["pkgconf"],
                      "test_dependencies": ["python@3.12"],
                      "recommended_dependencies": [],
                      "optional_dependencies": ["gettext"],
                      "head_dependencies": [],
                      "uses_from_macos": ["zlib"],
                      "requirements": ["macos"],
                      "conflicts_with": ["wgetpaste"],
                      "caveats": "Enable IPv6 manually.",
                      "bottle": {
                        "stable": {
                          "files": {
                            "arm64_sonoma": {
                              "cellar": "/opt/homebrew/Cellar",
                              "url": "https://example.com/bottle",
                              "sha256": "deadbeef"
                            }
                          }
                        }
                      },
                      "variations": {
                        "arm64_linux": {
                          "dependencies": ["openssl@3"]
                        }
                      },
                      "deprecated": false,
                      "deprecation_date": null,
                      "deprecation_reason": null,
                      "deprecation_replacement_formula": null,
                      "deprecation_replacement_cask": null,
                      "disabled": false,
                      "disable_date": null,
                      "disable_reason": null,
                      "disable_replacement_formula": null,
                      "disable_replacement_cask": null,
                      "analytics": {
                        "install": {
                          "30d": { "wget": 1200 },
                          "90d": { "wget": 3600 },
                          "365d": { "wget": 15000 }
                        },
                        "install_on_request": {
                          "30d": { "wget": 1100 },
                          "90d": { "wget": 3300 },
                          "365d": { "wget": 14000 }
                        },
                        "build_error": {
                          "30d": { "wget": 12 }
                        }
                      }
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
        XCTAssertEqual(detail.fullName, "homebrew/core/wget")
        XCTAssertEqual(detail.aliases, ["wget2"])
        XCTAssertEqual(detail.oldNames, ["gnu-wget"])
        XCTAssertEqual(detail.dependencies, ["libidn2", "openssl@3"])
        XCTAssertEqual(detail.conflicts, ["wgetpaste"])
        XCTAssertEqual(detail.license, "GPL-3.0-or-later")
        XCTAssertEqual(detail.caveats, "Enable IPv6 manually.")
        XCTAssertEqual(detail.versionDetails.map(\.title), ["Current", "Stable", "Head", "Bottle Available"])
        XCTAssertEqual(detail.dependencySections.map(\.title), [
            "Runtime Dependencies",
            "Build Dependencies",
            "Test Dependencies",
            "Optional Dependencies",
            "Uses From macOS",
            "Requirements"
        ])
        XCTAssertEqual(detail.platformSections.map(\.title), ["Bottle Platforms", "Variations"])
        XCTAssertEqual(detail.analytics.first?.value, "1,200")
    }

    func testFetchCaskDetailFlattensArtifacts() async throws {
        let client = makeClient { request in
            switch request.url?.path {
            case "/api/cask/docker-desktop.json":
                return .ok(
                    """
                    {
                      "token": "docker-desktop",
                      "full_token": "docker-desktop",
                      "name": ["Docker Desktop", "Docker CE"],
                      "old_tokens": ["docker"],
                      "desc": "Container desktop app",
                      "homepage": "https://example.com/docker",
                      "version": "4.68.0",
                      "tap": "homebrew/cask",
                      "caveats": "Requires Rosetta in some cases.",
                      "depends_on": {
                        "formula": ["docker-compose"],
                        "cask": ["visual-studio-code"],
                        "macos": {">=": ["13.0"]}
                      },
                      "conflicts_with": {
                        "cask": ["rancher"]
                      },
                      "artifacts": [
                        { "app": ["Docker.app"] },
                        { "zap": ["~/Library/Group Containers/group.com.docker"] }
                      ],
                      "variations": {
                        "sonoma": {
                          "url": "https://example.com/docker-sonoma.dmg"
                        }
                      },
                      "url": "https://example.com/docker.dmg",
                      "sha256": "feedface",
                      "auto_updates": true,
                      "deprecated": false,
                      "deprecation_date": null,
                      "deprecation_reason": null,
                      "deprecation_replacement_formula": null,
                      "deprecation_replacement_cask": null,
                      "disabled": false,
                      "disable_date": null,
                      "disable_reason": null,
                      "disable_replacement_formula": null,
                      "disable_replacement_cask": null,
                      "analytics": {
                        "install": {
                          "30d": { "docker-desktop": 5000 },
                          "90d": { "docker-desktop": 12000 },
                          "365d": { "docker-desktop": 44000 }
                        }
                      }
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
        XCTAssertEqual(detail.oldNames, ["docker"])
        XCTAssertEqual(detail.dependencies, ["docker-compose", "visual-studio-code"])
        XCTAssertEqual(detail.conflicts, ["rancher"])
        XCTAssertEqual(detail.artifacts, ["app: Docker.app", "zap: ~/Library/Group Containers/group.com.docker"])
        XCTAssertNil(detail.license)
        XCTAssertEqual(detail.downloadURL, URL(string: "https://example.com/docker.dmg"))
        XCTAssertEqual(detail.checksum, "feedface")
        XCTAssertEqual(detail.autoUpdates, true)
        XCTAssertEqual(detail.platformSections.map(\.title), ["macOS Compatibility", "Platform Variations"])
        XCTAssertEqual(detail.artifactSections.map(\.title), ["App", "Zap"])
    }

    func testFetchCaskDetailAllowsNullDescription() async throws {
        let client = makeClient { request in
            switch request.url?.path {
            case "/api/cask/apptrap.json":
                return .ok(
                    """
                    {
                      "token": "apptrap",
                      "full_token": "apptrap",
                      "name": ["AppTrap"],
                      "old_tokens": [],
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
                      ],
                      "variations": {},
                      "url": "https://onnati.net/apptrap.dmg",
                      "sha256": "123abc",
                      "auto_updates": false,
                      "deprecated": false,
                      "deprecation_date": null,
                      "deprecation_reason": null,
                      "deprecation_replacement_formula": null,
                      "deprecation_replacement_cask": null,
                      "disabled": false,
                      "disable_date": null,
                      "disable_reason": null,
                      "disable_replacement_formula": null,
                      "disable_replacement_cask": null,
                      "analytics": {
                        "install": {
                          "30d": { "apptrap": 100 }
                        }
                      }
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
        XCTAssertEqual(detail.analytics.first?.value, "100")
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
