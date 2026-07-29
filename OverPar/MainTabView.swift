import SwiftUI

enum AppTab: Hashable {
    case home, play, gallery, range, profile
}

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection: AppTab = .home
    @State private var showResumePrompt = false
    @State private var showActiveRound = false
    @State private var hasOfferedResume = false

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView(selection: $selection) }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            NavigationStack { PlayView() }
                .tabItem { Label("Play", systemImage: "flag.fill") }
                .tag(AppTab.play)
            NavigationStack { GalleryView() }
                .tabItem { Label("Gallery", systemImage: "photo.stack.fill") }
                .tag(AppTab.gallery)
            NavigationStack { DrivingRangeView() }
                .tabItem { Label("Range", systemImage: "scope") }
                .tag(AppTab.range)
            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .task {
            guard !hasOfferedResume, store.activeRound != nil else { return }
            hasOfferedResume = true
            try? await Task.sleep(for: .milliseconds(450))
            showResumePrompt = true
        }
        .sheet(isPresented: $showResumePrompt) {
            ResumeRoundPrompt {
                showResumePrompt = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(220))
                    showActiveRound = true
                }
            }
            .presentationDetents([.height(330)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showActiveRound) {
            NavigationStack {
                ActiveRoundView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showActiveRound = false }
                        }
                    }
            }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selection: AppTab

    private var nearest: GolfCourse? { store.courses.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Good to see you,")
                            .foregroundStyle(OverParTheme.secondary)
                        Text(store.profile.displayName.components(separatedBy: " ").first ?? store.profile.displayName)
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    }
                    Spacer()
                    Circle()
                        .fill(OverParTheme.forest)
                        .frame(width: 48, height: 48)
                        .overlay(Text(initials).font(.headline).foregroundStyle(.white))
                }
                if let round = store.activeRound,
                   let course = store.courses.first(where: { $0.id == round.courseID }) {
                    NavigationLink {
                        ActiveRoundView()
                    } label: {
                        ResumeRoundCard(round: round, course: course)
                    }
                    .buttonStyle(.plain)
                }
                if let course = nearest {
                    SectionHeading(eyebrow: "Closest to you", title: "Nearest course")
                    CourseHeroCard(course: course)
                }
                SectionHeading(eyebrow: "Your clubhouse", title: "Quick starts")
                HStack(spacing: 12) {
                    quickCard("Driving Range", "Know every club", "scope") { selection = .range }
                    quickCard("Gallery", "\(store.gallery.count) private shots", "photo.stack.fill") { selection = .gallery }
                }
                if let homeID = store.profile.homeCourseID,
                   let home = store.courses.first(where: { $0.id == homeID }) {
                    SectionHeading(eyebrow: "Pinned home", title: home.name)
                    OverParCard {
                        HStack {
                            Image(systemName: "flag.checkered.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(OverParTheme.forest)
                            VStack(alignment: .leading) {
                                Text(home.facilityName).font(.headline)
                                Text("\(home.roundHoleCount) holes · Par \(home.roundTotalPar)")
                                    .font(.subheadline).foregroundStyle(OverParTheme.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationBarHidden(true)
        .overParPage()
    }

    private var initials: String {
        store.profile.displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    private func quickCard(_ title: String, _ subtitle: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(OverParTheme.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .padding()
            .background(OverParTheme.mint, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

private struct ResumeRoundPrompt: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let resume: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(OverParTheme.mint)
                    .frame(width: 70, height: 70)
                Image(systemName: "figure.golf")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(OverParTheme.forest)
            }
            VStack(spacing: 6) {
                Text("Your round is waiting")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                if let round = store.activeRound,
                   let course = store.courses.first(where: { $0.id == round.courseID }) {
                    Text("\(course.name) · Hole \(round.holeNumber) of \(course.roundHoleCount)")
                        .foregroundStyle(OverParTheme.secondary)
                }
                Text("Everything is safely saved on this phone.")
                    .font(.caption)
                    .foregroundStyle(OverParTheme.secondary)
            }
            Button("Resume round", action: resume)
                .buttonStyle(PrimaryButtonStyle())
            Button("Not now") { dismiss() }
                .font(.headline)
                .foregroundStyle(OverParTheme.forest)
        }
        .padding(24)
        .overParPage()
    }
}

private struct ResumeRoundCard: View {
    let round: ActiveRound
    let course: GolfCourse

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 54, height: 54)
                Image(systemName: "figure.golf")
                    .font(.title2.bold())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("RESUME ROUND")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.76))
                Text(course.name)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .lineLimit(1)
                Text("Hole \(round.holeNumber) of \(course.roundHoleCount)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            Spacer()
            Image(systemName: "arrow.right.circle.fill")
                .font(.title)
        }
        .foregroundStyle(.white)
        .padding(17)
        .background(OverParTheme.forest, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: OverParTheme.forest.opacity(0.2), radius: 14, y: 7)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your active golf round")
    }
}

struct CourseHeroCard: View {
    let course: GolfCourse

    var body: some View {
        OverParCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    StatusPill(text: course.isVerified ? "Verified" : "Community")
                    Spacer()
                    Image(systemName: course.isSaved ? "bookmark.fill" : "bookmark")
                }
                Text(course.name)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(course.facilityName).foregroundStyle(OverParTheme.secondary)
                Divider()
                HStack {
                    Label(course.repeatsLayout ? "\(course.holeCount)-hole layout ×\(course.loopCount)" : "\(course.holeCount) holes", systemImage: "figure.golf")
                    Label("Par \(course.roundTotalPar)", systemImage: "flag")
                }
                .font(.subheadline)
                HStack {
                    NavigationLink("Preview") { CoursePreviewView(course: course) }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    NavigationLink("Play") { RoundSetupView(course: course) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
    }
}
