import Foundation
import Combine

/// Observable state owner for the menu bar and popover. Drives a polling
/// loop that:
///   1. Reads the current Wi-Fi SSID.
///   2. Picks the matching airline provider (if any).
///   3. Asks that provider for a fresh snapshot.
@MainActor
final class FlightMonitor: ObservableObject {
    enum State: Equatable {
        case notOnFlightWiFi
        case locationDenied
        case connecting(airline: String)
        case connected(FlightSnapshot)
        case error(String)
    }

    @Published private(set) var state: State = .notOnFlightWiFi

    private let registry: ProviderRegistry
    private let preferences: Preferences
    private let wifi = WiFiMonitor()
    private var pollTask: Task<Void, Never>?
    private var intervalObserver: AnyCancellable?

    init(registry: ProviderRegistry, preferences: Preferences) {
        self.registry = registry
        self.preferences = preferences
        wifi.onAuthorizationChange = { [weak self] in
            Task { @MainActor in self?.refreshNow() }
        }
        // Restart the polling loop whenever the user picks a new interval.
        intervalObserver = preferences.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in self?.start() }
        start()
    }

    deinit { pollTask?.cancel() }

    func start() {
        pollTask?.cancel()
        let interval = preferences.refreshInterval
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            }
        }
    }

    func refreshNow() {
        Task { await tick() }
    }

    private func tick() async {
        guard wifi.hasLocationPermission else {
            state = .locationDenied
            return
        }

        let ssid = wifi.currentSSID()
        guard let provider = registry.provider(forSSID: ssid) else {
            state = .notOnFlightWiFi
            return
        }

        if case .connected = state {} else {
            state = .connecting(airline: provider.name)
        }

        do {
            let snapshot = try await provider.fetchSnapshot()
            state = .connected(snapshot)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
