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
    let tap: String
    let caveats: String?
    let deprecated: Bool
    let disabled: Bool
    let versions: VersionsResponse

    struct VersionsResponse: Decodable {
        let stable: String?
        let head: String?
        let bottle: Bool?
    }
}

private struct CaskSummaryResponse: Decodable {
    let token: String
    let name: [String]
    let desc: String?
    let homepage: URL?
    let tap: String
    let caveats: String?
    let deprecated: Bool
    let disabled: Bool
    let autoUpdates: Bool?
    let version: String

    private enum CodingKeys: String, CodingKey {
        case token
        case name
        case desc
        case homepage
        case tap
        case caveats
        case deprecated
        case disabled
        case autoUpdates = "auto_updates"
        case version
    }
}

private struct FormulaDetailResponse: Decodable {
    let name: String
    let fullName: String
    let aliases: [String]
    let oldnames: [String]
    let desc: String?
    let homepage: URL?
    let versions: FormulaSummaryResponse.VersionsResponse
    let tap: String
    let license: String?
    let dependencies: [String]
    let buildDependencies: [String]
    let testDependencies: [String]
    let recommendedDependencies: [String]
    let optionalDependencies: [String]
    let headDependencies: [String]
    let usesFromMacOS: [String]
    let requirements: [JSONValue]
    let conflictsWith: [String]
    let caveats: String?
    let bottle: BottleResponse?
    let variations: [String: JSONValue]
    let deprecated: Bool
    let deprecationDate: String?
    let deprecationReason: String?
    let deprecationReplacementFormula: String?
    let deprecationReplacementCask: String?
    let disabled: Bool
    let disableDate: String?
    let disableReason: String?
    let disableReplacementFormula: String?
    let disableReplacementCask: String?
    let analytics: AnalyticsResponse?

    private enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case aliases
        case oldnames
        case desc
        case homepage
        case versions
        case tap
        case license
        case dependencies
        case buildDependencies = "build_dependencies"
        case testDependencies = "test_dependencies"
        case recommendedDependencies = "recommended_dependencies"
        case optionalDependencies = "optional_dependencies"
        case headDependencies = "head_dependencies"
        case usesFromMacOS = "uses_from_macos"
        case requirements
        case conflictsWith = "conflicts_with"
        case caveats
        case bottle
        case variations
        case deprecated
        case deprecationDate = "deprecation_date"
        case deprecationReason = "deprecation_reason"
        case deprecationReplacementFormula = "deprecation_replacement_formula"
        case deprecationReplacementCask = "deprecation_replacement_cask"
        case disabled
        case disableDate = "disable_date"
        case disableReason = "disable_reason"
        case disableReplacementFormula = "disable_replacement_formula"
        case disableReplacementCask = "disable_replacement_cask"
        case analytics
    }
}

private struct CaskDetailResponse: Decodable {
    let token: String
    let fullToken: String
    let name: [String]
    let oldTokens: [String]
    let desc: String?
    let homepage: URL?
    let version: String
    let tap: String
    let caveats: String?
    let dependsOn: [String: JSONValue]?
    let conflictsWith: [String: JSONValue]?
    let artifacts: [JSONValue]
    let variations: [String: JSONValue]
    let downloadURL: URL?
    let checksum: String?
    let autoUpdates: Bool?
    let deprecated: Bool
    let deprecationDate: String?
    let deprecationReason: String?
    let deprecationReplacementFormula: String?
    let deprecationReplacementCask: String?
    let disabled: Bool
    let disableDate: String?
    let disableReason: String?
    let disableReplacementFormula: String?
    let disableReplacementCask: String?
    let analytics: AnalyticsResponse?

    private enum CodingKeys: String, CodingKey {
        case token
        case fullToken = "full_token"
        case name
        case oldTokens = "old_tokens"
        case desc
        case homepage
        case version
        case tap
        case caveats
        case dependsOn = "depends_on"
        case conflictsWith = "conflicts_with"
        case artifacts
        case variations
        case downloadURL = "url"
        case checksum = "sha256"
        case autoUpdates = "auto_updates"
        case deprecated
        case deprecationDate = "deprecation_date"
        case deprecationReason = "deprecation_reason"
        case deprecationReplacementFormula = "deprecation_replacement_formula"
        case deprecationReplacementCask = "deprecation_replacement_cask"
        case disabled
        case disableDate = "disable_date"
        case disableReason = "disable_reason"
        case disableReplacementFormula = "disable_replacement_formula"
        case disableReplacementCask = "disable_replacement_cask"
        case analytics
    }
}

private struct BottleResponse: Decodable {
    let stable: StableBottleResponse?

    struct StableBottleResponse: Decodable {
        let files: [String: BottleFileResponse]
    }

    struct BottleFileResponse: Decodable {
        let cellar: String?
        let url: URL?
        let sha256: String?
    }
}

private struct AnalyticsResponse: Decodable {
    let install: [String: [String: Int]]?
    let installOnRequest: [String: [String: Int]]?
    let buildError: [String: [String: Int]]?

    private enum CodingKeys: String, CodingKey {
        case install
        case installOnRequest = "install_on_request"
        case buildError = "build_error"
    }
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
            homepage: response.homepage,
            tap: response.tap,
            hasCaveats: !(response.caveats?.isEmpty ?? true),
            isDeprecated: response.deprecated,
            isDisabled: response.disabled,
            autoUpdates: false
        )
    }

    init(response: CaskSummaryResponse) {
        self.init(
            kind: .cask,
            slug: response.token,
            title: response.name.first ?? response.token,
            subtitle: response.desc ?? Self.fallbackDescription,
            version: response.version,
            homepage: response.homepage,
            tap: response.tap,
            hasCaveats: !(response.caveats?.isEmpty ?? true),
            isDeprecated: response.deprecated,
            isDisabled: response.disabled,
            autoUpdates: response.autoUpdates ?? false
        )
    }
}

private extension CatalogPackageDetail {
    init(response: FormulaDetailResponse) {
        let dependencySections = [
            Self.makeTagSection("Runtime Dependencies", response.dependencies),
            Self.makeTagSection("Build Dependencies", response.buildDependencies),
            Self.makeTagSection("Test Dependencies", response.testDependencies),
            Self.makeTagSection("Recommended Dependencies", response.recommendedDependencies),
            Self.makeTagSection("Optional Dependencies", response.optionalDependencies),
            Self.makeTagSection("Head Dependencies", response.headDependencies),
            Self.makeTagSection("Uses From macOS", response.usesFromMacOS),
            Self.makeListSection("Requirements", response.requirements.flatMap(\.flattenedItems))
        ]
        .compactMap { $0 }

        let bottlePlatforms = response.bottle?.stable?.files.keys.sorted() ?? []
        let platformSections = [
            Self.makeTagSection("Bottle Platforms", bottlePlatforms),
            Self.makeTagSection("Variations", response.variations.keys.sorted())
        ]
        .compactMap { $0 }

        let lifecycleSections = Self.makeLifecycleSections(
            conflicts: response.conflictsWith,
            deprecated: response.deprecated,
            deprecationDate: response.deprecationDate,
            deprecationReason: response.deprecationReason,
            deprecationReplacementFormula: response.deprecationReplacementFormula,
            deprecationReplacementCask: response.deprecationReplacementCask,
            disabled: response.disabled,
            disableDate: response.disableDate,
            disableReason: response.disableReason,
            disableReplacementFormula: response.disableReplacementFormula,
            disableReplacementCask: response.disableReplacementCask
        )

        self.init(
            kind: .formula,
            slug: response.name,
            title: response.name,
            fullName: response.fullName,
            aliases: response.aliases,
            oldNames: response.oldnames,
            description: response.desc ?? CatalogPackageSummary.fallbackDescription,
            homepage: response.homepage,
            version: response.versions.stable ?? "Unknown",
            tap: response.tap,
            license: response.license,
            downloadURL: nil,
            checksum: nil,
            autoUpdates: nil,
            versionDetails: Self.makeVersionDetails(
                currentVersion: response.versions.stable ?? "Unknown",
                stable: response.versions.stable,
                head: response.versions.head,
                bottleAvailable: response.versions.bottle
            ),
            dependencies: response.dependencies,
            dependencySections: dependencySections,
            conflicts: response.conflictsWith,
            lifecycleSections: lifecycleSections,
            platformSections: platformSections,
            caveats: response.caveats,
            artifacts: [],
            artifactSections: [],
            analytics: Self.makeAnalyticsMetrics(response.analytics)
        )
    }

    init(response: CaskDetailResponse) {
        let artifacts = response.artifacts
            .map(\.flattenedDescription)
            .filter { !$0.isEmpty }
        let dependencySections = Self.makeDependencySections(from: response.dependsOn)
        let conflicts = Self.flattenedValues(from: response.conflictsWith?["formula"]) +
            Self.flattenedValues(from: response.conflictsWith?["cask"])
        let platformSections = Self.makeCaskPlatformSections(
            dependsOn: response.dependsOn,
            variations: response.variations
        )
        let lifecycleSections = Self.makeLifecycleSections(
            conflicts: conflicts,
            deprecated: response.deprecated,
            deprecationDate: response.deprecationDate,
            deprecationReason: response.deprecationReason,
            deprecationReplacementFormula: response.deprecationReplacementFormula,
            deprecationReplacementCask: response.deprecationReplacementCask,
            disabled: response.disabled,
            disableDate: response.disableDate,
            disableReason: response.disableReason,
            disableReplacementFormula: response.disableReplacementFormula,
            disableReplacementCask: response.disableReplacementCask
        )
        let artifactSections = Self.makeArtifactSections(from: response.artifacts)

        self.init(
            kind: .cask,
            slug: response.token,
            title: response.name.first ?? response.token,
            fullName: response.fullToken,
            aliases: response.name.dropFirst().map { $0 },
            oldNames: response.oldTokens,
            description: response.desc ?? CatalogPackageSummary.fallbackDescription,
            homepage: response.homepage,
            version: response.version,
            tap: response.tap,
            license: nil,
            downloadURL: response.downloadURL,
            checksum: response.checksum,
            autoUpdates: response.autoUpdates,
            versionDetails: Self.makeVersionDetails(
                currentVersion: response.version,
                stable: response.version,
                head: nil,
                bottleAvailable: nil
            ),
            dependencies: dependencySections.flatMap { $0.items },
            dependencySections: dependencySections,
            conflicts: conflicts,
            lifecycleSections: lifecycleSections,
            platformSections: platformSections,
            caveats: response.caveats,
            artifacts: artifacts,
            artifactSections: artifactSections,
            analytics: Self.makeAnalyticsMetrics(response.analytics)
        )
    }

    private static func makeVersionDetails(
        currentVersion: String,
        stable: String?,
        head: String?,
        bottleAvailable: Bool?
    ) -> [CatalogDetailMetric] {
        var metrics = [CatalogDetailMetric(title: "Current", value: currentVersion)]

        if let stable, stable != currentVersion {
            metrics.append(CatalogDetailMetric(title: "Stable", value: stable))
        } else if let stable {
            metrics.append(CatalogDetailMetric(title: "Stable", value: stable))
        }

        if let head, !head.isEmpty {
            metrics.append(CatalogDetailMetric(title: "Head", value: head))
        }

        if let bottleAvailable {
            metrics.append(
                CatalogDetailMetric(
                    title: "Bottle Available",
                    value: bottleAvailable ? "Yes" : "No"
                )
            )
        }

        return metrics
    }

    private static func makeAnalyticsMetrics(_ analytics: AnalyticsResponse?) -> [CatalogDetailMetric] {
        guard let analytics else {
            return []
        }

        return [
            makeAnalyticsMetric(title: "Installs (30d)", series: analytics.install, period: "30d"),
            makeAnalyticsMetric(title: "Installs (90d)", series: analytics.install, period: "90d"),
            makeAnalyticsMetric(title: "Installs (365d)", series: analytics.install, period: "365d"),
            makeAnalyticsMetric(title: "On Request (30d)", series: analytics.installOnRequest, period: "30d"),
            makeAnalyticsMetric(title: "On Request (90d)", series: analytics.installOnRequest, period: "90d"),
            makeAnalyticsMetric(title: "On Request (365d)", series: analytics.installOnRequest, period: "365d"),
            makeAnalyticsMetric(title: "Build Errors (30d)", series: analytics.buildError, period: "30d")
        ]
        .compactMap { $0 }
    }

    private static func makeAnalyticsMetric(
        title: String,
        series: [String: [String: Int]]?,
        period: String
    ) -> CatalogDetailMetric? {
        guard let counts = series?[period], !counts.isEmpty else {
            return nil
        }

        let total = counts.values.reduce(0, +)
        return CatalogDetailMetric(title: title, value: numberFormatter.string(from: NSNumber(value: total)) ?? "\(total)")
    }

    private static func makeDependencySections(from dependsOn: [String: JSONValue]?) -> [CatalogDetailSection] {
        guard let dependsOn else {
            return []
        }

        return [
            makeTagSection("Formula Dependencies", flattenedValues(from: dependsOn["formula"])),
            makeTagSection("Cask Dependencies", flattenedValues(from: dependsOn["cask"])),
            makeTagSection("Architecture", flattenedValues(from: dependsOn["arch"]))
        ]
        .compactMap { $0 }
    }

    private static func makeCaskPlatformSections(
        dependsOn: [String: JSONValue]?,
        variations: [String: JSONValue]
    ) -> [CatalogDetailSection] {
        var sections: [CatalogDetailSection] = []

        let macOSRequirements = flattenedValues(from: dependsOn?["macos"])
        if let section = makeListSection("macOS Compatibility", macOSRequirements) {
            sections.append(section)
        }

        if let section = makeTagSection("Platform Variations", variations.keys.sorted()) {
            sections.append(section)
        }

        return sections
    }

    private static func makeArtifactSections(from artifacts: [JSONValue]) -> [CatalogDetailSection] {
        artifacts.compactMap { artifact in
            guard case .object(let values) = artifact else {
                return nil
            }

            let items = values
                .sorted { $0.key < $1.key }
                .flatMap { key, value -> [String] in
                    let flattenedItems = value.flattenedItems
                    if flattenedItems.isEmpty {
                        return []
                    }

                    return flattenedItems.map { "\(key): \($0)" }
                }

            guard let title = values.keys.sorted().first, !items.isEmpty else {
                return nil
            }

            return CatalogDetailSection(title: title.capitalized, items: items, style: .list)
        }
    }

    private static func makeLifecycleSections(
        conflicts: [String],
        deprecated: Bool,
        deprecationDate: String?,
        deprecationReason: String?,
        deprecationReplacementFormula: String?,
        deprecationReplacementCask: String?,
        disabled: Bool,
        disableDate: String?,
        disableReason: String?,
        disableReplacementFormula: String?,
        disableReplacementCask: String?
    ) -> [CatalogDetailSection] {
        var sections: [CatalogDetailSection] = []

        if let conflictsSection = makeTagSection("Conflicts", conflicts) {
            sections.append(conflictsSection)
        }

        if deprecated {
            let replacements = [deprecationReplacementFormula, deprecationReplacementCask].compactMap { $0 }
            let notes = compactLines(
                "Status: Deprecated",
                deprecationDate.map { "Date: \($0)" },
                deprecationReason.map { "Reason: \($0)" },
                replacements.isEmpty ? nil : "Replacement: \(replacements.joined(separator: ", "))"
            )

            if let section = makeListSection("Deprecation", notes) {
                sections.append(section)
            }
        }

        if disabled {
            let replacements = [disableReplacementFormula, disableReplacementCask].compactMap { $0 }
            let notes = compactLines(
                "Status: Disabled",
                disableDate.map { "Date: \($0)" },
                disableReason.map { "Reason: \($0)" },
                replacements.isEmpty ? nil : "Replacement: \(replacements.joined(separator: ", "))"
            )

            if let section = makeListSection("Disabled", notes) {
                sections.append(section)
            }
        }

        return sections
    }

    private static func flattenedValues(from value: JSONValue?) -> [String] {
        guard let value else {
            return []
        }

        return value.flattenedItems
    }

    private static func makeTagSection(_ title: String, _ items: [String]) -> CatalogDetailSection? {
        let cleaned = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else {
            return nil
        }

        return CatalogDetailSection(title: title, items: cleaned, style: .tags)
    }

    private static func makeListSection(_ title: String, _ items: [String]) -> CatalogDetailSection? {
        let cleaned = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else {
            return nil
        }

        return CatalogDetailSection(title: title, items: cleaned, style: .list)
    }

    private static func compactLines(_ lines: String?...) -> [String] {
        lines.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}
