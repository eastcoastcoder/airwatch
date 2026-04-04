import Foundation

/// A normalized, airline-agnostic view of a flight's current state.
///
/// Airline providers map their native payloads into this struct so that the
/// rest of the app (UI, preferences, formatting) never has to know which
/// carrier produced the data.
struct FlightSnapshot: Equatable {
    var airline: String
    var flightNumber: String?
    var origin: String?
    var destination: String?

    var altitudeFeet: Double?
    var airspeedKnots: Double?
    var groundspeedKnots: Double?
    var headingDegrees: Double?
    var outsideAirTempC: Double?
    var latitude: Double?
    var longitude: Double?

    /// Minutes remaining in the flight.
    var timeToGoMinutes: Int?
    /// Total scheduled flight duration in minutes.
    var flightDurationMinutes: Int?
    /// e.g. "Cruise", "Climb", "Descent".
    var flightPhase: String?

    var connectivityHealthy: Bool
    var fetchedAt: Date
}

/// Unit system for displayed values. "Imperial" is Airwatch's default
/// because all the source airline APIs report in feet/knots/Celsius and
/// most pilots/avgeeks think in those units; metric is there for everyone
/// else.
enum UnitSystem: String, CaseIterable, Codable, Identifiable {
    case imperial
    case metric

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .imperial: return "Imperial"
        case .metric:   return "Metric"
        }
    }
}

/// Every piece of info the menu-bar label can potentially show. The user
/// picks an ordered subset of these in settings.
enum FlightField: String, CaseIterable, Identifiable, Codable {
    case altitude
    case airspeed
    case groundspeed
    case heading
    case outsideTemp
    case flightNumber
    case route
    case timeToGo
    case flightPhase

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .altitude: return "Altitude"
        case .airspeed: return "Airspeed"
        case .groundspeed: return "Ground Speed"
        case .heading: return "Heading"
        case .outsideTemp: return "Outside Temp"
        case .flightNumber: return "Flight Number"
        case .route: return "Route"
        case .timeToGo: return "Time Remaining"
        case .flightPhase: return "Phase"
        }
    }

    /// SF Symbol name used wherever this field is rendered (popover rows,
    /// settings toggles, reorder list).
    var iconName: String {
        switch self {
        case .altitude:     return "arrow.up.to.line"
        case .airspeed:     return "wind"
        case .groundspeed:  return "speedometer"
        case .heading:      return "location.north.line"
        case .outsideTemp:  return "thermometer.medium"
        case .flightNumber: return "number"
        case .route:        return "airplane.departure"
        case .timeToGo:     return "clock"
        case .flightPhase:  return "chart.line.uptrend.xyaxis"
        }
    }

    func format(_ snapshot: FlightSnapshot, units: UnitSystem = .imperial) -> String? {
        switch self {
        case .altitude:
            guard let ft = snapshot.altitudeFeet else { return nil }
            switch units {
            case .imperial: return "\(Self.grouped(ft)) ft"
            case .metric:   return "\(Self.grouped(ft * 0.3048)) m"
            }
        case .airspeed:
            guard let kt = snapshot.airspeedKnots else { return nil }
            switch units {
            case .imperial: return "\(Self.grouped(kt)) kt"
            case .metric:   return "\(Self.grouped(kt * 1.852)) km/h"
            }
        case .groundspeed:
            guard let kt = snapshot.groundspeedKnots else { return nil }
            switch units {
            case .imperial: return "\(Self.grouped(kt)) kt"
            case .metric:   return "\(Self.grouped(kt * 1.852)) km/h"
            }
        case .heading:
            guard let v = snapshot.headingDegrees else { return nil }
            return "\(Int(v.rounded()))°"
        case .outsideTemp:
            guard let c = snapshot.outsideAirTempC else { return nil }
            switch units {
            case .metric:   return "\(Int(c.rounded()))°C"
            case .imperial: return "\(Int((c * 9 / 5 + 32).rounded()))°F"
            }
        case .flightNumber:
            return snapshot.flightNumber
        case .route:
            guard let o = snapshot.origin, let d = snapshot.destination else { return nil }
            return "\(o)→\(d)"
        case .timeToGo:
            guard let m = snapshot.timeToGoMinutes else { return nil }
            let h = m / 60, mm = m % 60
            return h > 0 ? String(format: "%dh %02dm", h, mm) : "\(mm)m"
        case .flightPhase:
            return snapshot.flightPhase
        }
    }

    /// Rounds to the nearest integer and inserts thousands separators
    /// appropriate to the user's locale (e.g. 38972 → "38,972").
    private static func grouped(_ value: Double) -> String {
        Self.numberFormatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()
}
