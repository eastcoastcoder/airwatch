import SwiftUI

/// The dropdown pane shown when the menu bar icon is clicked. Always shows
/// the full set of known fields, regardless of menu-bar customization.
struct FlightPopoverView: View {
    @EnvironmentObject var monitor: FlightMonitor
    @EnvironmentObject var preferences: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if hasContent {
                Divider()
                content
            }
            Divider()
            footer
        }
        .padding(16)
    }

    private var hasContent: Bool {
        if case .connected = monitor.state { return true }
        return false
    }

    @ViewBuilder
    private var header: some View {
        switch monitor.state {
        case .connected(let snap):
            HStack {
                Image(systemName: snap.connectivityHealthy ? "airplane" : "exclamationmark.triangle.fill")
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text(snap.flightNumber ?? "\(snap.airline) Flight")
                        .font(.headline)
                    if let o = snap.origin, let d = snap.destination {
                        Text("\(o) → \(d)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        case .connecting(let airline):
            Text("Connecting to \(airline)…").font(.headline)
        case .notOnFlightWiFi:
            Text("Not on in-flight Wi-Fi").font(.headline)
        case .locationDenied:
            VStack(alignment: .leading, spacing: 4) {
                Text("Location Permission Required").font(.headline)
                Text("Airwatch needs Location access to read the Wi-Fi network name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderless)
                .padding(.top, 2)
            }
        case .error(let msg):
            Text("Error: \(msg)").font(.headline).foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var content: some View {
        if case .connected(let snap) = monitor.state {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(FlightField.allCases) { field in
                    if let value = field.format(snap, units: preferences.units) {
                        HStack(spacing: 10) {
                            Image(systemName: field.iconName)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 18)
                            Text(field.displayName)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(value).monospacedDigit()
                        }
                    }
                }
                if !snap.connectivityHealthy {
                    Label("Connectivity is currently unavailable",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Refresh") { monitor.refreshNow() }
            Spacer()
            if #available(macOS 14.0, *) {
                SettingsLink { Text("Settings…") }
            }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.borderless)
    }
}
