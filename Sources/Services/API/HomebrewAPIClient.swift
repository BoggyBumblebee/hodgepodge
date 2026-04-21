import Foundation

protocol HomebrewAPIClienting: Sendable {
    func fetchCatalog() async throws -> [CatalogPackageSummary]
    func fetchDetail(for package: CatalogPackageSummary) async throws -> CatalogPackageDetail
}

enum HomebrewAPIClientError: LocalizedError, Equatable {
    case invalidResponse
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The Homebrew API returned an invalid response."
        case .requestFailed(let statusCode):
            "The Homebrew API request failed with status code \(statusCode)."
        }
    }
}

struct HomebrewAPIClient: HomebrewAPIClienting, @unchecked Sendable {
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://formulae.brew.sh/api/")!,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.baseURL = baseURL
        self.decoder = decoder
    }

    func fetchCatalog() async throws -> [CatalogPackageSummary] {
        async let formulae: [FormulaSummaryResponse] = fetchJSON(path: "formula.json")
        async let casks: [CaskSummaryResponse] = fetchJSON(path: "cask.json")

        let formulaeResponses = try await formulae
        let caskResponses = try await casks

        let mappedFormulae = formulaeResponses.map(CatalogPackageSummary.init)
        let mappedCasks = caskResponses.map(CatalogPackageSummary.init)

        return (mappedFormulae + mappedCasks)
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    func fetchDetail(for package: CatalogPackageSummary) async throws -> CatalogPackageDetail {
        switch package.kind {
        case .formula:
            let response: FormulaDetailResponse = try await fetchJSON(path: "formula/\(package.slug).json")
            return CatalogPackageDetail(response: response)
        case .cask:
            let response: CaskDetailResponse = try await fetchJSON(path: "cask/\(package.slug).json")
            return CatalogPackageDetail(response: response)
        }
    }

    private func fetchJSON<Response: Decodable>(path: String) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HomebrewAPIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HomebrewAPIClientError.requestFailed(httpResponse.statusCode)
        }

        return try decoder.decode(Response.self, from: data)
    }
}

private struct FormulaSummaryResponse: Decodable {
    let name: String
    let desc: String?
    let homepage: URL?
    let versions: VersionsResponse

    struct VersionsResponse: Decodable {
        let stable: String?
    }
}

private struct CaskSummaryResponse: Decodable {
    let token: String
    let name: [String]
    let desc: String?
    let homepage: URL?
    let version: String
}

private struct FormulaDetailResponse: Decodable {
    let name: String
    let aliases: [String]
    let desc: String?
    let homepage: URL?
    let versions: FormulaSummaryResponse.VersionsResponse
    let tap: String
    let license: String?
    let dependencies: [String]
    let conflictsWith: [String]
    let caveats: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case aliases
        case desc
        case homepage
        case versions
        case tap
        case license
        case dependencies
        case conflictsWith = "conflicts_with"
        case caveats
    }
}

private struct CaskDetailResponse: Decodable {
    let token: String
    let name: [String]
    let desc: String?
    let homepage: URL?
    let version: String
    let tap: String
    let caveats: String?
    let dependsOn: CaskDependenciesResponse?
    let artifacts: [JSONValue]

    private enum CodingKeys: String, CodingKey {
        case token
        case name
        case desc
        case homepage
        case version
        case tap
        case caveats
        case dependsOn = "depends_on"
        case artifacts
    }
}

private struct CaskDependenciesResponse: Decodable {
    let formula: [String]?
    let cask: [String]?
}

private extension CatalogPackageSummary {
    static let fallbackDescription = "No description available."

    init(response: FormulaSummaryResponse) {
        self.init(
            kind: .formula,
            slug: response.name,
            title: response.name,
            subtitle: response.desc ?? Self.fallbackDescription,
            version: response.versions.stable ?? "Unknown",
            homepage: response.homepage
        )
    }

    init(response: CaskSummaryResponse) {
        self.init(
            kind: .cask,
            slug: response.token,
            title: response.name.first ?? response.token,
            subtitle: response.desc ?? Self.fallbackDescription,
            version: response.version,
            homepage: response.homepage
        )
    }
}

private extension CatalogPackageDetail {
    init(response: FormulaDetailResponse) {
        self.init(
            kind: .formula,
            slug: response.name,
            title: response.name,
            aliases: response.aliases,
            description: response.desc ?? CatalogPackageSummary.fallbackDescription,
            homepage: response.homepage,
            version: response.versions.stable ?? "Unknown",
            tap: response.tap,
            license: response.license,
            dependencies: response.dependencies,
            conflicts: response.conflictsWith,
            caveats: response.caveats,
            artifacts: []
        )
    }

    init(response: CaskDetailResponse) {
        let dependencies = (response.dependsOn?.formula ?? []) + (response.dependsOn?.cask ?? [])
        let artifacts = response.artifacts
            .map(\.flattenedDescription)
            .filter { !$0.isEmpty }

        self.init(
            kind: .cask,
            slug: response.token,
            title: response.name.first ?? response.token,
            aliases: response.name.dropFirst().map { $0 },
            description: response.desc ?? CatalogPackageSummary.fallbackDescription,
            homepage: response.homepage,
            version: response.version,
            tap: response.tap,
            license: nil,
            dependencies: dependencies,
            conflicts: [],
            caveats: response.caveats,
            artifacts: artifacts
        )
    }
}
