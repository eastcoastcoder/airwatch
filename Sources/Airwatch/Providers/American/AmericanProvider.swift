import Foundation

/// American Airlines in-flight Wi-Fi provider.
///
/// American exposes two different API surfaces for flight telemetry:
///   - `https://www.aainflight.com/api/v1/connectivity/viasat/flight`
///   - `https://www.aainflight.com/api/v1/connectivity/intelsat/system-status`
///
/// Some flights are available on the first endpoint and others on the alt.
/// This provider first tries the primary endpoint and falls back when needed.
struct AmericanProvider: AirlineProvider {
    let name = "American Airlines"

    private let flightDataURL = URL(string: "https://www.aainflight.com/api/v1/connectivity/viasat/flight")!
    private let flightDataAltURL = URL(string: "https://www.aainflight.com/api/v1/connectivity/intelsat/system-status")!

    func matches(ssid: String) -> Bool {
        let normalized = ssid.lowercased()
        return normalized == "aainflight.com" || normalized == "aa-inflight"
    }

    func fetchSnapshot() async throws -> FlightSnapshot {
        let response = try await fetchFlightData()

        return FlightSnapshot(
            airline: name,
            flightNumber: response.flightNumber,
            origin: response.origin,
            destination: response.destination,
            altitudeFeet: response.altitudeFeet,
            airspeedKnots: nil,
            groundspeedKnots: response.groundspeedKnots,
            headingDegrees: nil,
            outsideAirTempC: nil,
            latitude: response.latitude,
            longitude: response.longitude,
            timeToGoMinutes: response.timeToGoMinutes,
            flightDurationMinutes: response.flightDurationMinutes,
            flightPhase: response.flightPhase,
            connectivityHealthy: true,
            fetchedAt: Date()
        )
    }

    private func fetchFlightData() async throws -> FlightDataResponse {
        do {
            let primary = try await fetchJSON(from: flightDataURL)
            let parsed = FlightDataResponse(json: primary)
            if parsed.hasUsefulData {
                return parsed
            }
        } catch {
            // If the primary path fails, fall back to the alternate endpoint.
        }

        let fallback = try await fetchJSON(from: flightDataAltURL)
        let parsed = FlightDataResponse(json: fallback)

        guard parsed.hasUsefulData else {
            throw AmericanProviderError.missingFlightData
        }

        return parsed
    }

    private func fetchJSON(from url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data, options: [])

        guard let dictionary = json as? [String: Any] else {
            throw AmericanProviderError.invalidResponse
        }

        return dictionary
    }

    private struct FlightDataResponse {
        let json: [String: Any]
        let flightInfo: [String: Any]?
        let positionalInfo: [String: Any]?
        let serviceInfo: [String: Any]?

        init(json: [String: Any]) {
            self.json = json
            self.flightInfo = json["flight_info"] as? [String: Any]
            self.positionalInfo = json["positional_info"] as? [String: Any]
            self.serviceInfo = json["service_info"] as? [String: Any]
        }

        var flightNumber: String? {
            stringValue(["flight_no"], from: flightInfo)
                ?? stringValue(["flightNumber", "flight_number", "flight"], from: json)
        }

        var origin: String? {
            stringValue(["departure_airport_iata"], from: flightInfo)
                ?? stringValue(["origin", "departure", "from"], from: json)
        }

        var destination: String? {
            stringValue(["arrival_airport_iata"], from: flightInfo)
                ?? stringValue(["destination", "arrival", "to"], from: json)
        }

        var altitudeFeet: Double? {
            doubleValue(["above_sea_level_feet", "above_gnd_level_feet", "above_ground_level_feet"], from: positionalInfo)
                ?? doubleValue(["altitude", "alt"], from: json)
        }

        var groundspeedKnots: Double? {
            let mph = doubleValue([
                "horizontal_velocity_mph",
                "speed",
                "groundSpeed",
                "ground_speed"
            ], from: positionalInfo)
            ?? doubleValue(["speed", "groundSpeed", "ground_speed"], from: json)

            guard let mph = mph, mph > 0 else { return nil }
            return mph / 1.15078
        }

        var timeToGoMinutes: Int? {
            intValue(["time_to_land_mins"], from: flightInfo)
                ?? intValue(["timeRemaining", "time_remaining", "eta"], from: json)
        }

        var flightDurationMinutes: Int? {
            if let total = doubleValue(["total_flight_duration_mins"], from: flightInfo) {
                return Int(total.rounded())
            }

            if let duration = doubleValue(["flightDuration", "duration"], from: json) {
                return Int(duration.rounded())
            }

            if let progress = progressPercent,
               let remaining = timeToGoMinutes,
               progress > 0,
               progress < 100 {
                return Int((Double(remaining) / (1 - progress / 100)).rounded())
            }

            return nil
        }

        var progressPercent: Double? {
            if let timeToLand = doubleValue(["time_to_land_mins"], from: flightInfo),
               let totalDuration = doubleValue(["total_flight_duration_mins"], from: flightInfo),
               totalDuration > 0 {
                return min(100, max(0, timeToLand / totalDuration * 100))
            }

            if let timeToGo = doubleValue(["timeToGo"], from: json),
               let flightDuration = doubleValue(["flightDuration"], from: json),
               flightDuration > 0 {
                let elapsed = flightDuration - timeToGo
                return min(100, max(0, elapsed / flightDuration * 100))
            }

            if let progress = doubleValue(["progress"], from: json) {
                return min(100, max(0, progress))
            }

            if let elapsed = doubleValue(["elapsed"], from: json),
               let duration = doubleValue(["duration"], from: json),
               duration > 0 {
                return min(100, max(0, elapsed / duration * 100))
            }

            if let traveled = doubleValue(["distance_traveled"], from: json),
               let total = doubleValue(["total_distance"], from: json),
               total > 0 {
                return min(100, max(0, traveled / total * 100))
            }

            return nil
        }

        var latitude: Double? {
            doubleValue(["latitude"], from: positionalInfo) ?? doubleValue(["latitude"], from: json)
        }

        var longitude: Double? {
            doubleValue(["longitude"], from: positionalInfo) ?? doubleValue(["longitude"], from: json)
        }

        var flightPhase: String? {
            stringValue(["flight_phase"], from: serviceInfo)
                ?? stringValue(["flightPhase"], from: json)
        }

        var hasUsefulData: Bool {
            flightNumber != nil
                || origin != nil
                || destination != nil
                || altitudeFeet != nil
                || timeToGoMinutes != nil
                || groundspeedKnots != nil
        }

        private func stringValue(_ keys: [String], from dictionary: [String: Any]?) -> String? {
            guard let dictionary = dictionary else { return nil }
            for key in keys {
                if let value = dictionary[key] {
                    if let string = value as? String {
                        return string
                    }
                    if let number = value as? NSNumber {
                        return number.stringValue
                    }
                }
            }
            return nil
        }

        private func doubleValue(_ keys: [String], from dictionary: [String: Any]?) -> Double? {
            guard let dictionary = dictionary else { return nil }
            for key in keys {
                if let value = dictionary[key] {
                    switch value {
                    case let double as Double:
                        return double
                    case let int as Int:
                        return Double(int)
                    case let number as NSNumber:
                        return number.doubleValue
                    case let string as String:
                        return Double(string)
                    default:
                        continue
                    }
                }
            }
            return nil
        }

        private func intValue(_ keys: [String], from dictionary: [String: Any]?) -> Int? {
            guard let number = doubleValue(keys, from: dictionary) else { return nil }
            return Int(number.rounded())
        }
    }
}

enum AmericanProviderError: Error, LocalizedError {
    case invalidResponse
    case missingFlightData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "American Airlines response could not be decoded."
        case .missingFlightData:
            return "American Airlines did not return flight telemetry."
        }
    }
}
