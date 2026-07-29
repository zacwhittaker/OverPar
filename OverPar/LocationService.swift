@preconcurrency import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorization: CLAuthorizationStatus
    @Published private(set) var location: CLLocation?
    @Published private(set) var isSettling = false
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private var samples: [CLLocation] = []
    private var captureCompletion: ((Coordinate?) -> Void)?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
    }

    func requestForegroundPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestOneShotLocation() {
        manager.requestLocation()
    }

    func startRoundUpdates() {
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.startUpdatingLocation()
    }

    func stopRoundUpdates() {
        manager.stopUpdatingLocation()
    }

    func captureStablePoint(completion: @escaping (Coordinate?) -> Void) {
        guard authorization == .authorizedAlways || authorization == .authorizedWhenInUse else {
            errorMessage = "Allow location while using OverPar before recording a point."
            completion(nil)
            return
        }
        samples.removeAll()
        captureCompletion = completion
        isSettling = true
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedAlways || authorization == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let fresh = locations.filter {
            $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 30 && abs($0.timestamp.timeIntervalSinceNow) < 10
        }
        guard let latest = fresh.last else { return }
        location = latest
        guard isSettling else { return }
        samples.append(contentsOf: fresh)
        samples = Array(samples.suffix(8))
        guard samples.count >= 5 else { return }

        let sortedAccuracy = samples.map(\.horizontalAccuracy).sorted()
        let medianAccuracy = sortedAccuracy[sortedAccuracy.count / 2]
        let latitude = samples.map(\.coordinate.latitude).reduce(0, +) / Double(samples.count)
        let longitude = samples.map(\.coordinate.longitude).reduce(0, +) / Double(samples.count)
        let centre = CLLocation(latitude: latitude, longitude: longitude)
        let spread = samples.map { $0.distance(from: centre) }.max() ?? .infinity
        guard medianAccuracy <= 15, spread <= 10 else { return }

        isSettling = false
        manager.stopUpdatingLocation()
        let point = Coordinate(
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: medianAccuracy,
            capturedAt: Date()
        )
        let completion = captureCompletion
        captureCompletion = nil
        completion?(point)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isSettling = false
        errorMessage = error.localizedDescription
        let completion = captureCompletion
        captureCompletion = nil
        completion?(nil)
    }
}
