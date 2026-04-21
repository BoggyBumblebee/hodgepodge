import Foundation

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var packagesState: CatalogPackagesLoadState = .idle
    @Published var detailState: CatalogDetailLoadState = .idle
    @Published var searchText = ""
    @Published var scope: CatalogScope = .all
    @Published var selectedPackage: CatalogPackageSummary?

    private let apiClient: any HomebrewAPIClienting
    private var detailCache: [String: CatalogPackageDetail] = [:]

    init(apiClient: any HomebrewAPIClienting) {
        self.apiClient = apiClient
    }

    var filteredPackages: [CatalogPackageSummary] {
        guard case .loaded(let packages) = packagesState else {
            return []
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return packages.filter { package in
            let matchesScope = scope.includes(package.kind)
            guard matchesScope else {
                return false
            }

            guard !trimmedQuery.isEmpty else {
                return true
            }

            return package.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.slug.localizedCaseInsensitiveContains(trimmedQuery) ||
                package.subtitle.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    func loadIfNeeded() {
        guard case .idle = packagesState else {
            return
        }

        refreshCatalog()
    }

    func refreshCatalog() {
        packagesState = .loading

        Task { @MainActor [apiClient] in
            do {
                let packages = try await apiClient.fetchCatalog()
                packagesState = .loaded(packages)

                if let selectedPackage, packages.contains(selectedPackage) {
                    await loadDetail(for: selectedPackage)
                } else {
                    let replacement = packages.first
                    selectedPackage = replacement
                    if let replacement {
                        await loadDetail(for: replacement)
                    } else {
                        detailState = .idle
                    }
                }
            } catch {
                packagesState = .failed(error.localizedDescription)
                detailState = .idle
            }
        }
    }

    func selectPackage(_ package: CatalogPackageSummary?) {
        selectedPackage = package

        guard let package else {
            detailState = .idle
            return
        }

        Task { @MainActor in
            await loadDetail(for: package)
        }
    }

    func refreshSelectedDetail() {
        guard let selectedPackage else {
            detailState = .idle
            return
        }

        detailCache.removeValue(forKey: selectedPackage.id)
        Task { @MainActor in
            await loadDetail(for: selectedPackage)
        }
    }

    private func loadDetail(for package: CatalogPackageSummary) async {
        if let cached = detailCache[package.id] {
            detailState = .loaded(cached)
            return
        }

        detailState = .loading(package)

        do {
            let detail = try await apiClient.fetchDetail(for: package)
            detailCache[package.id] = detail
            guard selectedPackage == package else {
                return
            }
            detailState = .loaded(detail)
        } catch {
            guard selectedPackage == package else {
                return
            }
            detailState = .failed(package, error.localizedDescription)
        }
    }
}

extension CatalogViewModel {
    static func live() -> CatalogViewModel {
        CatalogViewModel(apiClient: HomebrewAPIClient())
    }
}
