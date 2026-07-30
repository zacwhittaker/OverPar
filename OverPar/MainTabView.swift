import SwiftUI

enum AppTab: Hashable {
    case home, play, gallery, range, profile
}

struct ResearchHomeView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selection: AppTab

    private var course: GolfCourse? { store.courses.first }
    private var firstName: String {
        store.profile.displayName.split(separator: " ").first.map(String.init) ?? store.profile.displayName
    }
    private var initials: String {
        store.profile.displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                pulse
                activity
            }
            .padding(.bottom, 28)
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .overParPage()
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            CourseCoverImage(course: course)
                .frame(height: 520)
                .clipped()
            LinearGradient(
                colors: [.black.opacity(0.10), .clear, .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("OverPar")
                        .font(.system(size: 31, weight: .heavy, design: .rounded))
                    Spacer()
                    Button { } label: { Image(systemName: "bell") }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
                    Circle()
                        .fill(OverParTheme.forest)
                        .frame(width: 42, height: 42)
                        .overlay(Text(initials).font(.headline.bold()))
                }
                .padding(.top, 60)
                Spacer()
                Text("Good \(greeting),")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
                Text(firstName)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .padding(.bottom, 178)
                Text("NEAREST COURSE")
                    .font(.caption2.bold())
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.78))
                Text(course?.name ?? "Your next round")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .padding(.top, 7)
                Text(course.map { "\($0.city)  ·  \($0.roundHoleCount) holes" } ?? "Discover community-mapped courses nearby")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.top, 4)
                Button {
                    selection = .play
                } label: {
                    HStack(spacing: 18) {
                        Text(course == nil ? "Explore courses" : "View course")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 50)
                    .background(OverParTheme.forest, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 15)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(height: 520)
    }

    private var pulse: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("YOUR GAME PULSE")
                .font(.caption2.bold())
                .tracking(1.1)
                .foregroundStyle(OverParTheme.forest)
            HStack(spacing: 0) {
                pulseMetric("\(store.completedRounds.count)", "Rounds")
                Divider().frame(height: 48)
                pulseMetric("\(store.gallery.count)", "Shot videos")
                Divider().frame(height: 48)
                pulseMetric("\(store.rangeHits.filter { !$0.isMishit }.count)", "Carries")
                Divider().frame(height: 48)
                pulseMetric("\(store.activeBag.count)", "Active clubs")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(OverParTheme.surface)
    }

    private func pulseMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(OverParTheme.secondary)
            Text(value).font(.system(.title2, design: .rounded, weight: .medium)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT ACTIVITY")
                .font(.caption2.bold())
                .tracking(1.1)
                .foregroundStyle(OverParTheme.forest)
            if let round = store.completedRounds.last {
                HStack(spacing: 13) {
                    CourseCoverImage(course: store.courses.first(where: { $0.id == round.courseID }))
                        .frame(width: 48, height: 48).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(round.courseName).font(.headline)
                        Text(round.startedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundStyle(OverParTheme.secondary)
                    }
                    Spacer()
                    Text("\(round.scores.values.reduce(0, +))")
                        .font(.title3.monospacedDigit())
                }
            } else {
                Button {
                    selection = .range
                } label: {
                    HStack {
                        Image(systemName: "scope")
                        Text("Start with your first carry")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "morning" : hour < 18 ? "afternoon" : "evening"
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection: AppTab
    @State private var showResumePrompt = false
    @State private var showActiveRound = false
    @State private var hasOfferedResume = false

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-screenshotTab"), arguments.indices.contains(index + 1) {
            let tab: AppTab = switch arguments[index + 1].lowercased() {
            case "play": .play
            case "gallery": .gallery
            case "range": .range
            case "profile": .profile
            default: .home
            }
            _selection = State(initialValue: tab)
        } else {
            _selection = State(initialValue: .home)
        }
        #else
        _selection = State(initialValue: .home)
        #endif
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { ResearchHomeView(selection: $selection) }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            NavigationStack { ResearchPlayView() }
                .tabItem { Label("Play", systemImage: "flag.fill") }
                .tag(AppTab.play)
            NavigationStack { GalleryView() }
                .tabItem { Label("Gallery", systemImage: "photo.stack.fill") }
                .tag(AppTab.gallery)
            NavigationStack { ResearchDrivingRangeView() }
                .tabItem { Label("Range", systemImage: "scope") }
                .tag(AppTab.range)
            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-screenshotActiveRound") {
                showActiveRound = true
                return
            }
            #endif
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
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Good afternoon,")
                            .font(.subheadline)
                            .foregroundStyle(OverParTheme.secondary)
                        Text(firstName)
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    }
                    Spacer()
                    Image(systemName: "bell")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                    Circle()
                        .fill(OverParTheme.forest.gradient)
                        .frame(width: 44, height: 44)
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
                homeHero

                if !store.completedRounds.isEmpty || !store.rangeHits.isEmpty || !store.gallery.isEmpty {
                    SectionHeading(eyebrow: "Your game", title: "At a glance")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        summaryCard(value: "\(store.completedRounds.count)", label: "Rounds saved", symbol: "flag.checkered")
                        summaryCard(value: "\(store.gallery.count)", label: "Private shots", symbol: "video.fill")
                        summaryCard(value: "\(store.rangeHits.filter { !$0.isMishit }.count)", label: "Range carries", symbol: "scope")
                        summaryCard(value: "\(store.activeBag.count)", label: "Clubs in bag", symbol: "figure.golf")
                    }
                }

                SectionHeading(eyebrow: "Quick start", title: "Your clubhouse")
                HStack(spacing: 10) {
                    quickCard("Range", "Dial in your bag", "scope") { selection = .range }
                    quickCard("Gallery", "\(store.gallery.count) private clips", "photo.stack.fill") { selection = .gallery }
                }

                if !store.courses.isEmpty {
                    SectionHeading(eyebrow: "Nearby", title: "More courses")
                    VStack(spacing: 0) {
                        ForEach(store.courses.prefix(3)) { course in
                            NavigationLink {
                                CoursePreviewView(course: course)
                            } label: {
                                HStack(spacing: 12) {
                                    CourseCoverImage(course: course)
                                        .frame(width: 64, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(course.name).font(.headline)
                                        Text("\(course.roundHoleCount) holes · Par \(course.roundTotalPar)")
                                            .font(.caption)
                                            .foregroundStyle(OverParTheme.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(OverParTheme.tertiary)
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if course.id != store.courses.prefix(3).last?.id {
                                Divider().padding(.leading, 76)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .background(OverParTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(OverParTheme.line))
                }
            }
            .padding(.horizontal, OverParTheme.Space.page)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .navigationBarHidden(true)
        .overParPage()
    }

    private var initials: String {
        store.profile.displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    private var firstName: String {
        store.profile.displayName.components(separatedBy: " ").first ?? store.profile.displayName
    }

    private var homeHero: some View {
        ZStack(alignment: .bottomLeading) {
            CourseCoverImage(course: nearest)
                .frame(height: 318)
            LinearGradient(
                colors: [.clear, .black.opacity(0.12), .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 12) {
                if let conditions = store.playingConditions {
                    HStack(spacing: 10) {
                        Label("\(Int(conditions.temperatureCelsius.rounded()))°C", systemImage: "sun.max.fill")
                        Label("\(Int(conditions.windSpeedKPH.rounded())) km/h", systemImage: "wind")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.9))
                }
                if let course = nearest {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(course.name)
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                        Text("\(course.city) · \(course.roundHoleCount) holes · Par \(course.roundTotalPar)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    NavigationLink {
                        RoundSetupView(course: course)
                    } label: {
                        HStack {
                            Text("Play round")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("Find somewhere\nto play.")
                        .font(.system(.title, design: .rounded, weight: .heavy))
                    Text("Search community-mapped courses near you.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                    Button {
                        selection = .play
                    } label: {
                        HStack {
                            Text("Explore courses")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .frame(height: 318)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.35)))
        .shadow(color: OverParTheme.Shadow.large.color, radius: OverParTheme.Shadow.large.radius, y: OverParTheme.Shadow.large.y)
    }

    private func summaryCard(value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .foregroundStyle(OverParTheme.forest)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(OverParTheme.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .padding(14)
        .background(OverParTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(OverParTheme.line))
    }

    private func quickCard(_ title: String, _ subtitle: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(OverParTheme.surface.opacity(0.72), in: Circle())
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(OverParTheme.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
            .padding(16)
            .background(OverParTheme.secondarySurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(OverParTheme.line.opacity(0.7)))
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
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                CourseArtwork()
                    .frame(height: 192)
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.62)], startPoint: .center, endPoint: .bottom)
                HStack {
                    StatusPill(
                        text: course.isVerified ? "Verified" : "Community",
                        symbol: course.isVerified ? "checkmark.seal.fill" : "person.3.fill",
                        tone: .white
                    )
                    .background(.black.opacity(0.18), in: Capsule())
                    Spacer()
                    Image(systemName: course.isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(14)
                VStack(alignment: .leading, spacing: 3) {
                    Spacer()
                    Text(course.name)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                    Text(course.facilityName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
            .frame(height: 192)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    Label(course.repeatsLayout ? "\(course.holeCount) holes ×\(course.loopCount)" : "\(course.holeCount) holes", systemImage: "figure.golf")
                    Label("Par \(course.roundTotalPar)", systemImage: "flag.fill")
                    Spacer()
                    Text(course.city)
                        .lineLimit(1)
                }
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(OverParTheme.secondary)
                HStack(spacing: 10) {
                    NavigationLink("Preview") { CoursePreviewView(course: course) }
                        .buttonStyle(SecondaryButtonStyle())
                    NavigationLink("Play") { RoundSetupView(course: course) }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(16)
        }
        .background(OverParTheme.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(OverParTheme.line.opacity(0.7), lineWidth: 0.75))
        .shadow(color: OverParTheme.Shadow.medium.color, radius: OverParTheme.Shadow.medium.radius, y: OverParTheme.Shadow.medium.y)
    }
}
