import GoogleMaps
import SwiftUI
import UIKit

final class OverParAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        GoogleMapsConfiguration.configure()
        return true
    }
}

enum GoogleMapsConfiguration {
    private(set) static var isConfigured = false

    static func configure() {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "OVERPAR_GOOGLE_MAPS_API_KEY") as? String,
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !key.contains("$(")
        else { return }
        isConfigured = GMSServices.provideAPIKey(key)
    }
}

@main
struct OverParApp: App {
    @UIApplicationDelegateAdaptor(OverParAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = AppStore()
    @StateObject private var location = LocationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(location)
                .tint(OverParTheme.forest)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.flushPersistence()
            }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isShowingLaunch = true

    var body: some View {
        ZStack {
            Group {
                if store.profile.hasCompletedOnboarding {
                    MainTabView()
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            if isShowingLaunch {
                OverParLaunchView()
                    .zIndex(10)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: store.profile.hasCompletedOnboarding)
        .task {
            guard isShowingLaunch else { return }
            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(.easeOut(duration: 0.18)) {
                isShowingLaunch = false
            }
        }
    }
}

private struct OverParLaunchView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            OverParTheme.canvas.ignoresSafeArea()
            CourseArtwork()
                .frame(width: 320, height: 320)
                .clipShape(Circle())
                .scaleEffect(isAnimating ? 1.04 : 0.94)
                .opacity(isAnimating ? 0.42 : 0.22)

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(OverParTheme.surface)
                        .frame(width: 126, height: 126)
                        .shadow(color: OverParTheme.forest.opacity(0.12), radius: 24, y: 10)
                    Image(systemName: "figure.golf")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(OverParTheme.forest)
                }
                VStack(spacing: 5) {
                    Text("OverPar")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(OverParTheme.forestDark)
                    Text("YOUR ROUND, BEAUTIFULLY SIMPLE")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(OverParTheme.secondary)
                }
                ModernLoadingRing()
                    .padding(.top, 8)
            }
            .offset(y: -16)
            .scaleEffect(isAnimating ? 1 : 0.92)
            .opacity(isAnimating ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                isAnimating = true
            }
        }
    }
}

private struct ModernLoadingRing: View {
    @State private var isSpinning = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(OverParTheme.line, lineWidth: 4)
            Circle()
                .trim(from: 0.08, to: 0.68)
                .stroke(
                    OverParTheme.forest,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
        }
        .frame(width: 30, height: 30)
        .onAppear {
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                isSpinning = true
            }
        }
    }
}
