@preconcurrency import CoreLocation
import Foundation
import WatchConnectivity

@MainActor
final class WatchRoundService: NSObject, ObservableObject, CLLocationManagerDelegate, WCSessionDelegate {
    @Published private(set) var holeNumber = 1
    @Published private(set) var target: CLLocationCoordinate2D?
    @Published private(set) var location: CLLocation?
    @Published private(set) var usesYards = true
    @Published private(set) var clubName = ""
    @Published private(set) var rulesCompliant = false
    @Published private(set) var isRoundActive = false
    @Published private(set) var locationError: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            apply(WCSession.default.receivedApplicationContext)
        }
    }

    var distance: CLLocationDistance? {
        guard let target, let location, isFresh(location) else { return nil }
        return location.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
    }

    var displayDistance: Int? {
        distance.map { Int(($0 * (usesYards ? 1.09361 : 1)).rounded()) }
    }

    var accuracyText: String {
        guard let location, isFresh(location) else { return "GPS settling" }
        let accuracy = location.horizontalAccuracy * (usesYards ? 1.09361 : 1)
        return "GPS ±\(Int(accuracy.rounded())) \(usesYards ? "yd" : "m")"
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            locationError = "Allow location for live distance."
        }
    }

    func stop() { manager.stopUpdatingLocation() }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last,
              latest.horizontalAccuracy >= 0,
              latest.horizontalAccuracy <= 40,
              isFresh(latest) else { return }
        location = latest
        locationError = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = "GPS unavailable"
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let context = session.receivedApplicationContext
        Task { @MainActor in self.apply(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    private func apply(_ context: [String: Any]) {
        guard !context.isEmpty else { return }
        isRoundActive = context["isActive"] as? Bool ?? false
        guard isRoundActive else {
            target = nil
            clubName = ""
            return
        }
        holeNumber = context["holeNumber"] as? Int ?? 1
        usesYards = context["usesYards"] as? Bool ?? true
        rulesCompliant = context["rulesCompliant"] as? Bool ?? false
        clubName = context["clubName"] as? String ?? ""
        if let latitude = context["targetLatitude"] as? Double,
           let longitude = context["targetLongitude"] as? Double {
            target = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    private func isFresh(_ location: CLLocation) -> Bool {
        abs(location.timestamp.timeIntervalSinceNow) < 15
    }
}
