import Foundation

enum BrewfileLoadState: Equatable {
    case idle
    case loading
    case loaded(BrewfileDocument)
    case failed(String)
}

enum BrewfileEntryKind: String, CaseIterable, Codable, Sendable {
    case tap
    case brew
    case cask
    case mas
    case vscode
    case go
    case cargo
    case uv
    case flatpak
    case krew
    case npm
    case unknown

    var title: String {
        switch self {
        case .tap:
            "Tap"
        case .brew:
            "Formula"
        case .cask:
            "Cask"
        case .mas:
            "App Store"
        case .vscode:
            "VS Code"
        case .go:
            "Go"
        case .cargo:
            "Cargo"
        case .uv:
            "uv"
        case .flatpak:
            "Flatpak"
        case .krew:
            "Krew"
        case .npm:
            "npm"
        case .unknown:
            "Unknown"
        }
    }

    var systemImageName: String {
        switch self {
        case .tap:
            "line.3.horizontal.decrease.circle"
        case .brew:
            "shippingbox"
        case .cask:
            "square.stack.3d.up"
        case .mas:
            "bag"
        case .vscode:
            "chevron.left.forwardslash.chevron.right"
        case .go, .cargo, .uv, .flatpak, .krew, .npm:
            "hammer"
        case .unknown:
            "questionmark.circle"
        }
    }

    static var addableCases: [BrewfileEntryKind] {
        allCases.filter(\.supportsBundleAdd)
    }

    var supportsBundleAdd: Bool {
        bundleAddFlag != nil || self == .brew
    }

    var supportsBundleRemove: Bool {
        bundleRemoveFlag != nil
    }

    var bundleAddFlag: String? {
        switch self {
        case .tap:
            "--tap"
        case .brew:
            nil
        case .cask:
            "--cask"
        case .mas:
            nil
        case .vscode:
            "--vscode"
        case .go:
            "--go"
        case .cargo:
            "--cargo"
        case .uv:
            "--uv"
        case .flatpak:
            "--flatpak"
        case .krew:
            "--krew"
        case .npm:
            "--npm"
        case .unknown:
            nil
        }
    }

    var bundleRemoveFlag: String? {
        switch self {
        case .tap:
            "--tap"
        case .brew:
            "--formula"
        case .cask:
            "--cask"
        case .mas:
            "--mas"
        case .vscode:
            "--vscode"
        case .go:
            "--go"
        case .cargo:
            "--cargo"
        case .uv:
            "--uv"
        case .flatpak:
            "--flatpak"
        case .krew:
            "--krew"
        case .npm:
            "--npm"
        case .unknown:
            nil
        }
    }
}

enum BrewfileLineCategory: String, CaseIterable, Identifiable, Sendable {
    case entry
    case comment
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .entry:
            "Entries"
        case .comment:
            "Comments"
        case .unknown:
            "Unknown"
        }
    }
}

enum BrewfileFilterOption: String, CaseIterable, Identifiable, Sendable {
    case all
    case entries
    case comments
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .entries:
            "Entries"
        case .comments:
            "Comments"
        case .unknown:
            "Unknown"
        }
    }
}

enum BrewfileSortOption: String, CaseIterable, Identifiable, Sendable {
    case fileOrder
    case name
    case kind

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fileOrder:
            "File Order"
        case .name:
            "Name"
        case .kind:
            "Kind"
        }
    }
}

struct BrewfileEntry: Identifiable, Equatable, Hashable, Codable, Sendable {
    let lineNumber: Int
    let kind: BrewfileEntryKind
    let name: String
    let rawLine: String
    let options: [String: String]
    let inlineComment: String?

    var id: Int { lineNumber }
}

struct BrewfileLine: Identifiable, Equatable, Hashable, Sendable {
    let lineNumber: Int
    let category: BrewfileLineCategory
    let entry: BrewfileEntry?
    let rawLine: String
    let commentText: String?

    var id: Int { lineNumber }

    var entryKind: BrewfileEntryKind? {
        entry?.kind
    }

    var name: String? {
        entry?.name
    }

    var title: String {
        switch category {
        case .entry:
            entry?.name ?? "Unknown Entry"
        case .comment:
            commentText ?? "Comment"
        case .unknown:
            rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var subtitle: String {
        switch category {
        case .entry:
            entry?.kind.title ?? BrewfileEntryKind.unknown.title
        case .comment:
            "Comment"
        case .unknown:
            "Unparsed"
        }
    }

    var badgeText: String {
        switch category {
        case .entry:
            entry?.kind.title ?? BrewfileEntryKind.unknown.title
        case .comment:
            "Comment"
        case .unknown:
            "Unknown"
        }
    }

    var systemImageName: String {
        switch category {
        case .entry:
            entry?.kind.systemImageName ?? BrewfileEntryKind.unknown.systemImageName
        case .comment:
            "text.bubble"
        case .unknown:
            "questionmark.circle"
        }
    }

    var searchText: String {
        [
            title,
            subtitle,
            rawLine,
            commentText,
            entry?.inlineComment
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}

struct BrewfileMetric: Identifiable, Equatable, Sendable {
    let title: String
    let value: String

    var id: String { title }
}

struct BrewfileDocument: Equatable, Sendable {
    let fileURL: URL
    let lines: [BrewfileLine]
    let loadedAt: Date
    let modifiedAt: Date?

    var entries: [BrewfileEntry] {
        lines.compactMap(\.entry)
    }

    var entryCount: Int {
        entries.count
    }

    var commentCount: Int {
        lines.filter { $0.category == .comment }.count
    }

    var unknownCount: Int {
        lines.filter { $0.category == .unknown }.count
    }

    var entryCountsByKind: [BrewfileMetric] {
        BrewfileEntryKind.allCases
            .filter { $0 != .unknown }
            .compactMap { kind in
                let count = entries.filter { $0.kind == kind }.count
                guard count > 0 else {
                    return nil
                }
                return BrewfileMetric(title: kind.title, value: "\(count)")
            }
    }

    var summaryMetrics: [BrewfileMetric] {
        var metrics = [
            BrewfileMetric(title: "Entries", value: "\(entryCount)"),
            BrewfileMetric(title: "Comments", value: "\(commentCount)"),
            BrewfileMetric(title: "Unknown", value: "\(unknownCount)")
        ]
        metrics.append(contentsOf: entryCountsByKind)
        return metrics
    }
}
