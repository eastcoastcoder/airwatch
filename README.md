# Airwatch

A tiny macOS menu bar app that shows your flight's live altitude and telemetry
when you're connected to in-flight Wi-Fi.

> **Note:** this project was written almost entirely by an AI coding agent
> (Claude). Treat the code accordingly — read before you trust it.

## Features

- Lives in the menu bar; no Dock icon.
- Auto-detects in-flight Wi-Fi by SSID and talks to the airline's captive-portal
  API for live flight data.
- Currently supports **Delta** (any SSID containing `deltawifi`). Architecture
  is pluggable — adding a new carrier is one `AirlineProvider` conformance.
- Click the menu bar item for a popover with altitude, airspeed, ground speed,
  heading, outside temperature, route, time remaining, phase, and flight
  number.
- Customizable:
  - Which fields appear in the menu bar label (and their order).
  - Refresh interval (1s / 3s / 5s / 10s / 15s / 30s / 60s, default 5s).
  - Imperial (ft · kt · °F) or metric (m · km/h · °C) units.
- Shows a warning icon when the airline reports connectivity is down.

## Requirements

- macOS 13 Ventura or later.
- Location permission — macOS 14+ gates Wi-Fi SSID access behind Location
  Services. Airwatch asks for it the first time it launches.

## Building

Open `Airwatch.xcodeproj` in Xcode and hit Run, or:

```sh
xcodebuild -project Airwatch.xcodeproj -scheme Airwatch -configuration Release build
```

The same sources also build as a Swift Package:

```sh
swift build
```

(The SPM target runs as a plain executable without a proper app bundle — use
the Xcode project for day-to-day use.)

## Adding another airline

1. Create `Sources/Airwatch/Providers/<Airline>/<Airline>Provider.swift`
   conforming to `AirlineProvider`:
   - `matches(ssid:)` — identify the carrier's in-flight Wi-Fi.
   - `fetchSnapshot()` — hit the captive-portal API and return a normalized
     `FlightSnapshot`.
2. Register it in `ProviderRegistry.default`.
3. That's it — the UI, preferences, and formatting all work automatically.

## Project layout

```
Sources/Airwatch/
  App.swift                         # SwiftUI @main entry
  Models/FlightSnapshot.swift       # airline-agnostic data model + fields
  Providers/
    AirlineProvider.swift           # protocol all carriers implement
    ProviderRegistry.swift          # registry + SSID matching
    Delta/DeltaProvider.swift       # Delta reference implementation
  Services/
    WiFiMonitor.swift               # CoreWLAN + Location auth
    FlightMonitor.swift             # poll loop + state machine
  Settings/Preferences.swift        # UserDefaults-backed prefs
  Views/
    MenuBarLabel.swift              # compact menu bar label
    FlightPopoverView.swift         # dropdown pane
    SettingsView.swift              # preferences window
```

## Releases

Pushing a tag matching `v*` (e.g. `v0.1.0`) triggers a GitHub Actions workflow
that builds the app and publishes a zipped `Airwatch.app` as a GitHub release
asset. The build is unsigned and ad-hoc codesigned — you'll need to
right-click → Open the first time, or remove the quarantine attribute:

```sh
xattr -dr com.apple.quarantine /Applications/Airwatch.app
```

## License

MIT
