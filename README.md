# Hodgepodge

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

The current project state includes the initial app shell and foundational services:

- Homebrew detection on launch
- an Overview screen with installation metadata
- Help menu entries for:
  - `Hodgepodge Help`
  - `Quick Start`
  - `Troubleshooting`
- bundled help documentation and app icon resources

As additional phases land, Hodgepodge will expand into catalog browsing, installed package management, upgrades, services, taps, Brewfiles, and maintenance tooling.

## Roadmap

### Phase 1: Foundation

- XcodeGen-driven project setup
- app shell and sidebar navigation
- Homebrew detection
- initial Help system
- icon/resource plumbing
- unit tests for core non-UI logic

### Phase 2: Catalog Browser

- formula and cask browsing from the hosted Homebrew API
- package search, filters, and detail screens
- install entry points from detail views

### Phase 3: Local Inventory

- installed package state from `brew info --json=v2 --installed`
- pinned, linked, outdated, leaves, and dependency views

### Phase 4: Core Actions

- install, uninstall, reinstall, fetch, link, unlink, pin, and unpin
- live logs and state refresh after mutations

### Phase 5: Services

- `brew services` list/detail integration
- start, stop, restart, kill, and cleanup flows

### Phase 6: Maintenance and Diagnostics

- update, outdated, cleanup, autoremove, doctor, and config flows
- health-oriented dashboarding

### Phase 7: Taps and Brewfile

- tap management
- Brewfile inspection and `brew bundle` workflows

### Phase 8: Advanced UX

- command history
- analytics
- notifications
- favorites and saved searches

## Contributing

Contributions are welcome. A good contribution path is:

1. Open or discuss the change.
2. Update `project.yml` instead of hand-maintaining the generated Xcode project.
3. Add or update tests for meaningful logic changes.
4. Keep code and menus intentional, accessible, and production-ready.

## License

Distributed under the MIT License. See [LICENSE.md](/Users/cmb/Workspace/github.com/boggybumblebee/hodgepodge/LICENSE.md).

## Contact

BoggyBumblebee

- GitHub: [BoggyBumblebee](https://github.com/BoggyBumblebee)

## Acknowledgments

- [Homebrew](https://brew.sh)
- [Homebrew Formulae API](https://formulae.brew.sh/docs/api/)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Apple's SwiftUI and XCTest tooling
