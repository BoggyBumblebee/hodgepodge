import Foundation

@MainActor
final class OutdatedPackagesViewModel: ObservableObject {
    @Published var packagesState: OutdatedPackagesLoadState = .idle
    @Published var searchText = ""
    @Published var scope: CatalogScope = .all
    @Published var activeFilters: Set<OutdatedPackageFilterOption> = []
    @Published var sortOption: OutdatedPackageSortOption = .name
    @Published var selectedPackage: OutdatedPackage?

    private let provider: any OutdatedPackagesProviding

    init(provider: any OutdatedPackagesProviding) {
        self.provider = provider
    }

    var filteredPackages: [OutdatedPackage] {
        guard case .loaded(let packages) = packagesState else {
            return []
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = packages.filter { package in
            guard scope.includes(package.kind) else {
                return false
            }

            guard matchesActiveFilters(for: package) else {
                return false
            }

            guard !trimmedQuery.isEmpty else {
                return true
            }

            return package.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.slug.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.fullName.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.currentVersion.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.installedVersions.joined(separator: " ").localizedCaseInsensitiveContains(trimmedQuery)
        }

        return filtered.sorted(by: sorter(for: sortOption))
    }

    var activeFilterCount: Int {
        activeFilters.count
    }

    func loadIfNeeded() {
        guard case .idle = packagesState else {
            return
        }

        refreshPackages()
    }

    func refreshPackages() {
        packagesState = .loading

        Task { @MainActor [provider] in
            do {
                let packages = try await provider.fetchOutdatedPackages()
                packagesState = .loaded(packages)

                if let selectedPackage,
                   let refreshedSelection = packages.first(where: { $0.id == selectedPackage.id }) {
                    self.selectedPackage = refreshedSelection
                } else {
                    selectedPackage = defaultSelection(from: packages)
                }
            } catch {
                packagesState = .failed(error.localizedDescription)
                selectedPackage = nil
            }
        }
    }

    func toggleFilter(_ filter: OutdatedPackageFilterOption) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
    }

    func clearFilters() {
        activeFilters.removeAll()
    }

    func isFilterActive(_ filter: OutdatedPackageFilterOption) -> Bool {
        activeFilters.contains(filter)
    }

    private func matchesActiveFilters(for package: OutdatedPackage) -> Bool {
        activeFilters.allSatisfy { filter in
            switch filter {
            case .pinned:
                package.isPinned
            }
        }
    }

    private func sorter(for option: OutdatedPackageSortOption) -> (OutdatedPackage, OutdatedPackage) -> Bool {
        switch option {
        case .name:
            return { lhs, rhs in
                Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .currentVersion:
            return { lhs, rhs in
                let result = lhs.currentVersion.localizedStandardCompare(rhs.currentVersion)
                if result != .orderedSame {
                    return result == .orderedDescending
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .packageType:
            return { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        }
    }

    private func defaultSelection(from packages: [OutdatedPackage]) -> OutdatedPackage? {
        packages.sorted(by: sorter(for: sortOption)).first
    }

    private static func compare(_ lhs: String, _ rhs: String, fallback: Bool) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result != .orderedSame {
            return result == .orderedAscending
        }
        return fallback
    }
}

extension OutdatedPackagesViewModel {
    static func live() -> OutdatedPackagesViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)

        return OutdatedPackagesViewModel(
            provider: BrewOutdatedPackagesProvider(
                brewLocator: brewLocator,
                runner: runner
            )
        )
    }
}
