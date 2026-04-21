import AppKit
import Foundation
import Combine

enum InstallationLoadState: Equatable {
    case idle
    case loading
    case loaded(HomebrewInstallation)
    case failed(String)
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: AppSection? = .overview
    @Published var installationState: InstallationLoadState = .idle
    @Published var lastOpenedHelpURL: URL?

    private let brewLocator: any BrewLocating
    private let helpResolver: any HelpDocumentResolving
    private let urlOpener: any URLOpening
    private let aboutPanelPresenter: any AboutPanelPresenting

    init(
        brewLocator: any BrewLocating,
        helpResolver: any HelpDocumentResolving,
        urlOpener: any URLOpening,
        aboutPanelPresenter: any AboutPanelPresenting
    ) {
        self.brewLocator = brewLocator
        self.helpResolver = helpResolver
        self.urlOpener = urlOpener
        self.aboutPanelPresenter = aboutPanelPresenter
    }

    func loadIfNeeded() {
        guard case .idle = installationState else {
            return
        }

        refreshInstallation()
    }

    func refreshInstallation() {
        installationState = .loading

        Task { @MainActor [brewLocator] in
            do {
                let installation = try await brewLocator.locate()
                installationState = .loaded(installation)
            } catch {
                installationState = .failed(error.localizedDescription)
            }
        }
    }

    func openAboutPanel() {
        aboutPanelPresenter.presentAboutPanel()
    }

    func openHelp(anchor: HelpAnchor = .home) {
        do {
            let url = try helpResolver.helpURL(anchor: anchor)
            if urlOpener.open(url) {
                lastOpenedHelpURL = url
            } else {
                installationState = .failed("Help could not be opened from the app bundle.")
            }
        } catch {
            installationState = .failed(error.localizedDescription)
        }
    }
}

extension AppModel {
    static func live() -> AppModel {
        let runner = ProcessCommandRunner()
        let brewLocator = BrewLocator(runner: runner)
        let helpResolver = HelpDocumentResolver(bundle: Bundle.main)
        let urlOpener = WorkspaceURLOpener()
        let aboutPanelPresenter = StandardAboutPanelPresenter()

        return AppModel(
            brewLocator: brewLocator,
            helpResolver: helpResolver,
            urlOpener: urlOpener,
            aboutPanelPresenter: aboutPanelPresenter
        )
    }
}
