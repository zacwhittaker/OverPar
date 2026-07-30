import AVFoundation
import CoreLocation
@preconcurrency import GoogleMaps
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct RoundSetupView: View {
    @EnvironmentObject private var store: AppStore
    let course: GolfCourse
    @State private var format: RoundFormat = .strokePlay
    @State private var rulesCompliant = false
    @State private var hasStarted = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nearly tee time")
                        .font(.caption.bold())
                        .foregroundStyle(OverParTheme.forest)
                    Text("Set up your round.")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    Text("\(course.name) · \(course.roundHoleCount) holes · Par \(course.roundTotalPar)")
                        .foregroundStyle(OverParTheme.secondary)
                }
                .padding(.vertical, 8)
            }
            Section("Round type") {
                Picker("Format", selection: $format) {
                    ForEach(RoundFormat.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            Section("Golf assistant") {
                Toggle("Rules-compliant mode", isOn: $rulesCompliant)
                Text(rulesCompliant
                     ? "Raw permitted distances remain. Plays-like and club recommendations are hidden."
                     : "Personal club suggestions are available and remain estimates.")
                    .font(.caption)
                    .foregroundStyle(OverParTheme.secondary)
            }
            Section {
                Label("The course and round save locally first and can resume after interruption.", systemImage: "checkmark.icloud.fill")
                    .foregroundStyle(OverParTheme.forest)
                Button("Start round") {
                    store.startRound(course: course, format: format, rulesCompliant: rulesCompliant)
                    hasStarted = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .listRowInsets(EdgeInsets())
            }
        }
        .overParFormPage()
        .navigationTitle("Round setup")
        .navigationDestination(isPresented: $hasStarted) { ActiveRoundView() }
    }
}

struct ActiveRoundView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var location: LocationService
    @State private var pendingShot: LoggedShot?
    @State private var showResult = false
    @State private var showCamera = false
    @State private var showFinishRound = false
    @State private var mapMode: RoundMapMode = .none
    @State private var completedRoundOverview: CompletedRound?
    @State private var showClubDistances = false
    @State private var showShotClubPicker = false

    private var round: ActiveRound? { store.activeRound }
    private var course: GolfCourse? {
        guard let round else { return nil }
        return store.courses.first(where: { $0.id == round.courseID })
    }
    private var hole: Hole? {
        guard let round, let course else { return nil }
        return course.hole(forRoundHole: round.holeNumber)
    }
    private var distance: CLLocationDistance? {
        guard let origin = targetLineOrigin, let target = hole?.greenReference else { return nil }
        return CLLocation(
            latitude: origin.latitude,
            longitude: origin.longitude
        ).distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
    }
    private var playerCoordinate: Coordinate? {
        if let manual = round?.manualPlayerLocation { return manual }
        return location.location.map {
            Coordinate(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude,
                horizontalAccuracy: $0.horizontalAccuracy,
                capturedAt: $0.timestamp
            )
        }
    }
    private var targetLineOrigin: Coordinate? {
        guard let round else { return hole?.tee }
        if let manual = round.manualPlayerLocation {
            return manual
        }
        let hasCompletedOpeningShot = !(round.shots[round.holeNumber] ?? []).isEmpty
        return hasCompletedOpeningShot ? (playerCoordinate ?? hole?.tee) : hole?.tee
    }

    var body: some View {
        ZStack {
            if let round, let course, let hole {
                RoundSatelliteMap(
                    hole: hole,
                    roundHoleNumber: round.holeNumber,
                    player: playerCoordinate,
                    targetLineOrigin: targetLineOrigin,
                    isManualPlayer: round.manualPlayerLocation != nil,
                    pendingShot: pendingShot,
                    acceptsTap: mapMode != .none,
                    onTap: handleMapTap
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    roundHeader(round: round, course: course, hole: hole)
                    if mapMode != .none {
                        mapInstruction
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        mapTools(round: round)
                    }
                    companionPanel(distance: distance, round: round)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            } else {
                ContentUnavailableView("No active round", systemImage: "flag.slash")
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: mapMode)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { location.startRoundUpdates() }
        .task(id: round?.courseID) {
            if let coordinate = course?.referenceCoordinate {
                await store.refreshPlayingConditions(at: coordinate)
            }
        }
        .sheet(isPresented: $showResult, onDismiss: {
            pendingShot = nil
        }) {
            if let pendingShot { ShotResultSheet(shot: pendingShot) }
        }
        .sheet(isPresented: $showClubDistances) {
            ClubDistancesSheet()
        }
        .sheet(isPresented: $showShotClubPicker, onDismiss: {
            if pendingShot?.clubID == nil {
                pendingShot = nil
            }
        }) {
            ShotClubPickerSheet(selectedClubID: pendingShot?.clubID) { clubID in
                pendingShot?.clubID = clubID
                showShotClubPicker = false
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ShotCameraView()
        }
        .confirmationDialog(
            "End this round?",
            isPresented: $showFinishRound,
            titleVisibility: .visible
        ) {
            Button("Save & end round") {
                location.stopRoundUpdates()
                completedRoundOverview = store.endRound(save: true)
            }
            Button("End without saving", role: .destructive) {
                location.stopRoundUpdates()
                store.endRound(save: false)
                dismiss()
            }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("Save the round to view its overview, or discard it permanently.")
        }
        .fullScreenCover(item: $completedRoundOverview, onDismiss: {
            dismiss()
        }) { completed in
            RoundOverviewView(round: completed)
        }
        .overParPage()
    }

    private func roundHeader(round: ActiveRound, course: GolfCourse, hole: Hole) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(OverParTheme.secondary)
                Text("Hole \(round.holeNumber) · Par \(hole.par)")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
            }
            Spacer()
            if round.manualPlayerLocation != nil {
                Label("Manual position", systemImage: "hand.tap.fill")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.white, in: Capsule())
            } else {
                StatusPill(
                    text: location.location.map { "GPS ±\(Int($0.horizontalAccuracy)) m" } ?? "GPS settling",
                    symbol: "location.fill"
                )
            }
            Menu {
                Button("Set my position on map") { mapMode = .player }
                Button(pendingShot == nil ? "Drop shot start pin" : "Drop shot finish pin") {
                    mapMode = .shot
                }
                if round.manualPlayerLocation != nil {
                    Button("Return to live GPS") {
                        mutateRound { $0.manualPlayerLocation = nil }
                    }
                }
                Divider()
                Button("End round", role: .destructive) { showFinishRound = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OverParTheme.forestDark)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.45), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Round menu")
        }
        .padding(14)
        .background(
            reduceTransparency ? AnyShapeStyle(Color.white) : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: 21, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Color.white.opacity(reduceTransparency ? 0 : 0.16))
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private var mapInstruction: some View {
        HStack(spacing: 10) {
            Image(systemName: mapMode == .player ? "location.fill.viewfinder" : "mappin.and.ellipse")
                .font(.headline)
            Text(mapMode == .player
                 ? "Tap the map where you want to stand"
                 : pendingShot == nil ? "Tap where this shot started" : "Tap where the ball finished")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
            Spacer()
            Button("Cancel") { mapMode = .none }
                .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(OverParTheme.forest, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 9, y: 4)
    }

    private func mapTools(round: ActiveRound) -> some View {
        VStack(spacing: 9) {
            mapTool(
                title: round.manualPlayerLocation == nil ? "Set position" : "Move position",
                symbol: "location.fill.viewfinder",
                active: mapMode == .player
            ) {
                mapMode = mapMode == .player ? .none : .player
            }
            mapTool(
                title: pendingShot == nil ? "Pin shot" : "Pin finish",
                symbol: "mappin.and.ellipse",
                active: mapMode == .shot
            ) {
                mapMode = mapMode == .shot ? .none : .shot
            }
            if round.manualPlayerLocation != nil {
                mapTool(title: "Use GPS", symbol: "location.fill", active: false) {
                    mutateRound { $0.manualPlayerLocation = nil }
                }
            }
        }
    }

    private func mapTool(
        title: String,
        symbol: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .bold))
            }
            .foregroundStyle(active ? .white : OverParTheme.forestDark)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(
                active
                    ? AnyShapeStyle(OverParTheme.forest.opacity(0.94))
                    : reduceTransparency
                        ? AnyShapeStyle(Color.white)
                        : AnyShapeStyle(.ultraThinMaterial),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .fill(Color.white.opacity(active || reduceTransparency ? 0 : 0.14))
                    .allowsHitTesting(false)
            }
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.72), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.14), radius: 7, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func conditionBadge(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(OverParTheme.forest)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(OverParTheme.mint.opacity(0.9), in: Capsule())
    }

    private func companionPanel(distance: Double?, round: ActiveRound) -> some View {
        let recommendation = distance.flatMap {
            store.recommendedClub(
                distanceMetres: $0,
                hole: hole,
                player: targetLineOrigin
            )
        }

        return VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TO GREEN")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(OverParTheme.forest)
                    if let distance {
                        let shown = store.profile.units == "yards" ? distance * 1.09361 : distance
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(shown.rounded()))")
                                .font(.system(size: 48, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                            Text(store.profile.units == "yards" ? "yd" : "m")
                                .font(.headline)
                        }
                        if !round.rulesCompliant, let recommendation {
                            let factor = store.profile.units == "yards" ? 1.09361 : 1
                            let unit = store.profile.units == "yards" ? "yd" : "m"
                            let carry = recommendation.carryMetres * factor
                            let total = (recommendation.carryMetres + recommendation.estimatedRollMetres) * factor
                            VStack(alignment: .leading, spacing: 1) {
                                Text("EXPECTED WITH \(recommendation.club.displayName.uppercased())")
                                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                                    .tracking(0.7)
                                    .foregroundStyle(OverParTheme.secondary)
                                Text(
                                    "\(Int(carry.rounded())) \(unit) carry"
                                    + (recommendation.estimatedRollMetres > 0.5
                                       ? "  •  ~\(Int(total.rounded())) \(unit) total"
                                       : "")
                                )
                                .font(.system(.caption, design: .rounded, weight: .heavy))
                                .foregroundStyle(OverParTheme.forest)
                            }
                            .padding(.top, 3)
                        }
                    } else {
                        Text("Set position")
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                    }
                }
                Spacer()
                if round.rulesCompliant {
                    Label("Raw distance", systemImage: "shield.checkered")
                        .font(.caption.bold())
                        .foregroundStyle(OverParTheme.secondary)
                } else if let recommendation {
                    Button {
                        showClubDistances = true
                    } label: {
                        HStack(spacing: 9) {
                        GolfClubIcon(club: recommendation.club, size: 46)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("PLAY")
                                .font(.caption2.bold())
                                .foregroundStyle(OverParTheme.secondary)
                            Text(recommendation.club.displayName)
                                .font(.system(.headline, design: .rounded, weight: .heavy))
                            if recommendation.club.showsNickname {
                                Text(recommendation.club.name)
                                    .font(.caption2)
                                    .foregroundStyle(OverParTheme.secondary)
                            }
                            Text(recommendation.isEstimated ? "Estimated club" : "From your carry")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(OverParTheme.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(OverParTheme.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View all club distances")
                }
            }
            if !round.rulesCompliant,
               let summary = recommendation?.conditionsSummary {
                HStack(spacing: 6) {
                    ForEach(summary.components(separatedBy: " · "), id: \.self) {
                        conditionBadge($0)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                Button {
                    logOrFinishShot()
                } label: {
                    Label(
                        pendingShot == nil ? "Log shot" : "Finish shot",
                        systemImage: pendingShot == nil ? "location.north.fill" : "checkmark.circle.fill"
                    )
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(OverParTheme.forestDark)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.white.opacity(0.34), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .disabled(playerCoordinate == nil)
                Button {
                    showCamera = true
                } label: {
                    Label("Record", systemImage: "video.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(OverParTheme.forest.opacity(0.94), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
            scoreControls(round: round)
        }
        .padding(16)
        .background(
            reduceTransparency ? AnyShapeStyle(Color.white) : AnyShapeStyle(.regularMaterial),
            in: RoundedRectangle(cornerRadius: 25, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(Color.white.opacity(reduceTransparency ? 0 : 0.24))
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.2), radius: 16, y: 7)
    }

    private func scoreControls(round: ActiveRound) -> some View {
        HStack(spacing: 10) {
            Button {
                mutateRound { value in
                    value.scores[value.holeNumber] = max(0, (value.scores[value.holeNumber] ?? 0) - 1)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.38), in: Circle())
            }
            .buttonStyle(.plain)
            Text("Score \(round.scores[round.holeNumber] ?? 0)")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .monospacedDigit()
            Button {
                mutateRound { $0.scores[$0.holeNumber, default: 0] += 1 }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.38), in: Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                showFinishRound = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.9), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End round")
            Button {
                mutateRound { value in
                    if let course, value.holeNumber < course.roundHoleCount {
                        value.holeNumber += 1
                        value.manualPlayerLocation = nil
                        pendingShot = nil
                    } else {
                        showFinishRound = true
                    }
                }
            } label: {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 44)
                    .background(OverParTheme.forest.opacity(0.94), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                round.holeNumber < (course?.roundHoleCount ?? 0) ? "Complete hole" : "Finish round"
            )
        }
    }

    private func logOrFinishShot() {
        if pendingShot == nil {
            pendingShot = LoggedShot(start: targetLineOrigin)
            showShotClubPicker = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            pendingShot?.end = playerCoordinate
            showResult = true
        }
    }

    private func handleMapTap(_ coordinate: Coordinate) {
        switch mapMode {
        case .none:
            break
        case .player:
            mutateRound { $0.manualPlayerLocation = coordinate }
            mapMode = .none
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .shot:
            if pendingShot == nil {
                pendingShot = LoggedShot(start: coordinate)
                showShotClubPicker = true
                mapMode = .none
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                pendingShot?.end = coordinate
                mapMode = .none
                showResult = true
            }
        }
    }

    private func mutateRound(_ mutation: (inout ActiveRound) -> Void) {
        guard var value = store.activeRound else { return }
        mutation(&value)
        store.activeRound = value
    }
}

private struct RoundOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    let round: CompletedRound

    private var playedHoles: [(number: Int, score: Int)] {
        round.scores
            .filter { $0.value > 0 }
            .map { (number: $0.key, score: $0.value) }
            .sorted { $0.number < $1.number }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(OverParTheme.mint)
                                .frame(width: 82, height: 82)
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(OverParTheme.forest)
                        }
                        Text("Round saved")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        Text(round.courseName)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(OverParTheme.secondary)
                        Text(round.endedAt, format: .dateTime.day().month().year().hour().minute())
                            .font(.caption)
                            .foregroundStyle(OverParTheme.secondary)
                    }
                    .padding(.top, 14)

                    HStack(spacing: 12) {
                        overviewMetric(value: "\(round.totalScore)", label: "Total score", symbol: "number")
                        overviewMetric(value: "\(round.holesPlayed)", label: "Holes played", symbol: "flag.fill")
                        overviewMetric(value: "\(round.shotCount)", label: "Shots logged", symbol: "location.north.fill")
                    }

                    OverParCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Scorecard")
                                    .font(.system(.title3, design: .rounded, weight: .heavy))
                                Spacer()
                                Text(round.format.rawValue)
                                    .font(.caption.bold())
                                    .foregroundStyle(OverParTheme.forest)
                            }
                            if playedHoles.isEmpty {
                                Text("No hole scores were entered.")
                                    .foregroundStyle(OverParTheme.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 80)
                            } else {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 66), spacing: 10)],
                                    spacing: 10
                                ) {
                                    ForEach(playedHoles, id: \.number) { hole in
                                        VStack(spacing: 3) {
                                            Text("Hole \(hole.number)")
                                                .font(.caption2.bold())
                                                .foregroundStyle(OverParTheme.secondary)
                                            Text("\(hole.score)")
                                                .font(.system(.title3, design: .rounded, weight: .heavy))
                                                .monospacedDigit()
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 58)
                                        .background(OverParTheme.canvas, in: RoundedRectangle(cornerRadius: 14))
                                    }
                                }
                            }
                        }
                    }

                    Button("Done") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
            }
            .navigationTitle("Round overview")
            .navigationBarTitleDisplayMode(.inline)
            .overParPage()
        }
    }

    private func overviewMetric(value: String, label: String, symbol: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .foregroundStyle(OverParTheme.forest)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(OverParTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(OverParTheme.line))
    }
}

private struct ClubDistancesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(store.activeBag) { club in
                        clubCard(club)
                    }
                }
                .padding(18)
            }
            .overParPage()
            .navigationTitle("Your club distances")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func clubCard(_ club: GolfClub) -> some View {
        let carry = store.stats(for: club)
        let course = store.onCourseDistance(for: club)
        let insight = store.carryInsight(for: club)
        let estimated = insight.estimatedMetres.map {
            store.profile.units == "yards" ? $0 * 1.09361 : $0
        }
        let unit = store.profile.units == "yards" ? "yd" : "m"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                GolfClubIcon(club: club, size: 45)
                Spacer()
                if carry != nil {
                    Text("MEASURED")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundStyle(OverParTheme.forest)
                } else if course != nil || estimated != nil {
                    Text("EST.")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(club.displayName)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .lineLimit(1)
                if club.showsNickname {
                    Text(club.name)
                        .font(.caption2)
                        .foregroundStyle(OverParTheme.secondary)
                }
            }
            if let carry {
                distanceLine(value: carry.playing, unit: unit, label: "Playing carry")
            } else if let course {
                distanceLine(value: course.distance, unit: unit, label: "GPS playing distance")
            } else if let estimated {
                distanceLine(value: estimated, unit: unit, label: "Modelled carry")
            } else {
                Text("No distance yet")
                    .font(.subheadline.bold())
                    .foregroundStyle(OverParTheme.secondary)
                    .frame(minHeight: 29)
            }
            if let course {
                Text("\(course.count) on-course GPS \(course.count == 1 ? "shot" : "shots")")
                    .font(.caption2)
                    .foregroundStyle(OverParTheme.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(OverParTheme.line))
    }

    private func distanceLine(value: Double, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Int(value.rounded()))")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                Text(unit).font(.caption.bold())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(OverParTheme.secondary)
        }
    }
}

private struct ShotClubPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let selectedClubID: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.activeBag) { club in
                        Button {
                            onSelect(club.id)
                        } label: {
                            HStack(spacing: 13) {
                                GolfClubIcon(club: club, size: 48, selected: selectedClubID == club.id)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(club.displayName)
                                        .font(.system(.headline, design: .rounded, weight: .heavy))
                                    if club.showsNickname {
                                        Text(club.name)
                                            .font(.caption)
                                            .foregroundStyle(OverParTheme.secondary)
                                    }
                                }
                                Spacer()
                                if selectedClubID == club.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(OverParTheme.forest)
                                }
                            }
                            .foregroundStyle(OverParTheme.ink)
                            .padding(13)
                            .background(.white, in: RoundedRectangle(cornerRadius: 19))
                            .overlay(RoundedRectangle(cornerRadius: 19).stroke(OverParTheme.line))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
            .overParPage()
            .navigationTitle("Which club?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private enum RoundMapMode: Equatable {
    case none
    case player
    case shot
}

private struct RoundSatelliteMap: UIViewRepresentable {
    let hole: Hole
    let roundHoleNumber: Int
    let player: Coordinate?
    let targetLineOrigin: Coordinate?
    let isManualPlayer: Bool
    let pendingShot: LoggedShot?
    let acceptsTap: Bool
    let onTap: (Coordinate) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(roundHoleNumber: roundHoleNumber, onTap: onTap)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let focus = hole.tee ?? hole.greenReference ?? Coordinate(latitude: 53.8008, longitude: -1.5491)
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition.camera(
            withLatitude: focus.latitude,
            longitude: focus.longitude,
            zoom: 17
        )
        options.backgroundColor = UIColor(OverParTheme.forestDark)
        let map = GMSMapView(options: options)
        map.mapType = .satellite
        map.delegate = context.coordinator
        map.settings.compassButton = true
        map.settings.rotateGestures = false
        map.settings.tiltGestures = false
        map.isBuildingsEnabled = false
        map.padding = UIEdgeInsets(top: 142, left: 8, bottom: 292, right: 8)
        context.coordinator.render(
            hole: hole,
            player: player,
            targetLineOrigin: targetLineOrigin,
            isManualPlayer: isManualPlayer,
            pendingShot: pendingShot,
            on: map
        )
        context.coordinator.fit(hole: hole, player: player, on: map, animated: false)
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.acceptsTap = acceptsTap
        context.coordinator.render(
            hole: hole,
            player: player,
            targetLineOrigin: targetLineOrigin,
            isManualPlayer: isManualPlayer,
            pendingShot: pendingShot,
            on: map
        )
        if context.coordinator.roundHoleNumber != roundHoleNumber {
            context.coordinator.roundHoleNumber = roundHoleNumber
            context.coordinator.fit(hole: hole, player: player, on: map, animated: true)
        }
    }

    @MainActor
    final class Coordinator: NSObject, GMSMapViewDelegate {
        var roundHoleNumber: Int
        var onTap: (Coordinate) -> Void
        var acceptsTap = false
        private var overlays: [GMSOverlay] = []

        init(roundHoleNumber: Int, onTap: @escaping (Coordinate) -> Void) {
            self.roundHoleNumber = roundHoleNumber
            self.onTap = onTap
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            guard acceptsTap else { return }
            onTap(Coordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                capturedAt: Date()
            ))
        }

        func render(
            hole: Hole,
            player: Coordinate?,
            targetLineOrigin: Coordinate?,
            isManualPlayer: Bool,
            pendingShot: LoggedShot?,
            on map: GMSMapView
        ) {
            overlays.forEach { $0.map = nil }
            overlays.removeAll(keepingCapacity: true)

            if let tee = hole.tee {
                addMarker(
                    coordinate: tee.clLocationCoordinate,
                    title: "TEE",
                    symbol: "figure.golf",
                    colour: UIColor(OverParTheme.forest),
                    on: map
                )
            }
            if let green = hole.greenReference {
                addMarker(
                    coordinate: green.clLocationCoordinate,
                    title: "GREEN",
                    symbol: "flag.fill",
                    colour: .systemRed,
                    on: map
                )
            }
            if let player {
                addMarker(
                    coordinate: player.clLocationCoordinate,
                    title: isManualPlayer ? "YOU · MANUAL" : "YOU",
                    symbol: isManualPlayer ? "hand.tap.fill" : "location.fill",
                    colour: isManualPlayer ? .systemOrange : .systemBlue,
                    on: map,
                    prominent: true
                )
            }
            if let start = pendingShot?.start {
                addMarker(
                    coordinate: start.clLocationCoordinate,
                    title: "SHOT START",
                    symbol: "smallcircle.filled.circle",
                    colour: .systemYellow,
                    on: map
                )
            }
            if let end = pendingShot?.end {
                addMarker(
                    coordinate: end.clLocationCoordinate,
                    title: "SHOT FINISH",
                    symbol: "mappin",
                    colour: .systemPurple,
                    on: map
                )
            }
            // Once a golfer position exists, the target line must describe the
            // shot they are actually facing rather than the original tee shot.
            addLine(
                from: targetLineOrigin ?? hole.tee,
                to: hole.greenReference,
                colour: UIColor(OverParTheme.forest),
                on: map
            )
            addLine(from: pendingShot?.start, to: pendingShot?.end, colour: .systemYellow, on: map)
        }

        func fit(hole: Hole, player: Coordinate?, on map: GMSMapView, animated: Bool) {
            // Frame the hole itself. A remote device fix must not zoom the
            // opening camera out to include the golfer testing from elsewhere.
            let coordinates = [hole.tee, hole.greenReference].compactMap { $0 }
            guard let first = coordinates.first else { return }
            if coordinates.count == 1
                || CLLocation(
                    latitude: coordinates[0].latitude,
                    longitude: coordinates[0].longitude
                ).distance(from: CLLocation(
                    latitude: coordinates[1].latitude,
                    longitude: coordinates[1].longitude
                )) < 20 {
                let update = GMSCameraUpdate.setCamera(
                    GMSCameraPosition.camera(
                        withLatitude: first.latitude,
                        longitude: first.longitude,
                        zoom: 18.5
                    )
                )
                DispatchQueue.main.async {
                    if animated {
                        map.animate(with: update)
                    } else {
                        map.moveCamera(update)
                    }
                }
                return
            }
            let second = coordinates[1]
            let latitudeSpan = max(abs(first.latitude - second.latitude), 0.00035)
            let longitudeSpan = max(abs(first.longitude - second.longitude), 0.00035)
            let latitudeMargin = latitudeSpan * 0.18
            let longitudeMargin = longitudeSpan * 0.18
            let southWest = CLLocationCoordinate2D(
                latitude: min(first.latitude, second.latitude) - latitudeMargin,
                longitude: min(first.longitude, second.longitude) - longitudeMargin
            )
            let northEast = CLLocationCoordinate2D(
                latitude: max(first.latitude, second.latitude) + latitudeMargin,
                longitude: max(first.longitude, second.longitude) + longitudeMargin
            )
            let expandedBounds = GMSCoordinateBounds(
                coordinate: southWest,
                coordinate: northEast
            )
            let update = GMSCameraUpdate.fit(expandedBounds, withPadding: 18)
            DispatchQueue.main.async {
                if animated {
                    map.animate(with: update)
                } else {
                    map.moveCamera(update)
                }
            }
        }

        private func addLine(
            from: Coordinate?,
            to: Coordinate?,
            colour: UIColor,
            on map: GMSMapView
        ) {
            guard let from, let to else { return }
            let path = GMSMutablePath()
            path.add(from.clLocationCoordinate)
            path.add(to.clLocationCoordinate)
            let outline = GMSPolyline(path: path)
            outline.strokeColor = .white
            outline.strokeWidth = 6
            outline.map = map
            overlays.append(outline)
            let line = GMSPolyline(path: path)
            line.strokeColor = colour
            line.strokeWidth = 3
            line.map = map
            overlays.append(line)
        }

        private func addMarker(
            coordinate: CLLocationCoordinate2D,
            title: String,
            symbol: String,
            colour: UIColor,
            on map: GMSMapView,
            prominent: Bool = false
        ) {
            let marker = GMSMarker(position: coordinate)
            marker.iconView = RoundMapMarker(
                title: title,
                symbol: symbol,
                colour: colour,
                prominent: prominent
            )
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.58)
            marker.map = map
            overlays.append(marker)
        }
    }
}

private final class RoundMapMarker: UIView {
    init(title: String, symbol: String, colour: UIColor, prominent: Bool) {
        let diameter: CGFloat = prominent ? 46 : 38
        super.init(frame: CGRect(x: 0, y: 0, width: max(68, diameter + 18), height: diameter + 24))

        let circle = UIView(frame: CGRect(
            x: (bounds.width - diameter) / 2,
            y: 0,
            width: diameter,
            height: diameter
        ))
        circle.backgroundColor = colour
        circle.layer.cornerRadius = diameter / 2
        circle.layer.borderWidth = 3
        circle.layer.borderColor = UIColor.white.cgColor
        circle.layer.shadowColor = UIColor.black.cgColor
        circle.layer.shadowOpacity = 0.24
        circle.layer.shadowRadius = 4
        circle.layer.shadowOffset = CGSize(width: 0, height: 2)
        addSubview(circle)

        let image = UIImageView(image: UIImage(systemName: symbol))
        image.tintColor = .white
        image.contentMode = .scaleAspectFit
        image.frame = circle.bounds.insetBy(dx: diameter * 0.27, dy: diameter * 0.27)
        circle.addSubview(image)

        let label = UILabel(frame: CGRect(x: 0, y: diameter + 3, width: bounds.width, height: 18))
        label.text = title
        label.font = .systemFont(ofSize: 9, weight: .heavy)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.58)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct ShotResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State var shot: LoggedShot
    @State private var showProfessional = false
    @State private var showPenalty = false
    @State private var showClubPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("SHOT COMPLETE")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(OverParTheme.forest)
                        Text("How did it go?")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        Text("Two quick taps. Add the detailed golf terms only if you want them.")
                            .foregroundStyle(OverParTheme.secondary)
                    }

                    Button {
                        showClubPicker = true
                    } label: {
                        HStack(spacing: 13) {
                            if let club = selectedClub {
                                GolfClubIcon(club: club, size: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("CLUB USED")
                                        .font(.caption2.bold())
                                        .foregroundStyle(OverParTheme.forest)
                                    Text(club.displayName)
                                        .font(.system(.headline, design: .rounded, weight: .heavy))
                                    if let gpsDistance {
                                        Text("\(Int(gpsDistance.rounded())) \(distanceUnit) by GPS")
                                            .font(.caption)
                                            .foregroundStyle(OverParTheme.secondary)
                                    }
                                }
                            } else {
                                Image(systemName: "figure.golf")
                                    .frame(width: 48, height: 48)
                                    .background(OverParTheme.mint, in: RoundedRectangle(cornerRadius: 14))
                                Text("Select the club used")
                                    .font(.headline)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(OverParTheme.secondary)
                        }
                        .foregroundStyle(OverParTheme.ink)
                        .padding(14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(OverParTheme.line))
                    }
                    .buttonStyle(.plain)

                    resultCard(step: "1", title: "Where did it finish?", detail: "Compared with where you aimed") {
                        HStack(spacing: 10) {
                            directionChoice(.left, symbol: "arrow.up.left")
                            directionChoice(.onTarget, symbol: "scope")
                            directionChoice(.right, symbol: "arrow.up.right")
                        }
                    }

                    resultCard(step: "2", title: "What did it land in?", detail: "Choose the ball’s finishing lie") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            lieChoice(.fairway, symbol: "leaf.fill")
                            lieChoice(.rough, symbol: "camera.macro")
                            lieChoice(.bunker, symbol: "circle.dotted")
                            lieChoice(.fringe, symbol: "circle.dashed")
                            lieChoice(.green, symbol: "flag.fill")
                            lieChoice(.penaltyArea, symbol: "drop.fill")
                            lieChoice(.outOfBounds, symbol: "exclamationmark.triangle.fill")
                            lieChoice(.holed, symbol: "circle.circle.fill")
                        }
                    }

                    if shot.finishingLie == .outOfBounds {
                        penaltyCard
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    VStack(spacing: 0) {
                        Button {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                showProfessional.toggle()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "chart.xyaxis.line")
                                    .frame(width: 40, height: 40)
                                    .background(OverParTheme.mint, in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Add shot shape & strike")
                                        .font(.headline)
                                    Text("Optional golf detail")
                                        .font(.caption)
                                        .foregroundStyle(OverParTheme.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .rotationEffect(.degrees(showProfessional ? 180 : 0))
                            }
                            .foregroundStyle(OverParTheme.ink)
                            .padding(16)
                        }
                        .buttonStyle(.plain)

                        if showProfessional {
                            Divider().padding(.horizontal, 16)
                            VStack(alignment: .leading, spacing: 18) {
                                detailChoices(
                                    title: "Ball flight",
                                    values: BallFlight.allCases,
                                    selection: $shot.ballFlight
                                )
                                detailChoices(
                                    title: "Strike",
                                    values: StrikeQuality.allCases,
                                    selection: $shot.strike
                                )
                            }
                            .padding(16)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(OverParTheme.line))
                }
                .padding(20)
                .padding(.bottom, 82)
            }
            .overParPage()
            .navigationTitle("Log result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    save()
                } label: {
                    Label("Save shot", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.48)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .background(.ultraThinMaterial)
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: shot.finishingLie)
            .sheet(isPresented: $showPenalty) {
                PenaltySheet(selection: $shot.relief, rulesCompliant: store.activeRound?.rulesCompliant ?? false)
            }
            .sheet(isPresented: $showClubPicker) {
                ShotClubPickerSheet(selectedClubID: shot.clubID) { clubID in
                    shot.clubID = clubID
                    showClubPicker = false
                }
            }
        }
    }

    private var canSave: Bool {
        shot.clubID != nil &&
        shot.direction != nil &&
        shot.finishingLie != nil &&
        (shot.finishingLie != .outOfBounds || shot.relief != nil)
    }

    private var selectedClub: GolfClub? {
        guard let clubID = shot.clubID else { return nil }
        return store.clubs.first { $0.id == clubID }
    }

    private var gpsDistance: Double? {
        guard let start = shot.start, let end = shot.end else { return nil }
        let metres = CLLocation(
            latitude: start.latitude,
            longitude: start.longitude
        ).distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
        return store.profile.units == "yards" ? metres * 1.09361 : metres
    }

    private var distanceUnit: String {
        store.profile.units == "yards" ? "yd" : "m"
    }

    private var penaltyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Relief required", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("For a lost or out-of-bounds ball, choose how you continued before saving.")
                .font(.subheadline)
                .foregroundStyle(OverParTheme.secondary)
            Button {
                showPenalty = true
            } label: {
                HStack {
                    Text(shot.relief?.rawValue ?? "Choose relief procedure")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(14)
                .foregroundStyle(OverParTheme.ink)
                .background(.white, in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.orange.opacity(0.35)))
    }

    private func resultCard<Content: View>(
        step: String,
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Text(step)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(OverParTheme.forest, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.headline)
                    Text(detail).font(.caption).foregroundStyle(OverParTheme.secondary)
                }
            }
            content()
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(OverParTheme.line))
    }

    private func directionChoice(_ value: TargetDirection, symbol: String) -> some View {
        let selected = shot.direction == value
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                shot.direction = value
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title2.bold())
                Text(value.rawValue)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? .white : OverParTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 82)
            .background(selected ? OverParTheme.forest : OverParTheme.canvas, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(selected ? OverParTheme.forest : OverParTheme.line))
        }
        .buttonStyle(.plain)
    }

    private func lieChoice(_ value: FinishingLie, symbol: String) -> some View {
        let selected = shot.finishingLie == value
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                shot.finishingLie = value
                if value != .outOfBounds {
                    shot.relief = nil
                }
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.headline)
                    .frame(width: 30, height: 30)
                Text(shortLieName(value))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .lineLimit(2)
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark.circle.fill") }
            }
            .foregroundStyle(selected ? .white : OverParTheme.ink)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(selected ? OverParTheme.forest : OverParTheme.canvas, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? OverParTheme.forest : OverParTheme.line))
        }
        .buttonStyle(.plain)
    }

    private func shortLieName(_ value: FinishingLie) -> String {
        value == .outOfBounds ? "Lost / OB" : value.rawValue
    }

    private func detailChoices<T: RawRepresentable & CaseIterable & Identifiable & Hashable>(
        title: String,
        values: T.AllCases,
        selection: Binding<T?>
    ) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.bold())
            FlowLayout {
                ForEach(Array(values)) { value in
                    let selected = selection.wrappedValue == value
                    Button {
                        selection.wrappedValue = selected ? nil : value
                    } label: {
                        Text(value.rawValue)
                            .font(.subheadline.bold())
                            .foregroundStyle(selected ? .white : OverParTheme.ink)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .background(selected ? OverParTheme.forest : OverParTheme.canvas, in: Capsule())
                            .overlay(Capsule().stroke(selected ? OverParTheme.forest : OverParTheme.line))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func save() {
        guard canSave, var round = store.activeRound else { return }
        round.shots[round.holeNumber, default: []].append(shot)
        store.recordOnCourseShot(shot)
        if let relief = shot.relief {
            round.scores[round.holeNumber, default: 0] += relief.strokes
        }
        store.activeRound = round
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

struct PenaltySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: ReliefProcedure?
    let rulesCompliant: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    relief(.strokeAndDistance, "Return to the previous position and play again.")
                    relief(.localRuleE5, "Only when the course or competition has adopted Model Local Rule E-5.")
                    relief(.provisional, "Use the provisional if the original is lost or out of bounds.")
                    relief(.casualDrop, "Nearby +1 drop. Not permitted by the Rules of Golf.", disabled: rulesCompliant)
                } footer: {
                    Text("Out of bounds and a lost ball default to stroke and distance: one penalty stroke and replay from the previous position.")
                }
            }
            .overParFormPage()
            .navigationTitle("Ball lost or out of bounds")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func relief(_ value: ReliefProcedure, _ detail: String, disabled: Bool = false) -> some View {
        Button {
            selection = value
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(value.rawValue).font(.headline)
                    Spacer()
                    if selection == value { Image(systemName: "checkmark.circle.fill") }
                }
                Text(detail).font(.caption).foregroundStyle(OverParTheme.secondary)
            }
        }
        .disabled(disabled)
    }
}

struct ShotCameraView: View {
    var body: some View {
        LiveShotTracerCameraView()
    }
}

struct FlowLayout<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) { content }
    }
}
