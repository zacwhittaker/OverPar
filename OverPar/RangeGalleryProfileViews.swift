import SwiftUI
import UIKit

struct DrivingRangeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedClubID: UUID?
    @State private var distance = ""
    @State private var isMishit = false
    @State private var showBag = false

    private var selectedClub: GolfClub? {
        store.clubs.first(where: { $0.id == (selectedClubID ?? store.activeBag.first?.id) })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SectionHeading(eyebrow: "Calibrate your game", title: "Driving Range")
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your locker")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text("Choose a club to record its carry.")
                            .font(.subheadline)
                            .foregroundStyle(OverParTheme.secondary)
                    }
                    Spacer()
                    Button { showBag = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .background(.white, in: Circle())
                            .overlay(Circle().stroke(OverParTheme.line))
                    }
                }
                if store.activeBag.isEmpty {
                    OverParCard {
                        ContentUnavailableView(
                            "Your locker is empty",
                            systemImage: "cabinet.fill",
                            description: Text("Add the clubs you carry to begin recording distances.")
                        )
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(store.activeBag) { club in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    selectedClubID = club.id
                                }
                            } label: {
                                lockerClub(club)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if let club = selectedClub {
                    statsCard(club)
                    OverParCard {
                        VStack(spacing: 14) {
                            Text("Record carry")
                                .font(.headline)
                            TextField("Carry distance", text: $distance)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                            Text(store.profile.units == "yards" ? "yards" : "metres")
                                .foregroundStyle(OverParTheme.secondary)
                            Toggle("Mark as mishit", isOn: $isMishit)
                            Button("Add hit") {
                                if let value = Double(distance) {
                                    store.addRangeHit(clubID: club.id, displayedDistance: value, kind: .carry, mishit: isMishit)
                                    distance = ""
                                    isMishit = false
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(Double(distance) == nil)
                        }
                    }
                    recentHits(club)
                }
            }
            .padding(20)
        }
        .navigationTitle("Driving Range")
        .sheet(isPresented: $showBag) { BagManagerView() }
        .onAppear { selectedClubID = selectedClubID ?? store.activeBag.first?.id }
        .overParPage()
    }

    private func lockerClub(_ club: GolfClub) -> some View {
        let selected = selectedClub?.id == club.id
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                GolfClubIcon(club: club, size: 52, selected: selected)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(club.displayName)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .lineLimit(1)
                if club.showsNickname {
                    Text(club.name)
                        .font(.caption)
                        .foregroundStyle(selected ? .white.opacity(0.76) : OverParTheme.secondary)
                        .lineLimit(1)
                }
            }
            let insight = store.carryInsight(for: club)
            if insight.isPossibleAnomaly, let estimate = insight.estimatedMetres {
                Label("Check gap · Est. \(displayDistance(estimate)) \(unitLabel)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(selected ? .yellow : .orange)
            } else if let stats = store.stats(for: club) {
                Text("\(Int(stats.average.rounded())) \(store.profile.units == "yards" ? "yd" : "m") average carry")
                    .font(.caption)
                    .foregroundStyle(selected ? .white.opacity(0.82) : OverParTheme.secondary)
            } else if let estimate = insight.estimatedMetres {
                Text("Est. \(displayDistance(estimate)) \(unitLabel) carry")
                    .font(.caption)
                    .foregroundStyle(selected ? .white.opacity(0.82) : OverParTheme.secondary)
            } else {
                Text("No carries recorded")
                    .font(.caption)
                    .foregroundStyle(selected ? .white.opacity(0.82) : OverParTheme.secondary)
            }
        }
        .foregroundStyle(selected ? .white : OverParTheme.ink)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .padding(16)
        .background(selected ? OverParTheme.forest : .white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(selected ? OverParTheme.forest : OverParTheme.line))
    }

    private func statsCard(_ club: GolfClub) -> some View {
        OverParCard {
            if let stats = store.stats(for: club, kind: .carry) {
                let insight = store.carryInsight(for: club)
                VStack(spacing: 10) {
                    clubTitle(club)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(stats.average.rounded()))")
                            .font(.system(size: 54, weight: .heavy, design: .rounded)).monospacedDigit()
                        Text(store.profile.units == "yards" ? "yd" : "m")
                    }
                    Text("Average carry")
                        .foregroundStyle(OverParTheme.secondary)
                    HStack {
                        metric("Playing carry", "\(Int(stats.playing.rounded()))")
                        metric("Typical", "\(Int(stats.low.rounded()))–\(Int(stats.high.rounded()))")
                        metric("Max carry", "\(Int(stats.maximum.rounded()))")
                    }
                    Text("\(stats.count) valid \(stats.count == 1 ? "shot" : "shots")")
                        .font(.caption)
                        .foregroundStyle(OverParTheme.secondary)
                    Text(stats.count >= 20 ? "Good confidence" : stats.count >= 8 ? "Building confidence" : "Low confidence")
                        .font(.caption.bold())
                        .foregroundStyle(OverParTheme.forest)
                    if insight.isPossibleAnomaly, let estimate = insight.estimatedMetres {
                        Divider()
                        Label("Possible gapping anomaly", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text("Your other clubs suggest roughly \(displayDistance(estimate)) \(unitLabel) carry for this club. Keep your recorded result, but check the club and record more full swings.")
                            .font(.caption)
                            .foregroundStyle(OverParTheme.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            } else if let estimate = store.carryInsight(for: club).estimatedMetres {
                VStack(spacing: 10) {
                    clubTitle(club)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(displayDistance(estimate))")
                            .font(.system(size: 54, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                        Text(unitLabel)
                    }
                    Text("Estimated carry")
                        .foregroundStyle(OverParTheme.secondary)
                    StatusPill(text: "Low confidence · not a recorded shot", symbol: "wand.and.stars")
                    Text("Estimated from the power shown by your calibrated clubs. Your first real carries will replace this estimate.")
                        .font(.caption)
                        .foregroundStyle(OverParTheme.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView("No carry shots yet", systemImage: "scope", description: Text("Record your first full swing. OverPar will only show distances you enter."))
            }
        }
    }

    private var unitLabel: String {
        store.profile.units == "yards" ? "yd" : "m"
    }

    private func displayDistance(_ metres: Double) -> Int {
        Int((store.profile.units == "yards" ? metres * 1.09361 : metres).rounded())
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.headline).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(OverParTheme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func clubTitle(_ club: GolfClub) -> some View {
        VStack(spacing: 2) {
            Text(club.displayName).font(.headline)
            if club.showsNickname {
                Text(club.name).font(.caption).foregroundStyle(OverParTheme.secondary)
            }
        }
    }

    private func recentHits(_ club: GolfClub) -> some View {
        let hits = store.rangeHits.filter { $0.clubID == club.id && $0.kind == .carry }.suffix(8).reversed()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Recent hits").font(.headline)
            ForEach(Array(hits)) { hit in
                HStack {
                    Text("\(Int((store.profile.units == "yards" ? hit.metres * 1.09361 : hit.metres).rounded()))")
                        .font(.headline).monospacedDigit()
                    Text(store.profile.units == "yards" ? "yd" : "m")
                    Spacer()
                    if hit.isMishit { StatusPill(text: "Mishit", symbol: "arrow.turn.down.right") }
                }
                .padding(.vertical, 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BagManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newNickname = ""
    @State private var category: ClubCategory = .iron
    @State private var pendingDeletion: IndexSet?
    @State private var editingClubID: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($store.clubs) { $club in
                        HStack(spacing: 12) {
                            GolfClubIcon(club: club, size: 48)
                            Button {
                                editingClubID = club.id
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(club.displayName)
                                        .font(.headline)
                                        .foregroundStyle(OverParTheme.ink)
                                    if club.showsNickname {
                                        Text(club.name)
                                            .font(.caption)
                                            .foregroundStyle(OverParTheme.secondary)
                                    } else {
                                        Text("Add nickname")
                                            .font(.caption)
                                            .foregroundStyle(OverParTheme.forest)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Toggle("", isOn: Binding(
                                get: { club.isActive },
                                set: { value in
                                    if value && store.activeBag.count >= 14 { return }
                                    club.isActive = value
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                    .onMove { store.moveClubs(from: $0, to: $1) }
                    .onDelete { pendingDeletion = $0 }
                } header: {
                    Text("Active bag · \(store.activeBag.count) of 14")
                } footer: {
                    Text("Drag to reorder. Swipe left to permanently delete a club and its recorded range shots.")
                }
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(ClubCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Club label", text: $newName)
                    TextField("Nickname (optional)", text: $newNickname)
                    Button("Add club") {
                        let label = newName.isEmpty ? category.rawValue : newName
                        store.clubs.append(GolfClub(
                            category: category,
                            name: label,
                            nickname: newNickname.trimmingCharacters(in: .whitespacesAndNewlines),
                            isActive: store.activeBag.count < 14
                        ))
                        newName = ""
                        newNickname = ""
                    }
                } header: {
                    Text("Add club")
                } footer: {
                    Text("Inventory can exceed 14. Only 14 clubs may be active for a round; duplicate club types are allowed.")
                }
            }
            .overParFormPage()
            .navigationTitle("Your bag")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog(
                "Delete this club?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete club and its range shots", role: .destructive) {
                    if let pendingDeletion {
                        store.deleteClubs(at: pendingDeletion)
                    }
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeletion = nil
                }
            } message: {
                Text("This permanently removes the club and every Driving Range hit recorded for it.")
            }
            .sheet(item: Binding(
                get: { store.clubs.first(where: { $0.id == editingClubID }) },
                set: { if $0 == nil { editingClubID = nil } }
            )) { club in
                ClubEditorView(clubID: club.id)
            }
        }
    }
}

private struct ClubEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let clubID: UUID
    @State private var name = ""
    @State private var nickname = ""
    @State private var loft = ""

    private var club: GolfClub? {
        store.clubs.first(where: { $0.id == clubID })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if let club {
                        GolfClubIcon(club: previewClub(from: club), size: 112)
                        VStack(spacing: 5) {
                            Text(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? name : nickname)
                                .font(.system(.title, design: .rounded, weight: .heavy))
                            if !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(name).foregroundStyle(OverParTheme.secondary)
                            }
                        }
                    }
                    OverParCard {
                        VStack(alignment: .leading, spacing: 16) {
                            field("Club name", text: $name)
                            field("Nickname", text: $nickname)
                            field("Loft in degrees (optional)", text: $loft, keyboard: .decimalPad)
                            Text("The nickname appears first in your locker. The real club name always stays underneath it.")
                                .font(.caption)
                                .foregroundStyle(OverParTheme.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Edit club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let index = store.clubs.firstIndex(where: { $0.id == clubID }) else { return }
                        store.clubs[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.clubs[index].nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.clubs[index].loft = Double(loft)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard let club else { return }
                name = club.name
                nickname = club.nickname
                loft = club.loft.map { String(format: "%g", $0) } ?? ""
            }
            .overParPage()
        }
    }

    private func previewClub(from club: GolfClub) -> GolfClub {
        var preview = club
        preview.name = name.isEmpty ? club.name : name
        preview.nickname = nickname
        return preview
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.bold()).foregroundStyle(OverParTheme.secondary)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .padding(14)
                .background(OverParTheme.canvas, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(OverParTheme.line))
        }
    }
}

struct GalleryView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                SectionHeading(eyebrow: "Private by default", title: "Gallery")
                if store.gallery.isEmpty {
                    ContentUnavailableView(
                        "Record your first shot",
                        systemImage: "video.badge.plus",
                        description: Text("Use Record Shot during a round. Original video is kept even if tracing needs correction.")
                    )
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(store.gallery) { item in
                            NavigationLink {
                                GalleryDetailView(item: item)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 18).fill(OverParTheme.forestDark.gradient)
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 42)).foregroundStyle(.white)
                                    }
                                    .aspectRatio(0.85, contentMode: .fit)
                                    Text(item.title).font(.headline)
                                    Text([item.courseName, item.holeNumber.map { "Hole \($0)" }].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(OverParTheme.secondary)
                                    StatusPill(text: item.tracerStatus, symbol: "scribble.variable")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Gallery")
        .overParPage()
    }
}

struct GalleryDetailView: View {
    let item: GalleryItem
    @State private var traceColour = Color.yellow

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(Color.black.gradient)
                    Path { path in
                        path.move(to: CGPoint(x: 65, y: 440))
                        path.addCurve(to: CGPoint(x: 290, y: 75), control1: CGPoint(x: 115, y: 170), control2: CGPoint(x: 230, y: 90))
                    }
                    .stroke(traceColour, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    Text("Editable visualised path")
                        .font(.caption.bold()).foregroundStyle(.white)
                        .padding(8).background(.black.opacity(0.6), in: Capsule())
                        .offset(y: 215)
                }
                .frame(height: 520)
                .padding(.horizontal)
                OverParCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.title).font(.title2.bold())
                        Label(item.isPrivate ? "Only you" : "Shared", systemImage: "lock.fill")
                        Text("Observed, interpolated and manually adjusted path segments remain editable metadata. The original video is unchanged.")
                            .font(.caption).foregroundStyle(OverParTheme.secondary)
                        ColorPicker("Trace colour", selection: $traceColour)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Shot")
        .overParPage()
    }
}

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape.fill") }
                }
                Circle()
                    .fill(OverParTheme.forest.gradient)
                    .frame(width: 104, height: 104)
                    .overlay(Text(initials).font(.largeTitle.bold()).foregroundStyle(.white))
                VStack(spacing: 4) {
                    Text(store.profile.displayName)
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    Text("@\(store.profile.username)").foregroundStyle(OverParTheme.secondary)
                    Text(store.profile.biography).multilineTextAlignment(.center).padding(.top, 6)
                    Label(store.profile.broadLocation, systemImage: "mappin")
                        .font(.subheadline).foregroundStyle(OverParTheme.secondary)
                }
                NavigationLink("Edit profile") { EditProfileView() }
                    .buttonStyle(.borderedProminent)
                if let homeID = store.profile.homeCourseID,
                   let home = store.courses.first(where: { $0.id == homeID }) {
                    SectionHeading(eyebrow: "Pinned home", title: "Home course")
                    CourseHeroCard(course: home)
                }
                SectionHeading(eyebrow: "Private by default", title: "Club distances")
                OverParCard {
                    VStack(spacing: 14) {
                        ForEach(store.activeBag.filter { store.stats(for: $0) != nil }) { club in
                            if let stats = store.stats(for: club) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(club.displayName).font(.headline)
                                        if club.showsNickname {
                                            Text(club.name).font(.caption).foregroundStyle(OverParTheme.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("\(Int(stats.playing.rounded())) \(store.profile.units == "yards" ? "yd" : "m")")
                                        .font(.headline).monospacedDigit()
                                    Text("\(stats.count) hits").font(.caption).foregroundStyle(OverParTheme.secondary)
                                }
                            }
                        }
                    }
                }
                SectionHeading(eyebrow: "Community", title: "Contributions")
                OverParCard {
                    Label("Add or improve a course", systemImage: "map.badge.plus")
                        .font(.headline)
                }
            }
            .padding(20)
        }
        .navigationTitle("Profile")
        .overParPage()
    }

    private var initials: String {
        store.profile.displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Form {
            TextField("Display name", text: $store.profile.displayName)
            TextField("Username", text: $store.profile.username)
                .textInputAutocapitalization(.never)
            TextField("Biography", text: $store.profile.biography, axis: .vertical)
            TextField("Broad location", text: $store.profile.broadLocation)
            Section {
                Text("Exact live location is never part of the public profile.")
                    .font(.caption).foregroundStyle(OverParTheme.secondary)
            }
        }
        .overParFormPage()
        .navigationTitle("Edit profile")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var location: LocationService
    @AppStorage("overpar.reduceMotion") private var reduceMotion = false
    @AppStorage("overpar.haptics") private var haptics = true

    var body: some View {
        List {
            Section("Account") {
                NavigationLink("Name, username & avatar") { EditProfileView() }
                LabeledContent("Sign-in methods", value: "Local until Supabase is configured")
                Label("Export your data", systemImage: "square.and.arrow.up")
            }
            Section("Golf preferences") {
                Picker("Units", selection: $store.profile.units) {
                    Text("Yards").tag("yards")
                    Text("Metres").tag("metres")
                }
                Toggle("Right-handed", isOn: $store.profile.isRightHanded)
                Toggle("Golf assistant by default", isOn: $store.profile.assistantEnabled)
                NavigationLink("Active bag") { BagManagerView() }
            }
            Section("Location & maps") {
                LabeledContent("Location access", value: permissionText)
                Button("Open system settings") { openSystemSettings() }
                LabeledContent("Hole logging maps", value: GoogleMapsConfiguration.isConfigured ? "Google satellite" : "Apple satellite fallback")
                Text(GoogleMapsConfiguration.isConfigured
                     ? "Google satellite imagery is active. OverPar stores only course coordinates and never copies imagery."
                     : "Add the restricted Google Maps iOS key to activate Google satellite imagery.")
                    .font(.caption).foregroundStyle(OverParTheme.secondary)
            }
            Section("Camera & Gallery") {
                LabeledContent("Recorded videos", value: "\(store.gallery.count)")
                LabeledContent("Tracer processing", value: "On-device / manual first")
                Text("Original video remains private. Cloud refinement is off until separately consented and configured.")
                    .font(.caption).foregroundStyle(OverParTheme.secondary)
            }
            Section("Privacy & community") {
                LabeledContent("Profile visibility", value: "OverPar community")
                LabeledContent("Club-distance visibility", value: "Only me")
                LabeledContent("Blocked accounts", value: "None")
            }
            Section("Appearance & accessibility") {
                Toggle("Reduce motion", isOn: $reduceMotion)
                Toggle("Haptics", isOn: $haptics)
            }
            Section("Help & legal") {
                NavigationLink("GPS & recommendation limits") {
                    Text("GPS measures the device position with reported uncertainty. Device-to-target distance is not airborne carry or a curved ball path. Club suggestions are estimates.")
                        .padding().navigationTitle("GPS limits")
                }
                NavigationLink("Rules disclaimer") {
                    Text("Check the Rules of Golf, the committee and local rules. Rules-compliant mode hides assistance that may be restricted.")
                        .padding().navigationTitle("Rules")
                }
                LabeledContent("Privacy policy", value: "Required before App Store submission")
                LabeledContent("Terms & map attribution", value: "Required before App Store submission")
            }
            Section {
                VStack(spacing: 8) {
                    Label("OverPar", systemImage: "figure.golf")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(OverParTheme.forest)
                    Text("Build version 1.0.0 · Release 1.0")
                    Text("Developed by Zac Whittaker")
                        .font(.headline)
                    Text("Made with care in Leeds.")
                        .font(.caption).foregroundStyle(OverParTheme.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .overParFormPage()
        .navigationTitle("Settings")
    }

    private var permissionText: String {
        switch location.authorization {
        case .authorizedAlways, .authorizedWhenInUse: "While using the app"
        case .denied, .restricted: "Denied"
        case .notDetermined: "Not requested"
        @unknown default: "Unknown"
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
