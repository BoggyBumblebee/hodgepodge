import Foundation

enum CatalogPackageKind: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case formula
    case cask

    var id: String { rawValue }

    var title: String {
        switch self {
        case .formula:
            "Formulae"
        case .cask:
            "Casks"
        }
    }

    var installCommandFlag: String {
        switch self {
        case .formula:
            ""
        case .cask:
            "--cask "
        }
    }
}

enum CatalogScope: String, CaseIterable, Equatable, Identifiable, Sendable {
    case all
    case formula
    case cask

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .formula:
            "Formulae"
        case .cask:
            "Casks"
        }
    }

    func includes(_ kind: CatalogPackageKind) -> Bool {
        switch self {
        case .all:
            true
        case .formula:
            kind == .formula
        case .cask:
            kind == .cask
        }
    }
}

enum CatalogFilterOption: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case hasCaveats
    case deprecated
    case disabled
    case autoUpdates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hasCaveats:
            "Has Caveats"
        case .deprecated:
            "Deprecated"
        case .disabled:
            "Disabled"
        case .autoUpdates:
            "Auto Updates"
        }
    }
}

enum CatalogSortOption: String, CaseIterable, Equatable, Identifiable, Sendable {
    case name
    case packageType
    case version
    case tap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            "Name"
        case .packageType:
            "Package Type"
        case .version:
            "Version"
        case .tap:
            "Tap"
        }
    }
}

struct CatalogPackageSummary: Identifiable, Equatable, Hashable, Sendable {
    let kind: CatalogPackageKind
    let slug: String
    let title: String
    let subtitle: String
    let version: String
    let homepage: URL?
    let tap: String
    let hasCaveats: Bool
    let isDeprecated: Bool
    let isDisabled: Bool
    let autoUpdates: Bool

    var id: String {
        "\(kind.rawValue):\(slug)"
    }

    var installCommand: String {
        "brew install \(kind.installCommandFlag)\(slug)"
    }
}

enum CatalogDetailSectionStyle: String, Equatable, Sendable {
    case tags
    case list
}

struct CatalogDetailSection: Identifiable, Equatable, Sendable {
    let title: String
    let items: [String]
    let style: CatalogDetailSectionStyle

    var id: String {
        title
    }
}

struct CatalogDetailMetric: Identifiable, Equatable, Sendable {
    let title: String
    let value: String

    var id: String {
        title
    }
}

struct CatalogPackageDetail: Equatable, Sendable {
    let kind: CatalogPackageKind
    let slug: String
    let title: String
    let fullName: String
    let aliases: [String]
    let oldNames: [String]
    let description: String
    let homepage: URL?
    let version: String
    let tap: String
    let license: String?
    let downloadURL: URL?
    let checksum: String?
    let autoUpdates: Bool?
    let versionDetails: [CatalogDetailMetric]
    let dependencies: [String]
    let dependencySections: [CatalogDetailSection]
    let conflicts: [String]
    let lifecycleSections: [CatalogDetailSection]
    let platformSections: [CatalogDetailSection]
    let caveats: String?
    let artifacts: [String]
    let artifactSections: [CatalogDetailSection]
    let analytics: [CatalogDetailMetric]

    var installCommand: String {
        "brew install \(kind.installCommandFlag)\(slug)"
    }

    var fetchCommand: String {
        "brew fetch \(kind.installCommandFlag)\(slug)"
    }

    var metadataDetails: [CatalogDetailMetric] {
        var metrics = [
            CatalogDetailMetric(title: "Full Name", value: fullName),
            CatalogDetailMetric(title: "Slug", value: slug),
            CatalogDetailMetric(title: "Tap", value: tap),
            CatalogDetailMetric(title: "License", value: license ?? "Not specified")
        ]

        if let checksum, !checksum.isEmpty {
            metrics.append(CatalogDetailMetric(title: "Checksum", value: checksum))
        }

        if let autoUpdates {
            metrics.append(CatalogDetailMetric(title: "Auto Updates", value: autoUpdates ? "Yes" : "No"))
        }

        return metrics
    }
}

enum CatalogPackagesLoadState: Equatable {
    case idle
    case loading
    case loaded([CatalogPackageSummary])
    case failed(String)
}

enum CatalogDetailLoadState: Equatable {
    case idle
    case loading(CatalogPackageSummary)
    case loaded(CatalogPackageDetail)
    case failed(CatalogPackageSummary, String)
}

enum JSONValue: Decodable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let decoded = try Self.decodeNonNullValue(from: container) {
            self = decoded
            return
        }

        throw DecodingError.typeMismatch(
            JSONValue.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value.")
        )
    }

    var flattenedDescription: String {
        switch self {
        case .string(let value):
            value
        case .number(let value):
            if value.rounded() == value {
                String(Int(value))
            } else {
                String(value)
            }
        case .bool(let value):
            String(value)
        case .array(let values):
            values
                .map(\.flattenedDescription)
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        case .object(let values):
            values
                .sorted { $0.key < $1.key }
                .map { key, value in
                    let flattened = value.flattenedDescription
                    return flattened.isEmpty ? key : "\(key): \(flattened)"
                }
                .joined(separator: ", ")
        case .null:
            ""
        }
    }

    var flattenedItems: [String] {
        switch self {
        case .string, .number, .bool, .object:
            return flattenedItemList
        case .array(let values):
            return values.flatMap(\.flattenedItems)
        case .null:
            return []
        }
    }

    private var flattenedItemList: [String] {
        let description = flattenedDescription
        return description.isEmpty ? [] : [description]
    }

    private static func decodeNonNullValue(from container: any SingleValueDecodingContainer) throws -> JSONValue? {
        if let value = try decode(String.self, from: container, wrap: JSONValue.string) {
            return value
        }

        if let value = try decode(Double.self, from: container, wrap: JSONValue.number) {
            return value
        }

        if let value = try decode(Bool.self, from: container, wrap: JSONValue.bool) {
            return value
        }

        if let value = try decode([String: JSONValue].self, from: container, wrap: JSONValue.object) {
            return value
        }

        return try decode([JSONValue].self, from: container, wrap: JSONValue.array)
    }

    private static func decode<Value: Decodable>(
        _ type: Value.Type,
        from container: any SingleValueDecodingContainer,
        wrap: (Value) -> JSONValue
    ) throws -> JSONValue? {
        guard let value = try? container.decode(type) else {
            return nil
        }

        return wrap(value)
    }
}
