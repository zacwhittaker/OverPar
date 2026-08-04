import CoreLocation
import Foundation
import WatchConnectivity

@MainActor
final class WatchRoundSync: NSObject, WCSessionDelegate {
    static let shared = WatchRoundSync()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func publish(
        round: ActiveRound,
        hole: Hole,
        units: String,
        recommendation: ClubRecommendation?
    ) {
        guard WCSession.isSupported(), let target = hole.greenReference else { return }
        let context: [String: Any] = [
            "isActive": true,
            "holeNumber": round.holeNumber,
            "targetLatitude": target.latitude,
            "targetLongitude": target.longitude,
            "usesYards": units == "yards",
            "rulesCompliant": round.rulesCompliant,
            "clubName": round.rulesCompliant ? "" : (recommendation?.club.displayName ?? "")
        ]
        try? WCSession.default.updateApplicationContext(context)
    }

    func clear() {
        guard WCSession.isSupported() else { return }
        try? WCSession.default.updateApplicationContext(["isActive": false])
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
