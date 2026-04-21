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

struct CatalogPackageSummary: Identifiable, Equatable, Hashable, Sendable {
    let kind: CatalogPackageKind
    let slug: String
    let title: String
    let subtitle: String
    let version: String
    let homepage: URL?

    var id: String {
        "\(kind.rawValue):\(slug)"
    }

    var installCommand: String {
        "brew install \(kind.installCommandFlag)\(slug)"
    }
}

struct CatalogPackageDetail: Equatable, Sendable {
    let kind: CatalogPackageKind
    let slug: String
    let title: String
    let aliases: [String]
    let description: String
    let homepage: URL?
    let version: String
    let tap: String
    let license: String?
    let dependencies: [String]
    let conflicts: [String]
    let caveats: String?
    let artifacts: [String]

    var installCommand: String {
        "brew install \(kind.installCommandFlag)\(slug)"
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
}
