# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Two parallel build systems share the same sources under `Sources/Airwatch/`:

- **Xcode project** (`Airwatch.xcodeproj`) — the real app bundle with entitlements, `Info.plist`, menu-bar `LSUIElement` config, and Location usage strings. Use this for day-to-day development and anything that needs Wi-Fi/Location APIs to actually work.
  ```sh
  xcodebuild -project Airwatch.xcodeproj -scheme Airwatch -configuration Release build
  ```
- **Swift Package** (`Package.swift`) — same sources, builds as a plain executable (no bundle, no entitlements). Useful for quick `swift build` compile checks, but the app will not function correctly when run this way because CoreWLAN SSID access requires the signed bundle + Location permission.

There are no tests in this repo.

If you add files under `Sources/Airwatch/`, they are picked up automatically by SPM but **must also be added to the Xcode project** or the shipped app will not include them.

## Architecture

Airwatch is a macOS menu-bar SwiftUI app (`LSUIElement`, no Dock icon) that polls an airline's in-flight Wi-Fi captive-portal API and renders live telemetry. The core design goal is that adding a new airline is a single-file change.

### The provider abstraction is the whole point

Everything flows through three types:

- `AirlineProvider` (`Sources/Airwatch/Providers/AirlineProvider.swift`) — protocol each carrier implements. Two methods: `matches(ssid:)` and `fetchSnapshot() async throws -> FlightSnapshot`.
- `FlightSnapshot` (`Sources/Airwatch/Models/FlightSnapshot.swift`) — the normalized, airline-agnostic data model. Every provider maps its native payload into this. The UI, formatting, and preferences code never see airline-specific types.
- `ProviderRegistry` (`Sources/Airwatch/Providers/ProviderRegistry.swift`) — static `.default` list that maps an SSID to a provider. Adding an airline means writing a `Providers/<Airline>/<Airline>Provider.swift` and appending it here. `DeltaProvider` is the reference implementation.

When changing provider-related code, preserve this invariant: **nothing outside `Providers/<Airline>/` should know which airline is active**. Airline-specific fields or quirks belong inside the provider, mapped onto `FlightSnapshot` (extend the snapshot if a field genuinely generalizes).

### Runtime state machine

`FlightMonitor` (`@MainActor`, `ObservableObject`) owns all live state as a four-case `State` enum: `notOnFlightWiFi | connecting | connected | error`. It runs a single `pollTask` that on each tick:

1. Asks `WiFiMonitor` for the current SSID (requires Location permission on macOS 14+; `WiFiMonitor.onAuthorizationChange` triggers a re-tick when the user grants it).
2. Resolves an `AirlineProvider` via `ProviderRegistry`.
3. Calls `fetchSnapshot()` and publishes the new `State`.

The poll loop is restarted whenever `Preferences.refreshInterval` changes (observed via Combine). Transient network issues from the airline API become `.error`; the airline's *own* connectivity-down signal is surfaced via `FlightSnapshot.connectivityHealthy` instead (shown as a warning icon, not an error state).

### Preferences and display

`Preferences` (UserDefaults-backed `ObservableObject`) drives both the menu bar label and settings UI. Two pieces of state are load-bearing for the UI:

- `menuBarFields: [FlightField]` — ordered subset. `MenuBarLabel` renders these left-to-right.
- `unitSystem: UnitSystem` — imperial/metric. All conversion happens in `FlightField.format(_:units:)`; providers always store SI-ish values in the snapshot (feet, knots, Celsius — matching what airline APIs natively emit).

`FlightField` is the single source of truth for what's displayable: adding a new field means adding a case, an icon, a display name, and a `format` branch — everything else (settings toggles, popover rows, menu bar) iterates over `FlightField.allCases`.

## Releases

Pushing a `v*` tag triggers a GitHub Actions workflow that builds and publishes a zipped, ad-hoc-signed `Airwatch.app` as a release asset.
