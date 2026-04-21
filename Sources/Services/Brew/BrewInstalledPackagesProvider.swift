import Foundation

protocol InstalledPackagesProviding: Sendable {
    func fetchInstalledPackages() async throws -> [InstalledPackage]
}

private let installedPackagesFallbackDescription = "No description available."

struct BrewInstalledPackagesProvider: InstalledPackagesProviding, @unchecked Sendable {
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

    func fetchInstalledPackages() async throws -> [InstalledPackage] {
        let installation = try await brewLocator.locate()
        let result = try await runner.run(
            executable: installation.brewPath,
            arguments: ["info", "--json=v2", "--installed"]
        )
        let leafFormulae = try await fetchLeafFormulae(using: installation.brewPath)
        let response = try decoder.decode(InstalledPackagesResponse.self, from: Data(result.stdout.utf8))

        return (
            response.formulae.map { InstalledPackage($0, leafFormulae: leafFormulae) } +
            response.casks.map(InstalledPackage.init)
        )
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private func fetchLeafFormulae(using brewPath: String) async throws -> Set<String> {
        let result = try await runner.run(
            executable: brewPath,
            arguments: ["leaves"]
        )

        let formulae = result.stdout
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Set(formulae)
    }
}

private struct InstalledPackagesResponse: Decodable {
    let formulae: [InstalledFormulaResponse]
    let casks: [InstalledCaskResponse]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formulae = try container.decodeIfPresent([InstalledFormulaResponse].self, forKey: .formulae) ?? []
        casks = try container.decodeIfPresent([InstalledCaskResponse].self, forKey: .casks) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case formulae
        case casks
    }
}

private struct InstalledFormulaResponse: Decodable {
    let name: String
    let fullName: String
    let tap: String
    let desc: String?
    let homepage: URL?
    let aliases: [String]
    let oldnames: [String]
    let versions: VersionsResponse
    let installed: [InstalledVersionResponse]
    let linkedKeg: String?
    let pinned: Bool
    let outdated: Bool
    let deprecated: Bool
    let disabled: Bool

    private enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case tap
        case desc
        case homepage
        case aliases
        case oldnames
        case versions
        case installed
        case linkedKeg = "linked_keg"
        case pinned
        case outdated
        case deprecated
        case disabled
    }

    struct VersionsResponse: Decodable {
        let stable: String?
        let head: String?
    }

    struct InstalledVersionResponse: Decodable {
        let version: String
        let time: TimeInterval?
        let runtimeDependencies: [RuntimeDependencyResponse]
        let installedAsDependency: Bool
        let installedOnRequest: Bool

        private enum CodingKeys: String, CodingKey {
            case version
            case time
            case runtimeDependencies = "runtime_dependencies"
            case installedAsDependency = "installed_as_dependency"
            case installedOnRequest = "installed_on_request"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decode(String.self, forKey: .version)
            time = try container.decodeIfPresent(TimeInterval.self, forKey: .time)
            runtimeDependencies = try container.decodeIfPresent([RuntimeDependencyResponse].self, forKey: .runtimeDependencies) ?? []
            installedAsDependency = try container.decodeIfPresent(Bool.self, forKey: .installedAsDependency) ?? false
            installedOnRequest = try container.decodeIfPresent(Bool.self, forKey: .installedOnRequest) ?? false
        }
    }

    struct RuntimeDependencyResponse: Decodable {
        let fullName: String

        private enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        fullName = try container.decode(String.self, forKey: .fullName)
        tap = try container.decode(String.self, forKey: .tap)
        desc = try container.decodeIfPresent(String.self, forKey: .desc)
        homepage = try container.decodeIfPresent(URL.self, forKey: .homepage)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        oldnames = try container.decodeIfPresent([String].self, forKey: .oldnames) ?? []
        versions = try container.decode(VersionsResponse.self, forKey: .versions)
        installed = try container.decodeIfPresent([InstalledVersionResponse].self, forKey: .installed) ?? []
        linkedKeg = try container.decodeIfPresent(String.self, forKey: .linkedKeg)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        outdated = try container.decodeIfPresent(Bool.self, forKey: .outdated) ?? false
        deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false
        disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled) ?? false
    }
}

private struct InstalledCaskResponse: Decodable {
    let token: String
    let fullToken: String
    let tap: String
    let name: [String]
    let desc: String?
    let homepage: URL?
    let version: String
    let installedVersion: String?
    let installedTime: TimeInterval?
    let outdated: Bool
    let autoUpdates: Bool
    let deprecated: Bool
    let disabled: Bool

    private enum CodingKeys: String, CodingKey {
        case token
        case fullToken = "full_token"
        case tap
        case name
        case desc
        case homepage
        case version
        case installedVersion = "installed"
        case installedTime = "installed_time"
        case outdated
        case autoUpdates = "auto_updates"
        case deprecated
        case disabled
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)
        fullToken = try container.decode(String.self, forKey: .fullToken)
        tap = try container.decode(String.self, forKey: .tap)
        name = try container.decodeIfPresent([String].self, forKey: .name) ?? []
        desc = try container.decodeIfPresent(String.self, forKey: .desc)
        homepage = try container.decodeIfPresent(URL.self, forKey: .homepage)
        version = try container.decode(String.self, forKey: .version)
        installedVersion = try container.decodeIfPresent(String.self, forKey: .installedVersion)
        installedTime = try container.decodeIfPresent(TimeInterval.self, forKey: .installedTime)
        outdated = try container.decodeIfPresent(Bool.self, forKey: .outdated) ?? false
        autoUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoUpdates) ?? false
        deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false
        disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled) ?? false
    }
}

private extension InstalledPackage {
    init(_ response: InstalledFormulaResponse, leafFormulae: Set<String>) {
        let installedVersions = response.installed.map(\.version)
        let latestInstallTime = response.installed.compactMap(\.time).max()
        let runtimeDependencies = Array(
            Set(response.installed.flatMap { $0.runtimeDependencies.map(\.fullName) })
        ).sorted()
        let isLeaf = leafFormulae.contains(response.name) || leafFormulae.contains(response.fullName)
        let selectedVersion = response.linkedKeg
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? installedVersions.last
            ?? response.versions.stable
            ?? response.versions.head
            ?? "Unknown"

        self.init(
            kind: .formula,
            slug: response.name,
            title: response.name,
            fullName: response.fullName,
            subtitle: response.desc ?? installedPackagesFallbackDescription,
            version: selectedVersion,
            homepage: response.homepage,
            tap: response.tap,
            installedVersions: installedVersions,
            installedAt: latestInstallTime.map(Date.init(timeIntervalSince1970:)),
            linkedVersion: response.linkedKeg,
            isPinned: response.pinned,
            isLinked: response.linkedKeg?.isEmpty == false,
            isLeaf: isLeaf,
            isOutdated: response.outdated,
            isInstalledOnRequest: response.installed.contains { $0.installedOnRequest },
            isInstalledAsDependency: response.installed.contains { $0.installedAsDependency },
            autoUpdates: false,
            isDeprecated: response.deprecated,
            isDisabled: response.disabled,
            runtimeDependencies: runtimeDependencies
        )
    }

    init(_ response: InstalledCaskResponse) {
        let selectedVersion = response.installedVersion ?? response.version

        self.init(
            kind: .cask,
            slug: response.token,
            title: response.name.first ?? response.token,
            fullName: response.fullToken,
            subtitle: response.desc ?? installedPackagesFallbackDescription,
            version: selectedVersion,
            homepage: response.homepage,
            tap: response.tap,
            installedVersions: [selectedVersion],
            installedAt: response.installedTime.map(Date.init(timeIntervalSince1970:)),
            linkedVersion: nil,
            isPinned: false,
            isLinked: false,
            isLeaf: false,
            isOutdated: response.outdated,
            isInstalledOnRequest: true,
            isInstalledAsDependency: false,
            autoUpdates: response.autoUpdates,
            isDeprecated: response.deprecated,
            isDisabled: response.disabled,
            runtimeDependencies: []
        )
    }
}
