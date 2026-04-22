# Hodgepodge

[![CI](https://github.com/BoggyBumblebee/hodgepodge/actions/workflows/ci.yml/badge.svg)](https://github.com/BoggyBumblebee/hodgepodge/actions/workflows/ci.yml)
[![SonarCloud Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=BoggyBumblebee_hodgepodge&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=BoggyBumblebee_hodgepodge)
[![SonarCloud Coverage](https://sonarcloud.io/api/project_badges/measure?project=BoggyBumblebee_hodgepodge&metric=coverage)](https://sonarcloud.io/summary/new_code?id=BoggyBumblebee_hodgepodge)

## About The Project

Hodgepodge is a native macOS SwiftUI application for working with Homebrew in a way that stays transparent to the underlying `brew` tool. The goal is to provide a serious desktop console for package discovery, installed-state inspection, upgrades, services, taps, Brewfiles, and maintenance workflows without relying on Homebrew's private Ruby internals.

The project is intentionally being built in phases so each milestone is useful, testable, and safe to iterate on.

## Built With

- Swift 6
- SwiftUI
- XcodeGen
- XCTest
- Homebrew CLI
- Homebrew Formulae API

## Getting Started

Hodgepodge is generated from `project.yml`, so the Xcode project is reproducible and should not be treated as the source of truth.

## Prerequisites

- macOS 14 or later
- Xcode 26 or later
- [Homebrew](https://brew.sh)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Installation

1. Clone the repository.
2. Install XcodeGen if needed: `brew install xcodegen`
3. Generate the project: `xcodegen generate`
4. Build or test from Xcode, or run:

```bash
xcodebuild -project Hodgepodge.xcodeproj \
  -scheme Hodgepodge \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO
```

## Usage

The current project state already includes:

- Homebrew detection and an Overview screen with installation metadata
- hosted formula and cask catalog browsing with rich detail views
- a dedicated Catalog Analytics screen for hosted Homebrew analytics leaderboards
- installed package inventory, outdated packages, package-state filters, and dependency navigation
- safe action flows for install, fetch, upgrade, service control, and maintenance commands
- tap management
- Brewfile inspection, check, install, export, and entry add/remove flows
- command history for catalog actions
- bundled help documentation and app icon resources

## Roadmap

### Phase 1: Foundation - Completed

- XcodeGen-driven project setup
- app shell and sidebar navigation
- Homebrew detection
- Help system
- icon and resource plumbing
- unit tests for core non-UI logic

### Phase 2: Catalog Browser - Completed

- formula and cask browsing from the hosted Homebrew API
- package search, filters, sorting, and detail screens
- install and fetch entry points from detail views

### Phase 3: Local Inventory - Completed

- installed package state from `brew info --json=v2 --installed`
- outdated package inventory from `brew outdated --json=v2`
- pinned, linked, leaves, and dependency views
- package-to-package jump navigation in dependency trees
- Brewfile generation from currently installed packages

### Phase 4: Core Actions - Completed

- install and fetch flows from catalog detail
- single-package and bulk upgrade flows from the Outdated screen
- uninstall, reinstall, link, unlink, pin, and unpin
- live logs, cancellation, confirmation, and state refresh after mutations

### Phase 5: Services - Completed

- `brew services` list and detail integration
- start, stop, restart, kill, and cleanup flows

### Phase 6: Maintenance and Diagnostics - Completed

- update, outdated, cleanup, autoremove, doctor, and config flows
- health-oriented dashboarding with raw output access

### Phase 7: Taps and Brewfile - Completed

- tap management
- Brewfile inspection
- `brew bundle check`
- `brew bundle install`
- Brewfile export and dump flows
- Brewfile entry add and remove flows

### Phase 8: Advanced UX - In Progress

- completed:
  - command history for catalog actions
  - a dedicated Catalog Analytics screen powered by the public Homebrew API
  - shared favorites across catalog and installed packages
  - saved searches for the catalog
- still to do:
  - notifications

## Contributing

Contributions are welcome. A good contribution path is:

1. Open or discuss the change.
2. Update `project.yml` instead of hand-maintaining the generated Xcode project.
3. Add or update tests for meaningful logic changes.
4. Keep code and menus intentional, accessible, and production-ready.

## License

Distributed under the MIT License. See [LICENSE.md](LICENSE.md).

## Contact

BoggyBumblebee

- GitHub: [BoggyBumblebee](https://github.com/BoggyBumblebee)

## Acknowledgments

- [Homebrew](https://brew.sh)
- [Homebrew Formulae API](https://formulae.brew.sh/docs/api/)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Apple's SwiftUI and XCTest tooling
