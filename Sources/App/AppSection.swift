import AppKit

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case catalog
    case installed
    case outdated
    case services
    case taps
    case brewfile
    case maintenance
    case commandCenter
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .catalog:
            "Catalog"
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
        case .commandCenter:
            "Command Center"
        case .settings:
            "Settings"
        }
    }

    var systemImageName: String {
        switch self {
        case .overview:
            "square.grid.2x2"
        case .catalog:
            "books.vertical"
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
        case .commandCenter:
            "terminal"
        case .settings:
            "gearshape"
        }
    }
}
