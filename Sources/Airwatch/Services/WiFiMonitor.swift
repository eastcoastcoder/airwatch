import CoreLocation
import CoreWLAN
import Foundation

/// Returns the SSID of the currently associated Wi-Fi network.
///
/// On macOS 14+, `CWInterface.ssid()` returns nil unless the app has asked
/// the user for Location permission — the entitlement alone is insufficient,
/// you must actively trigger the prompt via CLLocationManager. We request it
/// lazily on first read and keep a manager alive to receive the response.
final class WiFiMonitor: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var hasRequestedAuthorization = false

    /// Called on the main actor when the user grants (or changes) location
    /// permission, so the monitor can re-poll immediately instead of waiting
    /// for the next scheduled tick.
    var onAuthorizationChange: (() -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    /// Whether the user has granted (or not yet been asked) location permission.
    /// Returns false only when explicitly denied or restricted.
    var hasLocationPermission: Bool {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return false
        default:
            return true
        }
    }

    func currentSSID() -> String? {
        ensureLocationAuthorization()
        return CWWiFiClient.shared().interface()?.ssid()
    }

    private func ensureLocationAuthorization() {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    // CLLocationManagerDelegate — we don't actually use location, we just
    // need the authorization so CoreWLAN will hand us the SSID.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?()
    }
}
