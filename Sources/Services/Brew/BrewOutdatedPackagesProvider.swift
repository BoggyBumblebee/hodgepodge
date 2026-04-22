import Foundation

protocol OutdatedPackagesProviding: Sendable {
    func fetchOutdatedPackages() async throws -> [OutdatedPackage]
}

struct BrewOutdatedPackagesProvider: OutdatedPackagesProviding, @unchecked Sendable {
    private let brewLocator: any BrewLocating
    private let runner: any CommandRunning
    private let decoder: JSONDecoder

    init(
        brewLocator: any BrewLocating,
        runner: any CommandRunning,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.brewLocator = brewLocator
        self.runner = runner
        self.decoder = decoder
    }

    func fetchOutdatedPackages() async throws -> [OutdatedPackage] {
        let installation = try await brewLocator.locate()
        let result = try await runner.run(
            executable: installation.brewPath,
            arguments: try installation.compatibility.outdatedArguments()
        )
        let response = try decoder.decode(OutdatedPackagesResponse.self, from: Data(result.stdout.utf8))

        return (response.formulae.map(OutdatedPackage.init) + response.casks.map(OutdatedPackage.init))
            .sorted { lhs, rhs in
                let result = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
                return lhs.slug < rhs.slug
            }
    }
}

private struct OutdatedPackagesResponse: Decodable {
    let formulae: [OutdatedFormulaResponse]
    let casks: [OutdatedCaskResponse]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formulae = try container.decodeIfPresent([OutdatedFormulaResponse].self, forKey: .formulae) ?? []
        casks = try container.decodeIfPresent([OutdatedCaskResponse].self, forKey: .casks) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case formulae
        case casks
    }
}

private struct OutdatedFormulaResponse: Decodable {
    let fullName: String
    let installedVersions: [String]
    let currentVersion: String
    let pinned: Bool
    let pinnedVersion: String?

    private enum CodingKeys: String, CodingKey {
        case fullName = "name"
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
        case pinned
        case pinnedVersion = "pinned_version"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fullName = try container.decode(String.self, forKey: .fullName)
        installedVersions = try container.decodeIfPresent([String].self, forKey: .installedVersions) ?? []
        currentVersion = try container.decode(String.self, forKey: .currentVersion)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        pinnedVersion = try container.decodeIfPresent(String.self, forKey: .pinnedVersion)
    }
}

private struct OutdatedCaskResponse: Decodable {
    let token: String
    let installedVersions: [String]
    let currentVersion: String

    private enum CodingKeys: String, CodingKey {
        case token = "name"
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)
        installedVersions = try container.decodeIfPresent([String].self, forKey: .installedVersions) ?? []
        currentVersion = try container.decode(String.self, forKey: .currentVersion)
    }
}

private extension OutdatedPackage {
    init(_ response: OutdatedFormulaResponse) {
        let components = response.fullName.split(separator: "/").map(String.init)
        let slug = components.last ?? response.fullName

        self.init(
            kind: .formula,
            slug: slug,
            title: slug,
            fullName: response.fullName,
            installedVersions: response.installedVersions,
            currentVersion: response.currentVersion,
            isPinned: response.pinned,
            pinnedVersion: response.pinnedVersion
        )
    }

    init(_ response: OutdatedCaskResponse) {
        self.init(
            kind: .cask,
            slug: response.token,
            title: response.token,
            fullName: response.token,
            installedVersions: response.installedVersions,
            currentVersion: response.currentVersion,
            isPinned: false,
            pinnedVersion: nil
        )
    }
}
