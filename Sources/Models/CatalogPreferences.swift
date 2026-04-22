import Foundation

struct CatalogSavedSearch: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let searchText: String
    let scope: CatalogScope
    let activeFilters: Set<CatalogFilterOption>
    let sortOption: CatalogSortOption

    var summary: String {
        var parts: [String] = []

        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearchText.isEmpty {
            parts.append("Search: \(trimmedSearchText)")
        }

        if scope != .all {
            parts.append(scope.title)
        }

        if !activeFilters.isEmpty {
            parts.append(
                activeFilters
                    .sorted { $0.title < $1.title }
                    .map(\.title)
                    .joined(separator: ", ")
            )
        }

        if sortOption != .name {
            parts.append("Sort: \(sortOption.title)")
        }

        if parts.isEmpty {
            return "Default catalog view"
        }

        return parts.joined(separator: " • ")
    }
}

struct CatalogPreferencesSnapshot: Codable, Equatable, Sendable {
    let favoritePackageIDs: [String]
    let savedSearches: [CatalogSavedSearch]

    static let empty = CatalogPreferencesSnapshot(
        favoritePackageIDs: [],
        savedSearches: []
    )
}
