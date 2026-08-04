import SwiftUI

@main
struct OverParWatchApp: App {
    @StateObject private var round = WatchRoundService()

    var body: some Scene {
        WindowGroup {
            WatchDistanceView()
                .environmentObject(round)
        }
    }
}
