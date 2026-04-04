import SwiftUI

@main
struct AirwatchApp: App {
    @StateObject private var preferences = Preferences.shared
    @StateObject private var monitor = FlightMonitor(registry: .default, preferences: .shared)

    var body: some Scene {
        MenuBarExtra {
            FlightPopoverView()
                .environmentObject(monitor)
                .environmentObject(preferences)
                .frame(width: 320)
        } label: {
            MenuBarLabel()
                .environmentObject(monitor)
                .environmentObject(preferences)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(preferences)
        }
    }
}
