import Foundation
import CoreLocation

/// Ramazan vakitleri için tek seferlik, yaklaşık konum. Konum saklanmaz, sadece enlem/boylam ayarlara yazılır.
@MainActor
final class LocationOnce: NSObject, CLLocationManagerDelegate {
    static let shared = LocationOnce()

    private let manager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request(_ completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        self.completion = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            finish(nil)
        }
    }

    private func finish(_ c: CLLocationCoordinate2D?) {
        completion?(c)
        completion = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.completion != nil else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: self.manager.requestLocation()
            case .notDetermined: break
            default: self.finish(nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let c = locations.last?.coordinate
        Task { @MainActor in self.finish(c) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }
}
