import SwiftUI

/// The compact label that lives in the menu bar.
///
/// Display rules:
///   - Not on flight Wi-Fi → a dimmed plane icon only.
///   - Connectivity down → warning triangle + altitude (if any).
///   - Healthy → plane icon + user-selected fields.
struct MenuBarLabel: View {
    @EnvironmentObject var monitor: FlightMonitor
    @EnvironmentObject var preferences: Preferences

    var body: some View {
        HStack(spacing: 4) {
            icon
            if let text = labelText, !text.isEmpty {
                Text(text)
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch monitor.state {
        case .connected(let snap) where !snap.connectivityHealthy:
            Image(systemName: "exclamationmark.triangle.fill")
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
        case .connected:
            Image(systemName: "airplane")
        case .connecting:
            Image(systemName: "airplane")
        case .notOnFlightWiFi:
            Image(systemName: "airplane")
                .opacity(0.4)
        case .locationDenied:
            Image(systemName: "location.slash")
        }
    }

    private var labelText: String? {
        guard case .connected(let snap) = monitor.state else { return nil }
        let fields = preferences.menuBarFields
        // If both speeds are shown at once they'd collide (e.g. "470 kt · 507 kt"),
        // so tag the ground speed with " GS" only in that case.
        let ambiguous = fields.contains(.airspeed) && fields.contains(.groundspeed)
        let parts = fields.compactMap { field -> String? in
            guard let base = field.format(snap, units: preferences.units) else { return nil }
            return (ambiguous && field == .groundspeed) ? "\(base) GS" : base
        }
        return parts.joined(separator: " · ")
    }
}
