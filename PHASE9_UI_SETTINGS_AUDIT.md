# Phase 9 UI and Settings Audit

## Goal

Phase 9 starts with three related objectives:

- normalize the macOS UI toward Apple's platform conventions
- introduce a real Settings experience for user-configurable behavior
- prepare the app for longer-term Homebrew compatibility work

This audit focuses on the first two items so the next implementation slices can be deliberate instead of ad hoc.

## Current State Summary

The app already has strong functional coverage, but the current presentation is still more "feature-first" than "macOS-native":

- the app uses a consistent sidebar-to-detail structure in [Sources/Views/RootView.swift](/Users/cmb/Workspace/github.com/boggybumblebee/hodgepodge/Sources/Views/RootView.swift)
- most sections render large custom headers, embedded action rows, and section-specific side cards
- `Settings` exists in navigation as a placeholder route, not as a real macOS Settings window
- several pieces of persisted behavior already exist, but they are not yet expressed as user preferences

## Primary Audit Findings

### 1. Settings should not live as a normal sidebar section

Current state:

- `Settings` is part of `AppSection` in [Sources/App/AppSection.swift](/Users/cmb/Workspace/github.com/boggybumblebee/hodgepodge/Sources/App/AppSection.swift)
- it routes to [Sources/Views/PlaceholderFeatureView.swift](/Users/cmb/Workspace/github.com/boggybumblebee/hodgepodge/Sources/Views/PlaceholderFeatureView.swift)

Recommendation:

- remove `Settings` from the main operational sidebar
- add a dedicated SwiftUI `Settings` scene in [Sources/HodgepodgeApp.swift](/Users/cmb/Workspace/github.com/boggybumblebee/hodgepodge/Sources/HodgepodgeApp.swift)
- keep the sidebar focused on working areas: `Catalog`, `Installed`, `Outdated`, `Services`, `Taps`, `Brewfile`, `Maintenance`, `Catalog Analytics`, `About Brew`

Reason:

- this is the standard macOS mental model
- it reduces clutter in the main navigation
- it makes settings feel app-level rather than content-level

### 2. The app relies heavily on oversized in-content headers instead of macOS toolbar patterns

Current state:

- sections such as [Sources/Views/CatalogView.swift](/Users/cmb/Workspace/github.com/boggybumblebee/hodgepodge/Sources/Views/CatalogView.swift), [Sources/Views/InstalledPackagesView.swift](/Users/cmb/Workspace/github.com/boggybumblebee/hodgepodge/Sources/Views/InstalledPackagesView.swift), [Sources/Views/ServicesView.swift](/Users/cmb/Workspace/github.com/boggybumblebee/hodgepodge/Sources/Views/ServicesView.swift), and [Sources/Views/MaintenanceView.swift](/Users/cmb/Workspace/github.com/boggybumblebee/hodgepodge/Sources/Views/MaintenanceView.swift) all use large custom title blocks with controls embedded below them
- refresh buttons, sort pickers, and filters are often inline in the content rather than promoted to a toolbar

Recommendation:

- move section-level actions like refresh, filter menus, and sorting to `.toolbar`
- keep content headers shorter and more informational
- reserve large in-content header treatments for special-purpose screens only

Reason:

- macOS apps feel more native when navigation and commands are separated from content
- it reduces vertical sprawl at the top of each screen

### 3. The current split-view layouts are useful but visually inconsistent

Current state:

- each major screen defines its own `HSplitView` sizing
- many screens combine sidebar lists with additional `GroupBox` cards above the list
- some views feel like "sidebar plus dashboard plus detail" all inside one split

Recommendation:

- standardize a small number of layout templates:
  - list + detail
  - dashboard + output
  - document list + detail
- use consistent sidebar widths across comparable sections
- avoid stacking too many "control cards" ahead of the list unless they materially help navigation

Reason:

- consistency will make the app feel calmer and easier to learn

### 4. Some action-heavy cards should become inspectors, toolbars, or settings

Current state:

- `Catalog` has a saved-search card
- `Installed` has a Brewfile export card
- `Services` has a cleanup card
- several sections include large embedded live-output blocks

Recommendation:

- keep action cards only where they are primary to the section
- move app-wide behavior choices into Settings
- consider moving secondary controls into toolbar menus or a trailing inspector over time

Reason:

- the current layout is functional but can feel crowded

## Proposed Settings Information Architecture

The app already has persisted state and clear user-adjustable behaviors. These should become the first real Settings panes.

### General

Good candidates:

- enable or disable completion notifications
- optionally choose whether notification sounds are used
- choose the default launch section
- choose whether the app reopens the last selected Brewfile automatically

Rationale:

- these are app-wide behavior preferences, not per-screen working state

### Brewfile

Good candidates:

- remember last selected Brewfile
- preferred default export directory for generated Brewfiles
- preferred default export scope when generating a Brewfile from `Installed`

Rationale:

- the app already persists Brewfile selection in [Sources/Services/Persistence/BrewfileSelectionStore.swift](/Users/cmb/Workspace/github.com/boggybumblebee/hodgepodge/Sources/Services/Persistence/BrewfileSelectionStore.swift)
- these choices affect repeated workflows and feel like real preferences

### Notifications

Good candidates:

- enable all command completion notifications
- optionally scope notifications to long-running operations only
- optionally scope notifications by area:
  - package actions
  - maintenance
  - services
  - Brewfile actions

Rationale:

- notification behavior is currently implementation-driven in [Sources/Services/Notifications/CommandNotificationScheduler.swift](/Users/cmb/Workspace/github.com/boggybumblebee/hodgepodge/Sources/Services/Notifications/CommandNotificationScheduler.swift), not user-driven

### Advanced

Good candidates:

- command history retention limit
- whether raw command output should auto-clear after successful completion
- whether compatibility warnings should be surfaced when a Homebrew version exposes degraded support

Rationale:

- these are real preferences, but not good defaults for the main Settings panes

## What Should Stay Out of Settings

These are important, but they are better treated as per-screen state or user data rather than app preferences:

- current search text
- current sort and filter selections
- current selected package or service
- saved searches themselves
- favorites themselves
- current analytics period
- transient confirmation choices for destructive actions

Reason:

- these are part of working context, not long-lived application configuration

## Recommended UI Cleanup Priorities

### Priority 1

- replace the placeholder `Settings` section with a real Settings scene
- remove `Settings` from the sidebar
- add an app-level Settings command path

### Priority 2

- move refresh, filtering, and sort controls into toolbars for:
  - `Catalog`
  - `Installed`
  - `Outdated`
  - `Services`
  - `Taps`

### Priority 3

- standardize split widths and card spacing across major sections
- reduce vertical header height where it does not add product value

### Priority 4

- review action cards one by one and decide whether each belongs:
  - inline in content
  - in a toolbar menu
  - in Settings
  - in a trailing inspector

## Phase 9 Implementation Order

Recommended next slices:

1. Create a real `Settings` scene and remove the sidebar placeholder.
2. Add a small shared settings store and start with `General` plus `Notifications`.
3. Refactor `Catalog` and `Installed` to use more native toolbar-driven controls.
4. Continue section-by-section UI normalization using the same layout rules.
5. Start the Homebrew compatibility hardening pass after UI/settings foundations are in place.

## Compatibility Follow-On

This audit does not implement compatibility work yet, but it does suggest one important design rule for the next slice:

- compatibility handling should be mostly internal, not exposed as user-facing settings unless the behavior meaningfully changes the user experience

Examples of likely internal compatibility work:

- capability probing for `brew` subcommands and flags
- version-aware command composition
- defensive decoding for evolving Homebrew JSON
- compatibility test fixtures for multiple Homebrew payload shapes
