import Foundation

/// Delta Air Lines in-flight Wi-Fi provider.
///
/// Delta exposes two endpoints on the captive portal host `wifi.delta.com`:
///   - `/api/services`    — overall service health (we use `connectivity`)
///   - `/api/flight-data` — real-time flight telemetry
struct DeltaProvider: AirlineProvider {
    let name = "Delta"

    private let servicesURL = URL(string: "https://wifi.delta.com/api/services")!
    private let flightURL = URL(string: "https://wifi.delta.com/api/flight-data")!

    func matches(ssid: String) -> Bool {
        ssid.lowercased().contains("deltawifi")
    }

    func fetchSnapshot() async throws -> FlightSnapshot {
        // Fetch both endpoints in parallel. If services fails we still want
        // to surface flight data (and vice versa), so each call is isolated.
        async let servicesTask = fetch(Services.self, from: servicesURL)
        async let flightTask = fetch(FlightData.self, from: flightURL)

        let services = try? await servicesTask
        let flight = try await flightTask

        return FlightSnapshot(
            airline: name,
            flightNumber: flight.flightNumber,
            origin: flight.origin,
            destination: flight.destination,
            altitudeFeet: flight.altitude,
            airspeedKnots: flight.airspeed,
            groundspeedKnots: flight.groundspeed,
            headingDegrees: flight.heading,
            outsideAirTempC: flight.airTemperature,
            latitude: flight.latitude,
            longitude: flight.longitude,
            timeToGoMinutes: flight.timeToGo,
            flightDurationMinutes: flight.flightDuration,
            flightPhase: flight.flightPhase,
            connectivityHealthy: services?.connectivity ?? false,
            fetchedAt: Date()
        )
    }

    private func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "accept")
        request.setValue("https://wifi.delta.com/welcome", forHTTPHeaderField: "referer")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder.airline.decode(T.self, from: data)
    }

    // MARK: - Wire types (Delta-specific; kept private to this file)

    private struct Services: Decodable {
        let connectivity: Bool
    }

    private struct FlightData: Decodable {
        let flightNumber: String?
        let origin: String?
        let destination: String?
        let altitude: Double?
        let airspeed: Double?
        let groundspeed: Double?
        let heading: Double?
        let airTemperature: Double?
        let latitude: Double?
        let longitude: Double?
        let timeToGo: Int?
        let flightDuration: Int?
        let flightPhase: String?
    }
}
