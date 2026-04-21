import Foundation

enum HelpAnchor: String {
    case home
    case quickStart = "quick-start"
    case troubleshooting

    var fragment: String? {
        switch self {
        case .home:
            nil
        case .quickStart, .troubleshooting:
            rawValue
        }
    }
}

protocol HelpDocumentResolving {
    func helpURL(anchor: HelpAnchor) throws -> URL
}

protocol BundleResourceQuerying {
    func url(forResource name: String?, withExtension ext: String?, subdirectory subpath: String?) -> URL?
    func url(forResource name: String?, withExtension ext: String?) -> URL?
}

extension Bundle: BundleResourceQuerying {}

enum HelpDocumentResolverError: LocalizedError, Equatable {
    case helpDocumentMissing

    var errorDescription: String? {
        "Help documentation could not be found in the application bundle."
    }
}

struct HelpDocumentResolver: HelpDocumentResolving {
    private let bundle: BundleResourceQuerying

    init(bundle: BundleResourceQuerying) {
        self.bundle = bundle
    }

    func helpURL(anchor: HelpAnchor) throws -> URL {
        let baseURL =
            bundle.url(forResource: "index", withExtension: "html", subdirectory: "Help") ??
            bundle.url(forResource: "index", withExtension: "html")

        guard let baseURL else {
            throw HelpDocumentResolverError.helpDocumentMissing
        }

        return baseURL.appendingFragment(anchor.fragment)
    }
}

private extension URL {
    func appendingFragment(_ fragment: String?) -> URL {
        guard let fragment, !fragment.isEmpty else {
            return self
        }

        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.fragment = fragment
        return components?.url ?? self
    }
}
