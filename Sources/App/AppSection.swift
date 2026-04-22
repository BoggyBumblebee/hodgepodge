import AppKit

enum AppSection: String, CaseIterable, Identifiable {
    case catalog
    case catalogAnalytics
    case installed
    case outdated
    case services
    case taps
    case brewfile
    case maintenance
    case settings
    case overview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .catalog:
            "Catalog"
        case .catalogAnalytics:
            "Catalog Analytics"
        case .installed:
            "Installed"
        case .outdated:
            "Outdated"
        case .services:
            "Services"
        case .taps:
            "Taps"
        case .brewfile:
            "Brewfile"
        case .maintenance:
            "Maintenance"
        case .settings:
            "Settings"
        case .overview:
            "About Brew"
        }
    }

    var systemImageName: String {
        switch self {
        case .catalog:
            "books.vertical"
        case .catalogAnalytics:
            "chart.bar.xaxis"
        case .installed:
            "shippingbox"
        case .outdated:
            "arrow.triangle.2.circlepath"
        case .services:
            "bolt.horizontal.circle"
        case .taps:
            "line.3.horizontal.decrease.circle"
        case .brewfile:
            "doc.text"
        case .maintenance:
            "stethoscope"
        case .settings:
            "gearshape"
        case .overview:
            "info.circle"
        }
    }
}
