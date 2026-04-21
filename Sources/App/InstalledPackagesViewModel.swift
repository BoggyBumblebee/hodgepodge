import Foundation

@MainActor
final class InstalledPackagesViewModel: ObservableObject {
    @Published var packagesState: InstalledPackagesLoadState = .idle
    @Published var searchText = ""
    @Published var scope: CatalogScope = .all
    @Published var activeFilters: Set<InstalledPackageFilterOption> = []
    @Published var sortOption: InstalledPackageSortOption = .installDate
    @Published var selectedPackage: InstalledPackage?

    private let provider: any InstalledPackagesProviding

    init(provider: any InstalledPackagesProviding) {
        self.provider = provider
    }

    var filteredPackages: [InstalledPackage] {
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
                package.subtitle.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.tap.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.version.localizedCaseInsensitiveContains(trimmedQuery)
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
                let packages = try await provider.fetchInstalledPackages()
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

    func toggleFilter(_ filter: InstalledPackageFilterOption) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
    }

    func clearFilters() {
        activeFilters.removeAll()
    }

    func isFilterActive(_ filter: InstalledPackageFilterOption) -> Bool {
        activeFilters.contains(filter)
    }

    private func matchesActiveFilters(for package: InstalledPackage) -> Bool {
        activeFilters.allSatisfy { filter in
            switch filter {
            case .pinned:
                package.isPinned
            case .linked:
                package.isLinked
            case .outdated:
                package.isOutdated
            case .installedOnRequest:
                package.isInstalledOnRequest
            case .installedAsDependency:
                package.isInstalledAsDependency
            case .autoUpdates:
                package.autoUpdates
            }
        }
    }

    private func sorter(for option: InstalledPackageSortOption) -> (InstalledPackage, InstalledPackage) -> Bool {
        switch option {
        case .name:
            return { lhs, rhs in
                Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .installDate:
            return { lhs, rhs in
                switch (lhs.installedAt, rhs.installedAt) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    return lhsDate > rhsDate
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                default:
                    return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
                }
            }
        case .packageType:
            return { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        case .tap:
            return { lhs, rhs in
                let result = lhs.tap.localizedCaseInsensitiveCompare(rhs.tap)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
                return Self.compare(lhs.title, rhs.title, fallback: lhs.slug < rhs.slug)
            }
        }
    }

    private func defaultSelection(from packages: [InstalledPackage]) -> InstalledPackage? {
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

extension InstalledPackagesViewModel {
    static func live() -> InstalledPackagesViewModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)

        return InstalledPackagesViewModel(
            provider: BrewInstalledPackagesProvider(
                brewLocator: brewLocator,
                runner: runner
            )
        )
    }
}
