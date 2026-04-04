import Foundation

/// Registry of all known airline providers. To add a new airline, create a
/// new type conforming to `AirlineProvider` and append it to `.default`.
struct ProviderRegistry {
    let providers: [AirlineProvider]

    static let `default` = ProviderRegistry(providers: [
        DeltaProvider()
        // Future: UnitedProvider(), AmericanProvider(), SouthwestProvider(), ...
    ])

    /// First provider whose `matches(ssid:)` returns true, or nil if the
    /// current network is not a recognized in-flight Wi-Fi.
    func provider(forSSID ssid: String?) -> AirlineProvider? {
        guard let ssid else { return nil }
        return providers.first { $0.matches(ssid: ssid) }
    }
}
