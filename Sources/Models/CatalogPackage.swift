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
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value.")
            )
        }
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
        case .string, .number, .bool:
            let description = flattenedDescription
            return description.isEmpty ? [] : [description]
        case .array(let values):
            return values.flatMap(\.flattenedItems)
        case .object:
            let description = flattenedDescription
            return description.isEmpty ? [] : [description]
        case .null:
            return []
        }
    }
}
