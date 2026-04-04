import Foundation

/// Protocol implemented once per airline. Adding a new carrier means writing
/// a new type that conforms to this and registering it in `ProviderRegistry`.
protocol AirlineProvider: Sendable {
    /// Human-readable name, e.g. "Delta".
    var name: String { get }

    /// Returns true if the given Wi-Fi SSID belongs to this airline's
    /// in-flight network. Matching should be case-insensitive and tolerate
    /// the suffixes airlines sometimes add (e.g. "deltawifi.com").
    func matches(ssid: String) -> Bool

    /// Fetch the latest flight snapshot. Implementations should throw on
    /// network failure; transient connectivity issues are reflected in
    /// `FlightSnapshot.connectivityHealthy`.
    func fetchSnapshot() async throws -> FlightSnapshot
}

/// Shared JSON decoder with a lenient ISO-8601 strategy. Most airline APIs
/// emit timestamps with or without fractional seconds; we don't actually rely
/// on the parsed date for display so a best-effort parse is fine.
extension JSONDecoder {
    static let airline: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
