import Foundation
import Combine

/// User-configurable display preferences, persisted to UserDefaults.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let fieldsKey = "menuBarFields"
    private let intervalKey = "refreshInterval"
    private let unitsKey = "unitSystem"
    private let defaults = UserDefaults.standard

    /// Allowed refresh cadences (seconds). Surfaced as a segmented picker.
    static let refreshIntervalOptions: [Int] = [1, 3, 5, 10, 15, 30, 60]

    @Published var menuBarFields: [FlightField] {
        didSet { persistFields() }
    }

    /// Seconds between polls. Defaults to 5s.
    @Published var refreshInterval: Int {
        didSet { defaults.set(refreshInterval, forKey: intervalKey) }
    }

    /// Imperial (ft/kt/°F) or metric (m/km·h/°C). Defaults to imperial.
    @Published var units: UnitSystem {
        didSet { defaults.set(units.rawValue, forKey: unitsKey) }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: "menuBarFields"),
           let decoded = try? JSONDecoder().decode([FlightField].self, from: data) {
            self.menuBarFields = decoded
        } else {
            self.menuBarFields = [.altitude]
        }

        let stored = UserDefaults.standard.integer(forKey: "refreshInterval")
        self.refreshInterval = Self.refreshIntervalOptions.contains(stored) ? stored : 5

        if let raw = UserDefaults.standard.string(forKey: "unitSystem"),
           let parsed = UnitSystem(rawValue: raw) {
            self.units = parsed
        } else {
            self.units = .imperial
        }
    }

    private func persistFields() {
        if let data = try? JSONEncoder().encode(menuBarFields) {
            defaults.set(data, forKey: fieldsKey)
        }
    }

    func toggle(_ field: FlightField) {
        if let idx = menuBarFields.firstIndex(of: field) {
            menuBarFields.remove(at: idx)
        } else {
            menuBarFields.append(field)
        }
    }
}
