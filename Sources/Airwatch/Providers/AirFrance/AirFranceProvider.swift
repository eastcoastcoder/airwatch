import Foundation

/// Air France in-flight Wi-Fi provider.
///
/// Air France uses three endpoints:
///   - `wifi.airfrance.com/starlinkrouter/diagnostics` — disablement status
///     and Starlink router location (the only reliable altitude source)
///   - `wifi.airfrance.com/starlinkrouter/sandbox-client` — clientId/routerId
///     needed to authenticate the flightdata call
///   - `freewifi.airfrance.com/ach/api/flightdata` — flight info, aircraft
///     position, and connectivity health
struct AirFranceProvider: AirlineProvider {
    let name = "Air France"

    private let diagnosticsURL = URL(string: "https://wifi.airfrance.com/starlinkrouter/diagnostics")!
    private let sandboxClientURL = URL(string: "https://wifi.airfrance.com/starlinkrouter/sandbox-client")!
    private let flightDataURL = URL(string: "https://freewifi.airfrance.com/ach/api/flightdata")!

    func matches(ssid: String) -> Bool {
        ssid.lowercased() == "airfrancewifi"
    }

    func fetchSnapshot() async throws -> FlightSnapshot {
        let diagnostics = try await fetch(Diagnostics.self, from: diagnosticsURL)

        let dish = diagnostics.dish

        guard dish.disablementCode == "okay" else {
            throw AirFranceError.disabled(dish.disablementCode)
        }

        let sandbox = try await fetch(SandboxClient.self, from: sandboxClientURL)

        var components = URLComponents(url: flightDataURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "cb", value: "1"),
            URLQueryItem(name: "clientId", value: sandbox.clientId),
            URLQueryItem(name: "routerId", value: sandbox.routerId),
        ]

        var flightData: FlightDataResponse?
        do {
            flightData = try await fetch(FlightDataResponse.self, from: components.url!)
        } catch {
            // flightdata API can fail outside actual flight conditions
            flightData = nil
        }

        let loc = dish.location
        let aircraft = flightData?.aircraft
        let flight = flightData?.flight
        let healthy = flightData?.services?.passengerInternet?.healthy ?? false

        // Prefer flightdata altitude (pressure altitude, matches IFE/ADS-B)
        // over diagnostics (GPS/ellipsoid, reads ~1-2k ft high).
        let altFeet: Double? = if let a = aircraft?.altitude, a > 0 {
            a
        } else {
            loc.altitudeMeters * 3.28084
        }

        // horizontalVelocity is km/h; hide when zero (on ground / no data).
        let gsKnots: Double? = if let v = aircraft?.horizontalVelocity, v > 0 {
            v / 1.852
        } else {
            nil
        }

        return FlightSnapshot(
            airline: name,
            flightNumber: flight?.number,
            origin: flight?.originIATA,
            destination: flight?.destinationIATA,
            altitudeFeet: altFeet,
            airspeedKnots: nil,
            groundspeedKnots: gsKnots,
            headingDegrees: nil,
            outsideAirTempC: nil,
            latitude: loc.latitude,
            longitude: loc.longitude,
            timeToGoMinutes: flight?.timeToDestination,
            flightDurationMinutes: flight?.duration,
            flightPhase: flight?.phase,
            connectivityHealthy: healthy,
            fetchedAt: Date()
        )
    }

    private func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder.airline.decode(T.self, from: data)
    }

    // MARK: - Wire types (Air France-specific; kept private to this file)

    private struct Diagnostics: Decodable {
        let dish: Dish

        struct Dish: Decodable {
            let disablementCode: String
            let location: Location
        }

        struct Location: Decodable {
            let latitude: Double
            let longitude: Double
            let altitudeMeters: Double
        }
    }

    private struct SandboxClient: Decodable {
        let routerId: String
        let clientId: String
    }

    private struct FlightDataResponse: Decodable {
        let aircraft: Aircraft?
        let flight: Flight?
        let services: Services?
    }

    private struct Aircraft: Decodable {
        let altitude: Double?
        let latitude: Double?
        let longitude: Double?
        let horizontalVelocity: Double?
    }

    private struct Flight: Decodable {
        let number: String?
        let phase: String?
        let originIATA: String?
        let destinationIATA: String?
        let duration: Int?
        let timeToDestination: Int?
    }

    private struct Services: Decodable {
        let passengerInternet: PassengerInternet?

        struct PassengerInternet: Decodable {
            let healthy: Bool?
        }
    }
}

enum AirFranceError: Error, LocalizedError {
    case disabled(String)

    var errorDescription: String? {
        switch self {
        case .disabled(let code):
            return "Air France Wi-Fi disabled: \(code)"
        }
    }
}
