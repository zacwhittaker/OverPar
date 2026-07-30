@preconcurrency import GoogleMaps
import MapKit
import PhotosUI
import SwiftUI
import UIKit

private enum TerrainElevationError: LocalizedError {
    case incompleteHole
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .incompleteHole: return "A tee or green location is missing."
        case .invalidResponse: return "The terrain service returned incomplete elevation data."
        }
    }
}

private struct TerrainElevationResponse: Decodable {
    let elevation: [Double]
}

private struct OpenTopoDataResponse: Decodable {
    struct Result: Decodable {
        let elevation: Double?
    }
    let results: [Result]
    let status: String
}

private struct OpenTopoDataRequest: Encodable {
    let locations: String
    let samples: Int
    let interpolation: String
}

private enum TerrainElevationService {
    static let sampleCount = 100

    static func profile(for hole: Hole) async throws -> HoleTerrainProfile {
        guard let tee = hole.tee, let green = hole.greenReference else {
            throw TerrainElevationError.incompleteHole
        }
        let fractions = (0..<sampleCount).map { Double($0) / Double(sampleCount - 1) }
        let coordinates = fractions.map { fraction in
            Coordinate(
                latitude: tee.latitude + (green.latitude - tee.latitude) * fraction,
                longitude: tee.longitude + (green.longitude - tee.longitude) * fraction
            )
        }
        let fetchedElevations: [Double]
        let source: String
        do {
            fetchedElevations = try await euDemElevations(tee: tee, green: green)
            source = "OpenTopoData EU-DEM 25m · 100 samples"
        } catch {
            fetchedElevations = try await openMeteoElevations(for: coordinates)
            source = "Open-Meteo Copernicus DEM 90m fallback · 100 samples"
        }
        return HoleTerrainProfile(
            source: source,
            fetchedAt: Date(),
            samples: zip(zip(fractions, coordinates), fetchedElevations).map { pair, elevation in
                TerrainSample(
                    fractionAlongHole: pair.0,
                    coordinate: pair.1,
                    elevationMetres: elevation
                )
            }
        )
    }

    private static func euDemElevations(
        tee: Coordinate,
        green: Coordinate
    ) async throws -> [Double] {
        // The free public endpoint permits one request per second. Course
        // enrichment is deliberately sequential, so a short pause keeps every
        // hole inside that limit.
        try await Task.sleep(for: .seconds(1.05))
        guard let url = URL(string: "https://api.opentopodata.org/v1/eudem25m") else {
            throw TerrainElevationError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("OverPar/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(OpenTopoDataRequest(
            locations: "\(tee.latitude),\(tee.longitude)|\(green.latitude),\(green.longitude)",
            samples: sampleCount,
            interpolation: "cubic"
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { throw TerrainElevationError.invalidResponse }
        let decoded = try JSONDecoder().decode(OpenTopoDataResponse.self, from: data)
        let values = decoded.results.compactMap(\.elevation)
        guard decoded.status == "OK", values.count == sampleCount else {
            throw TerrainElevationError.invalidResponse
        }
        return values
    }

    private static func openMeteoElevations(for coordinates: [Coordinate]) async throws -> [Double] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/elevation")
        components?.queryItems = [
            URLQueryItem(
                name: "latitude",
                value: coordinates.map { String(format: "%.7f", $0.latitude) }.joined(separator: ",")
            ),
            URLQueryItem(
                name: "longitude",
                value: coordinates.map { String(format: "%.7f", $0.longitude) }.joined(separator: ",")
            )
        ]
        guard let url = components?.url else { throw TerrainElevationError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("OverPar/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { throw TerrainElevationError.invalidResponse }
        let decoded = try JSONDecoder().decode(TerrainElevationResponse.self, from: data)
        guard decoded.elevation.count == coordinates.count else {
            throw TerrainElevationError.invalidResponse
        }
        return decoded.elevation
    }
}

struct ResearchPlayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var location: LocationService
    @State private var query = ""
    @State private var showCreator = false

    private var courses: [GolfCourse] {
        guard !query.isEmpty else { return store.courses }
        return store.courses.filter {
            [$0.name, $0.facilityName, $0.city, $0.postcode]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Play")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .tracking(-1.2)
                    .padding(.top, 10)
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                        TextField("Search courses or cities", text: $query)
                            .textInputAutocapitalization(.words)
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                                .foregroundStyle(OverParTheme.tertiary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(OverParTheme.secondarySurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    Button { location.requestOneShotLocation() } label: {
                        Image(systemName: "map")
                            .font(.title3)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 18)

                HStack {
                    Text(query.isEmpty ? "NEARBY COURSES" : "SEARCH RESULTS")
                        .font(.caption2.bold()).tracking(1.1)
                    Spacer()
                    Button { showCreator = true } label: {
                        Label("Add course", systemImage: "plus")
                    }
                    .font(.caption.bold())
                }
                .foregroundStyle(OverParTheme.forest)
                .padding(.top, 30)
                .padding(.bottom, 12)

                if let featured = courses.first {
                    NavigationLink { CourseOverviewView(courseID: featured.id) } label: {
                        ZStack(alignment: .bottomLeading) {
                            CourseCoverImage(course: featured)
                                .frame(height: 228).clipped()
                            LinearGradient(colors: [.clear, .black.opacity(0.76)], startPoint: .center, endPoint: .bottom)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(featured.isVerified ? "VERIFIED" : "COMMUNITY")
                                    .font(.caption2.bold()).tracking(1)
                                Text(featured.name)
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                Text("\(featured.city)  ·  \(featured.roundHoleCount) holes")
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.82))
                            }
                            .padding(16)
                        }
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 0) {
                        ForEach(Array(courses.dropFirst())) { course in
                            NavigationLink { CourseOverviewView(courseID: course.id) } label: {
                                HStack(spacing: 14) {
                                    CourseCoverImage(course: course)
                                        .frame(width: 104, height: 76)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(course.name).font(.headline).foregroundStyle(OverParTheme.ink)
                                        Text("\(course.city)  ·  \(course.roundHoleCount) holes")
                                            .font(.caption).foregroundStyle(OverParTheme.secondary)
                                        Label(course.isVerified ? "Verified" : "Community", systemImage: course.isVerified ? "checkmark.seal.fill" : "person.2.fill")
                                            .font(.caption2.bold()).foregroundStyle(OverParTheme.secondaryGreen)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption.bold())
                                        .foregroundStyle(OverParTheme.tertiary)
                                }
                                .padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                    .padding(.top, 8)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "map")
                            .font(.system(size: 34)).foregroundStyle(OverParTheme.forest)
                        Text(query.isEmpty ? "No courses nearby yet" : "No matching course")
                            .font(.title2.bold())
                        Text("Search by course, city or postcode—or map the first one for your community.")
                            .foregroundStyle(OverParTheme.secondary)
                        Button("Add a course") { showCreator = true }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.vertical, 34)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCreator) { CourseCreatorView() }
        .overParPage()
    }
}

struct PlayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var location: LocationService
    @State private var query = ""
    @State private var showCreator = false

    private var matches: [GolfCourse] {
        guard !query.isEmpty else { return store.courses }
        return store.courses.filter {
            [$0.name, $0.facilityName, $0.city, $0.postcode]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PLAY")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(OverParTheme.secondaryGreen)
                    Text("Find your next\nfavourite course.")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .tracking(-0.8)
                        .lineSpacing(-2)
                    Text("Community mapped. Ready whenever you are.")
                        .foregroundStyle(OverParTheme.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(OverParTheme.forest)
                    TextField("Course, city or postcode", text: $query)
                        .textInputAutocapitalization(.words)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(OverParTheme.tertiary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(OverParTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(OverParTheme.line))
                .shadow(color: OverParTheme.Shadow.small.color, radius: OverParTheme.Shadow.small.radius, y: OverParTheme.Shadow.small.y)
                HStack {
                    Button {
                        location.requestOneShotLocation()
                    } label: {
                        Label("Use my location", systemImage: "location.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Spacer()
                    Button {
                        showCreator = true
                    } label: {
                        Label("Add a course", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                SectionHeading(
                    eyebrow: query.isEmpty ? "Near you" : "Search results",
                    title: query.isEmpty ? "Courses to play" : "\(matches.count) \(matches.count == 1 ? "course" : "courses")"
                )
                ForEach(matches) { course in
                    CourseHeroCard(course: course)
                }
                if matches.isEmpty {
                    OverParEmptyState(
                        symbol: "map",
                        title: "No course found",
                        message: "Try another name, city or postcode—or add it for the community."
                    )
                    Button("Add this course") { showCreator = true }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, OverParTheme.Space.page)
            .padding(.vertical, 16)
        }
        .navigationTitle("Play")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreator = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCreator) { CourseCreatorView() }
        .overParPage()
    }
}

struct CourseOverviewView: View {
    @EnvironmentObject private var store: AppStore
    let courseID: UUID
    @State private var showDetailsEditor = false
    @State private var showHoleEditor = false
    @State private var isUpdatingTerrain = false
    @State private var terrainError: String?

    private var course: GolfCourse? {
        store.courses.first { $0.id == courseID }
    }

    var body: some View {
        Group {
            if let course {
                ScrollView {
                    VStack(spacing: 0) {
                        hero(course)
                        overview(course)
                    }
                }
                .ignoresSafeArea(edges: .top)
                .toolbar {
                    if course.canCurrentUserEdit {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button {
                                    showDetailsEditor = true
                                } label: {
                                    Label("Edit course", systemImage: "pencil")
                                }
                                Button {
                                    showHoleEditor = true
                                } label: {
                                    Label("Edit holes", systemImage: "mappin.and.ellipse")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.headline)
                                    .foregroundStyle(OverParTheme.forestDark)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().stroke(.white.opacity(0.65)))
                            }
                            .accessibilityLabel("Course options")
                        }
                    }
                }
                .sheet(isPresented: $showDetailsEditor) {
                    CourseDetailsEditorView(course: course)
                }
                .sheet(isPresented: $showHoleEditor) {
                    CourseCreatorView(editing: course, startsAtHoles: true)
                }
            } else {
                ContentUnavailableView("Course unavailable", systemImage: "flag.slash")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Terrain update failed", isPresented: Binding(
            get: { terrainError != nil },
            set: { if !$0 { terrainError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(terrainError ?? "Please try again.")
        }
        .overParPage()
    }

    private func hero(_ course: GolfCourse) -> some View {
        ZStack(alignment: .bottomLeading) {
            CourseCoverImage(course: course)
                .frame(height: 330)
                .clipped()
            LinearGradient(
                colors: [.black.opacity(0.08), .clear, .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 7) {
                Text(course.isVerified ? "VERIFIED COURSE" : "COMMUNITY COURSE")
                    .font(.caption2.bold())
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.82))
                Text(course.name)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                if !course.city.isEmpty {
                    Label(course.city, systemImage: "mappin")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.84))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(height: 330)
    }

    private func overview(_ course: GolfCourse) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 0) {
                metric("\(course.roundHoleCount)", "Holes")
                Divider().frame(height: 42)
                metric("\(course.roundTotalPar)", "Par")
                Divider().frame(height: 42)
                metric("\(course.holeCount)", "Mapped Holes")
            }

            HStack(spacing: 10) {
                NavigationLink {
                    RoundSetupView(course: course)
                } label: {
                    Label("Play", systemImage: "flag.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                NavigationLink {
                    CoursePreviewView(course: course)
                } label: {
                    Label("Preview", systemImage: "map.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button {
                updateTerrain(course)
            } label: {
                HStack {
                    if isUpdatingTerrain {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(isUpdatingTerrain ? "Updating Terrain…" : "Update Terrain")
                    Spacer()
                    Text("Tee to Green")
                        .font(.caption)
                        .foregroundStyle(OverParTheme.secondary)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isUpdatingTerrain)

            VStack(alignment: .leading, spacing: 12) {
                Text("COURSE DETAILS")
                    .font(.caption2.bold())
                    .tracking(1.2)
                    .foregroundStyle(OverParTheme.forest)
                detailRow("Facility", value: course.facilityName)
                if !course.city.isEmpty { detailRow("Location", value: course.city) }
                if !course.postcode.isEmpty { detailRow("Postcode", value: course.postcode) }
                detailRow("Layout", value: course.repeatsLayout
                          ? "\(course.holeCount) Mapped Holes · \(course.loopCount) Loops"
                          : "\(course.holeCount)-Hole Course")
                detailRow("Created By", value: "@\(course.creatorUsername ?? (course.canCurrentUserEdit ? store.profile.username : "community"))")
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("HOLE-BY-HOLE")
                        .font(.caption2.bold())
                        .tracking(1.2)
                        .foregroundStyle(OverParTheme.forest)
                    Spacer()
                    Text("Par \(course.totalPar)")
                        .font(.subheadline.bold())
                }
                VStack(spacing: 0) {
                    ForEach(course.currentRevision.holes) { hole in
                        HStack {
                            Text("\(hole.number)")
                                .font(.headline.monospacedDigit())
                                .frame(width: 32, alignment: .leading)
                            Text("Hole \(hole.number)")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if let yards = yardage(for: hole) {
                                Text("\(yards) yd")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(OverParTheme.secondary)
                            }
                            Text("Par \(hole.par)")
                                .font(.subheadline.bold())
                                .frame(width: 52, alignment: .trailing)
                        }
                        .padding(.vertical, 13)
                        if hole.id != course.currentRevision.holes.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 36)
        .background(OverParTheme.canvas)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(OverParTheme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(value).font(.system(.title2, design: .rounded, weight: .heavy)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(OverParTheme.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 3)
    }

    private func yardage(for hole: Hole) -> Int? {
        guard let tee = hole.tee, let green = hole.greenReference else { return nil }
        let metres = CLLocation(latitude: tee.latitude, longitude: tee.longitude)
            .distance(from: CLLocation(latitude: green.latitude, longitude: green.longitude))
        return Int((metres * 1.09361).rounded())
    }

    private func updateTerrain(_ course: GolfCourse) {
        guard !isUpdatingTerrain else { return }
        isUpdatingTerrain = true
        Task {
            do {
                var holes = course.currentRevision.holes
                for index in holes.indices {
                    holes[index].terrainProfile = try await TerrainElevationService.profile(for: holes[index])
                }
                store.publishTerrainRevision(courseID: course.id, holes: holes)
                isUpdatingTerrain = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                isUpdatingTerrain = false
                terrainError = error.localizedDescription
            }
        }
    }
}

private struct CourseDetailsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let course: GolfCourse
    @State private var name: String
    @State private var facility: String
    @State private var city: String
    @State private var postcode: String
    @State private var coverSelection: PhotosPickerItem?
    @State private var coverPhotoData: Data?
    @State private var useDefaultCover = false

    init(course: GolfCourse) {
        self.course = course
        _name = State(initialValue: course.name)
        _facility = State(initialValue: course.facilityName)
        _city = State(initialValue: course.city)
        _postcode = State(initialValue: course.postcode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("COURSE IDENTITY")
                            .font(.caption2.bold()).tracking(1.2)
                            .foregroundStyle(OverParTheme.forest)
                        Text("Edit course")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        Text("Update how this course appears without changing its saved hole positions.")
                            .foregroundStyle(OverParTheme.secondary)
                    }

                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if useDefaultCover {
                                CourseCoverImage(course: nil)
                            } else if let coverPhotoData, let image = UIImage(data: coverPhotoData) {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                CourseCoverImage(course: course)
                            }
                        }
                        .frame(height: 210)
                        .clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                        Text(useDefaultCover ? "DEFAULT COURSE IMAGE" : "COURSE COVER")
                            .font(.caption2.bold()).tracking(1)
                            .foregroundStyle(.white)
                            .padding(16)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    HStack(spacing: 10) {
                        PhotosPicker(selection: $coverSelection, matching: .images) {
                            Label("Choose photo", systemImage: "photo.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        if course.coverPhotoFilename != nil || coverPhotoData != nil {
                            Button {
                                coverPhotoData = nil
                                useDefaultCover = true
                            } label: {
                                Label("Use default", systemImage: "arrow.uturn.backward")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .onChange(of: coverSelection) { _, item in
                        Task {
                            guard let data = try? await item?.loadTransferable(type: Data.self),
                                  let jpeg = CourseCoverProcessor.prepare(data)
                            else { return }
                            await MainActor.run {
                                coverPhotoData = jpeg
                                useDefaultCover = false
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        editorField("Course name", text: $name)
                        editorField("Club or facility", text: $facility)
                        editorField("City", text: $city)
                        editorField("Postcode", text: $postcode)
                    }
                }
                .padding(20)
            }
            .overParPage()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateCourseDetails(
                            courseID: course.id,
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            facility: facility.trimmingCharacters(in: .whitespacesAndNewlines),
                            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                            postcode: postcode.trimmingCharacters(in: .whitespacesAndNewlines),
                            coverPhotoData: coverPhotoData,
                            useDefaultCover: useDefaultCover
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func editorField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.bold()).foregroundStyle(OverParTheme.secondary)
            TextField(title, text: text)
                .textInputAutocapitalization(.words)
                .padding(14)
                .background(OverParTheme.surface, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(OverParTheme.line))
        }
    }
}

struct CoursePreviewView: View {
    @EnvironmentObject private var store: AppStore
    @State private var course: GolfCourse
    @State private var selectedHole = 1
    @State private var camera: MapCameraPosition
    @State private var googleScale = PreviewMapScale(yards: 50, width: 76)
    @State private var isAnalysingTerrain = false
    @State private var terrainProgress = 0.0
    @State private var terrainStatus = "Preparing the course…"
    @State private var showTerrainFailure = false

    init(course: GolfCourse) {
        _course = State(initialValue: course)
        let coordinate = course.referenceCoordinate?.clLocationCoordinate ?? CLLocationCoordinate2D(latitude: 53.8008, longitude: -1.5491)
        _camera = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }

    private var hole: Hole { course.currentRevision.holes[selectedHole - 1] }
    private var holeYards: Int? {
        guard let tee = hole.tee, let green = hole.greenReference else { return nil }
        let metres = CLLocation(
            latitude: tee.latitude,
            longitude: tee.longitude
        ).distance(from: CLLocation(latitude: green.latitude, longitude: green.longitude))
        return Int((metres * 1.09361).rounded())
    }

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Group {
                    if GoogleMapsConfiguration.isConfigured {
                        GoogleCoursePreviewMap(
                            hole: hole,
                            selectedHole: selectedHole,
                            scale: $googleScale
                        )
                    } else {
                        Map(position: $camera) {
                            if let tee = hole.tee {
                                Annotation("Tee", coordinate: tee.clLocationCoordinate) {
                                    FriendlyMapPin(kind: .tee)
                                }
                            }
                            if let green = hole.greenReference {
                                Annotation("Green", coordinate: green.clLocationCoordinate) {
                                    FriendlyMapPin(kind: .green)
                                }
                            }
                            if let tee = hole.tee, let green = hole.greenReference {
                                MapPolyline(coordinates: [tee.clLocationCoordinate, green.clLocationCoordinate])
                                    .stroke(.white, lineWidth: 7)
                                MapPolyline(coordinates: [tee.clLocationCoordinate, green.clLocationCoordinate])
                                    .stroke(OverParTheme.forest, style: StrokeStyle(lineWidth: 3, dash: [9, 7]))
                            }
                        }
                        .mapStyle(.imagery)
                        .mapControls {
                            MapCompass()
                            MapScaleView()
                            MapUserLocationButton()
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                HStack(alignment: .top) {
                    if GoogleMapsConfiguration.isConfigured {
                        mapScale
                    }
                    Spacer()
                    if let holeYards {
                        Label("\(holeYards) yd", systemImage: "flag.fill")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .foregroundStyle(OverParTheme.forestDark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.94), in: Capsule())
                            .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
                            .accessibilityLabel("Tee to green reference \(holeYards) yards")
                    }
                }
                .padding(16)
            }

            VStack(spacing: 15) {
                HStack {
                    holeNavigationButton(
                        title: "Previous",
                        symbol: "arrow.left",
                        enabled: selectedHole > 1
                    ) {
                        changeHole(to: selectedHole - 1)
                    }
                    Spacer()
                    VStack(spacing: 3) {
                        Text("HOLE \(hole.number)")
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(OverParTheme.forest)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Par \(hole.par)")
                                .font(.system(.title2, design: .rounded, weight: .heavy))
                            if let holeYards {
                                Text("· \(holeYards) yd")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(OverParTheme.secondary)
                            }
                        }
                    }
                    Spacer()
                    holeNavigationButton(
                        title: "Next",
                        symbol: "arrow.right",
                        enabled: selectedHole < course.holeCount,
                        imageAfterText: true
                    ) {
                        changeHole(to: selectedHole + 1)
                    }
                }
                if canUpdateTerrain {
                    Button {
                        analyseTerrain()
                    } label: {
                        Label(
                            needsTerrainAnalysis ? "Analyse Terrain" : "Update Terrain",
                            systemImage: needsTerrainAnalysis
                                ? "mountain.2.fill"
                                : "arrow.triangle.2.circlepath"
                        )
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.bordered)
                    .tint(OverParTheme.forest)
                }
                NavigationLink("Play this course") { RoundSetupView(course: course) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .background(OverParTheme.surface)
        }
            if isAnalysingTerrain {
                TerrainLoadingView(progress: terrainProgress, status: terrainStatus)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isAnalysingTerrain)
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Terrain could not be read", isPresented: $showTerrainFailure) {
            Button("Try again") { analyseTerrain() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The course is unchanged. Check your connection and try again.")
        }
    }

    private var needsTerrainAnalysis: Bool {
        course.currentRevision.holes.contains {
            $0.tee != nil && $0.greenReference != nil && $0.terrainProfile == nil
        }
    }

    private var canUpdateTerrain: Bool {
        course.currentRevision.holes.contains {
            $0.tee != nil && $0.greenReference != nil
        }
    }

    private func analyseTerrain() {
        guard canUpdateTerrain else { return }
        isAnalysingTerrain = true
        terrainProgress = 0
        terrainStatus = "Preparing the terrain scan…"

        Task {
            do {
                var enrichedHoles = course.currentRevision.holes
                let terrainIndices = enrichedHoles.indices.filter {
                    enrichedHoles[$0].tee != nil
                        && enrichedHoles[$0].greenReference != nil
                }
                for (progressIndex, holeIndex) in terrainIndices.enumerated() {
                    terrainStatus = "Reading 100 terrain points for hole \(holeIndex + 1)…"
                    enrichedHoles[holeIndex].terrainProfile = try await TerrainElevationService.profile(
                        for: enrichedHoles[holeIndex]
                    )
                    withAnimation(.easeInOut(duration: 0.25)) {
                        terrainProgress = Double(progressIndex + 1) / Double(terrainIndices.count)
                    }
                }
                terrainStatus = "Saving the terrain revision…"
                if let updated = store.publishTerrainRevision(courseID: course.id, holes: enrichedHoles) {
                    course = updated
                }
                isAnalysingTerrain = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                isAnalysingTerrain = false
                showTerrainFailure = true
            }
        }
    }

    private var mapScale: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(googleScale.yards) yd")
                .font(.system(.caption2, design: .rounded, weight: .heavy))
            HStack(spacing: 0) {
                Rectangle().frame(width: 2, height: 7)
                Rectangle().frame(width: googleScale.width, height: 2)
                Rectangle().frame(width: 2, height: 7)
            }
        }
        .foregroundStyle(OverParTheme.ink)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 7, y: 3)
        .accessibilityLabel("Map scale \(googleScale.yards) yards")
    }

    private func changeHole(to newHole: Int) {
        guard (1...course.holeCount).contains(newHole) else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            selectedHole = newHole
        }
        moveCamera(to: newHole)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func moveCamera(to holeNumber: Int) {
        guard
            course.currentRevision.holes.indices.contains(holeNumber - 1),
            let point = course.currentRevision.holes[holeNumber - 1].tee ??
                course.currentRevision.holes[holeNumber - 1].greenReference
        else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            camera = .region(MKCoordinateRegion(
                center: point.clLocationCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
            ))
        }
    }

    private func holeNavigationButton(
        title: String,
        symbol: String,
        enabled: Bool,
        imageAfterText: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if !imageAfterText { Image(systemName: symbol) }
                Text(title)
                if imageAfterText { Image(systemName: symbol) }
            }
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(enabled ? OverParTheme.forest : OverParTheme.secondary.opacity(0.45))
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(enabled ? OverParTheme.mint : OverParTheme.canvas, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct PreviewMapScale: Equatable {
    var yards: Int
    var width: CGFloat
}

private enum FriendlyPinKind {
    case tee
    case green

    var title: String { self == .tee ? "TEE" : "GREEN" }
    var symbol: String { self == .tee ? "figure.golf" : "flag.fill" }
    var colour: Color { self == .tee ? OverParTheme.forest : Color(red: 0.92, green: 0.26, blue: 0.28) }
}

private struct FriendlyMapPin: View {
    let kind: FriendlyPinKind

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: kind.symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(kind.colour, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
            Text(kind.title)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.58), in: Capsule())
        }
    }
}

private struct GoogleCoursePreviewMap: UIViewRepresentable {
    let hole: Hole
    let selectedHole: Int
    @Binding var scale: PreviewMapScale

    func makeCoordinator() -> Coordinator {
        Coordinator(scale: $scale, initialHole: selectedHole)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let focus = hole.tee ?? hole.greenReference ?? Coordinate(latitude: 53.8008, longitude: -1.5491)
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition.camera(
            withLatitude: focus.latitude,
            longitude: focus.longitude,
            zoom: 17
        )
        options.backgroundColor = UIColor(OverParTheme.mint)
        let map = GMSMapView(options: options)
        map.mapType = .satellite
        map.delegate = context.coordinator
        map.settings.compassButton = true
        map.settings.myLocationButton = false
        map.settings.rotateGestures = false
        map.settings.tiltGestures = false
        map.isBuildingsEnabled = false
        map.padding = UIEdgeInsets(top: 74, left: 0, bottom: 14, right: 8)
        context.coordinator.render(hole: hole, on: map)
        context.coordinator.fit(hole: hole, on: map, animated: false)
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        guard context.coordinator.lastHole != selectedHole else { return }
        context.coordinator.lastHole = selectedHole
        context.coordinator.render(hole: hole, on: map)
        context.coordinator.fit(hole: hole, on: map, animated: true)
    }

    @MainActor
    final class Coordinator: NSObject, GMSMapViewDelegate {
        var scale: Binding<PreviewMapScale>
        var lastHole: Int
        private var overlays: [GMSOverlay] = []

        init(scale: Binding<PreviewMapScale>, initialHole: Int) {
            self.scale = scale
            lastHole = initialHole
        }

        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            updateScale(for: mapView)
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            updateScale(for: mapView)
        }

        func render(hole: Hole, on map: GMSMapView) {
            overlays.forEach { $0.map = nil }
            overlays.removeAll(keepingCapacity: true)

            if let tee = hole.tee {
                addMarker(kind: .tee, coordinate: tee.clLocationCoordinate, to: map)
            }
            if let green = hole.greenReference {
                addMarker(kind: .green, coordinate: green.clLocationCoordinate, to: map)
            }
            if let tee = hole.tee, let green = hole.greenReference {
                let path = GMSMutablePath()
                path.add(tee.clLocationCoordinate)
                path.add(green.clLocationCoordinate)

                let outline = GMSPolyline(path: path)
                outline.strokeColor = .white
                outline.strokeWidth = 7
                outline.map = map
                overlays.append(outline)

                let route = GMSPolyline(path: path)
                route.strokeWidth = 3
                route.spans = GMSStyleSpans(
                    path,
                    [
                        GMSStrokeStyle.solidColor(UIColor(OverParTheme.forest)),
                        GMSStrokeStyle.solidColor(.clear)
                    ],
                    [NSNumber(value: 14), NSNumber(value: 8)],
                    .rhumb
                )
                route.map = map
                overlays.append(route)
            }
        }

        func fit(hole: Hole, on map: GMSMapView, animated: Bool) {
            guard let tee = hole.tee, let green = hole.greenReference else { return }
            let bounds = GMSCoordinateBounds(
                coordinate: tee.clLocationCoordinate,
                coordinate: green.clLocationCoordinate
            )
            let update = GMSCameraUpdate.fit(bounds, withPadding: 92)
            DispatchQueue.main.async {
                if animated {
                    map.animate(with: update)
                } else {
                    map.moveCamera(update)
                }
                self.updateScale(for: map)
            }
        }

        private func addMarker(
            kind: FriendlyPinKind,
            coordinate: CLLocationCoordinate2D,
            to map: GMSMapView
        ) {
            let renderer = ImageRenderer(content: FriendlyMapPin(kind: kind))
            renderer.scale = UIScreen.main.scale
            let marker = GMSMarker(position: coordinate)
            marker.title = kind == .tee ? "Tee" : "Green reference"
            marker.icon = renderer.uiImage
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.58)
            marker.map = map
            overlays.append(marker)
        }

        private func updateScale(for map: GMSMapView) {
            guard map.bounds.width > 120, map.bounds.height > 100 else { return }
            let sampleWidth: CGFloat = 90
            let y = map.bounds.midY
            let start = map.projection.coordinate(for: CGPoint(x: 18, y: y))
            let end = map.projection.coordinate(for: CGPoint(x: 18 + sampleWidth, y: y))
            let yards = CLLocation(
                latitude: start.latitude,
                longitude: start.longitude
            ).distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude)) * 1.09361
            guard yards.isFinite, yards > 0 else { return }

            let choices = [1, 2, 5, 10, 20, 25, 50, 75, 100, 150, 200, 250, 500, 750, 1000]
            let niceYards = choices.last(where: { Double($0) <= yards }) ?? 1
            let width = max(28, min(sampleWidth, sampleWidth * CGFloat(Double(niceYards) / yards)))
            let next = PreviewMapScale(yards: niceYards, width: width)
            if scale.wrappedValue != next {
                scale.wrappedValue = next
            }
        }
    }
}

private enum RecordingMethod: String, CaseIterable, Identifiable {
    case satellite = "Satellite map"
    case walk = "Walk with GPS"
    var id: String { rawValue }
}

private struct CourseHoleSatelliteMap: View {
    @Binding var hole: Hole
    @Binding var placementTarget: String
    let focus: Coordinate
    @State private var camera: MapCameraPosition

    init(hole: Binding<Hole>, placementTarget: Binding<String>, focus: Coordinate) {
        _hole = hole
        _placementTarget = placementTarget
        self.focus = focus
        _camera = State(initialValue: Self.cameraPosition(for: focus))
    }

    var body: some View {
        Group {
            if GoogleMapsConfiguration.isConfigured {
                GoogleHoleMapView(hole: $hole, placementTarget: $placementTarget, focus: focus)
            } else {
                appleMap
            }
        }
        .frame(height: 365)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white, lineWidth: 3))
        .shadow(color: OverParTheme.forest.opacity(0.12), radius: 14, y: 6)
    }

    private var appleMap: some View {
        MapReader { proxy in
            Map(position: $camera, interactionModes: [.pan, .zoom]) {
                if let tee = hole.tee {
                    Marker("Tee", systemImage: "figure.golf", coordinate: tee.clLocationCoordinate)
                        .tint(OverParTheme.forest)
                }
                if let green = hole.greenReference {
                    Marker("Green reference", systemImage: "flag.fill", coordinate: green.clLocationCoordinate)
                        .tint(.red)
                }
                if let tee = hole.tee, let green = hole.greenReference {
                    MapPolyline(coordinates: [tee.clLocationCoordinate, green.clLocationCoordinate])
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, dash: [7, 5]))
                }
            }
            .mapStyle(.imagery)
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                let value = Coordinate(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    capturedAt: Date()
                )
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    if placementTarget == "tee" {
                        hole.tee = value
                        placementTarget = "green"
                    } else {
                        hole.greenReference = value
                    }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .onChange(of: focus) { _, newFocus in
            withAnimation(.easeInOut(duration: 0.5)) {
                camera = Self.cameraPosition(for: newFocus)
            }
        }
    }

    private static func cameraPosition(for focus: Coordinate) -> MapCameraPosition {
        .region(MKCoordinateRegion(
            center: focus.clLocationCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        ))
    }
}

private struct GoogleHoleMapView: UIViewRepresentable {
    @Binding var hole: Hole
    @Binding var placementTarget: String
    let focus: Coordinate

    func makeCoordinator() -> Coordinator {
        Coordinator(hole: $hole, placementTarget: $placementTarget, initialFocus: focus)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition.camera(
            withLatitude: focus.latitude,
            longitude: focus.longitude,
            zoom: 18
        )
        options.backgroundColor = UIColor(OverParTheme.mint)
        let map = GMSMapView(options: options)
        map.mapType = .satellite
        map.delegate = context.coordinator
        map.settings.compassButton = true
        map.settings.rotateGestures = false
        map.settings.tiltGestures = false
        map.isBuildingsEnabled = false
        context.coordinator.renderGeometry(on: map, hole: hole)
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        context.coordinator.hole = $hole
        context.coordinator.placementTarget = $placementTarget
        context.coordinator.renderGeometry(on: map, hole: hole)
        guard context.coordinator.lastFocus != focus else { return }
        context.coordinator.lastFocus = focus
        map.animate(to: GMSCameraPosition.camera(
            withLatitude: focus.latitude,
            longitude: focus.longitude,
            zoom: 18
        ))
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var hole: Binding<Hole>
        var placementTarget: Binding<String>
        var lastFocus: Coordinate
        private var overlays: [GMSOverlay] = []

        init(hole: Binding<Hole>, placementTarget: Binding<String>, initialFocus: Coordinate) {
            self.hole = hole
            self.placementTarget = placementTarget
            lastFocus = initialFocus
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            let point = Coordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                capturedAt: Date()
            )
            if placementTarget.wrappedValue == "tee" {
                hole.wrappedValue.tee = point
                placementTarget.wrappedValue = "green"
            } else {
                hole.wrappedValue.greenReference = point
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        func renderGeometry(on map: GMSMapView, hole: Hole) {
            overlays.forEach { $0.map = nil }
            overlays.removeAll(keepingCapacity: true)

            if let tee = hole.tee {
                let marker = GMSMarker(position: tee.clLocationCoordinate)
                marker.title = "Tee"
                marker.icon = GMSMarker.markerImage(with: UIColor(OverParTheme.forest))
                marker.map = map
                overlays.append(marker)
            }
            if let green = hole.greenReference {
                let marker = GMSMarker(position: green.clLocationCoordinate)
                marker.title = "Green reference"
                marker.icon = GMSMarker.markerImage(with: .systemRed)
                marker.map = map
                overlays.append(marker)
            }
            if let tee = hole.tee, let green = hole.greenReference {
                let path = GMSMutablePath()
                path.add(tee.clLocationCoordinate)
                path.add(green.clLocationCoordinate)
                let line = GMSPolyline(path: path)
                line.strokeColor = .white
                line.strokeWidth = 4
                line.spans = GMSStyleSpans(
                    path,
                    [GMSStrokeStyle.solidColor(.white), GMSStrokeStyle.solidColor(.clear)],
                    [NSNumber(value: 14), NSNumber(value: 8)],
                    .rhumb
                )
                line.map = map
                overlays.append(line)
            }
        }
    }
}

struct CourseCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var location: LocationService
    @State private var name = ""
    @State private var facility = ""
    @State private var city = ""
    @State private var count = 18
    @State private var loopCount = 1
    @State private var method: RecordingMethod = .satellite
    @State private var holes = (1...18).map { Hole(number: $0, par: 4) }
    @State private var step = 0
    @State private var mapFocus = Coordinate(latitude: 53.8008, longitude: -1.5491)
    @State private var placementTarget: String = "tee"
    @State private var showingSafety = true
    @State private var isPublishing = false
    @State private var mapSearchQuery = ""
    @State private var isSearchingMap = false
    @State private var mapSearchError: String?
    @State private var terrainProgress = 0.0
    @State private var terrainStatus = "Preparing the course…"
    @State private var showTerrainFailure = false
    @State private var coverSelection: PhotosPickerItem?
    @State private var coverPhotoData: Data?
    private let editingCourseID: UUID?
    private let firstEditableStep: Int

    init(editing course: GolfCourse? = nil, startsAtHoles: Bool = false) {
        editingCourseID = course?.id
        firstEditableStep = startsAtHoles ? 1 : 0
        _name = State(initialValue: course?.name ?? "")
        _facility = State(initialValue: course?.facilityName ?? "")
        _city = State(initialValue: course?.city ?? "")
        _count = State(initialValue: course?.holeCount ?? 18)
        _loopCount = State(initialValue: course?.loopCount ?? 1)
        _holes = State(initialValue: course?.currentRevision.holes ?? (1...18).map { Hole(number: $0, par: 4) })
        _showingSafety = State(initialValue: course == nil)
        _step = State(initialValue: startsAtHoles ? 1 : 0)
    }

    private var currentHoleIndex: Int? {
        guard (1...count).contains(step) else { return nil }
        return step - 1
    }

    private var totalSteps: Int { count + 2 }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    progressHeader
                    ZStack {
                        if step == 0 {
                            detailsStep
                                .transition(stepTransition)
                        } else if let currentHoleIndex {
                            holeStep(index: currentHoleIndex)
                                .id(step)
                                .transition(stepTransition)
                        } else {
                            reviewStep
                                .transition(stepTransition)
                        }
                    }
                    .animation(.spring(response: 0.42, dampingFraction: 0.88), value: step)
                    bottomControls
                }
                if isPublishing {
                    TerrainLoadingView(progress: terrainProgress, status: terrainStatus)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .zIndex(10)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isPublishing)
            .background(OverParTheme.canvas.ignoresSafeArea())
            .foregroundStyle(OverParTheme.ink)
            .navigationTitle(editingCourseID == nil ? "Create course" : firstEditableStep == 1 ? "Edit holes" : "Edit course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .alert("Map safely", isPresented: $showingSafety) {
                Button("I understand") {}
            } message: {
                Text("Do not enter restricted areas, obstruct play or stand in a shot path. The saved flag point is a persistent green reference because the physical cup moves.")
            }
            .alert("Terrain could not be read", isPresented: $showTerrainFailure) {
                Button("Try again") { publish() }
                Button("Publish without terrain for now") { publishWithoutTerrain() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your tee and green locations are safe. You can retry now or publish the course and let terrain enrichment happen later.")
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stepTitle)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("Step \(step + 1) of \(totalSteps)")
                        .font(.caption)
                        .foregroundStyle(OverParTheme.secondary)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(OverParTheme.forest)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(OverParTheme.mint, in: Capsule())
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(OverParTheme.line)
                    Capsule()
                        .fill(OverParTheme.forest)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                wizardHeading(
                    eyebrow: "First things first",
                    title: "Tell us about the course",
                    detail: "These details help golfers find the right course in the community."
                )
                OverParCard {
                    VStack(spacing: 14) {
                        creatorField("Course name", symbol: "flag.fill", text: $name, contentType: .organizationName)
                        creatorField("Club or facility name", symbol: "building.2.fill", text: $facility, contentType: .organizationName)
                        creatorField("City", symbol: "mappin.and.ellipse", text: $city, contentType: .addressCity)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Course cover")
                        .font(.headline)
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let coverPhotoData, let image = UIImage(data: coverPhotoData) {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else if let editingCourseID,
                                      let course = store.courses.first(where: { $0.id == editingCourseID }) {
                                CourseCoverImage(course: course)
                            } else {
                                CourseCoverImage(course: nil)
                            }
                        }
                        .frame(height: 168)
                        .clipped()
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.68)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text("COURSE COVER").font(.caption2.bold()).tracking(1)
                            Text(coverPhotoData == nil ? "Default artwork" : "Selected photo")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    PhotosPicker(selection: $coverSelection, matching: .images) {
                        Label(
                            editingCourseID == nil && coverPhotoData == nil
                                ? "Choose a cover photo"
                                : "Change cover photo",
                            systemImage: "photo.badge.plus"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .onChange(of: coverSelection) { _, item in
                        Task {
                            guard let data = try? await item?.loadTransferable(type: Data.self),
                                  let jpeg = CourseCoverProcessor.prepare(data)
                            else { return }
                            await MainActor.run { coverPhotoData = jpeg }
                        }
                    }
                    Text("Landscape photos work best. If you skip this, OverPar keeps the default course image.")
                        .font(.caption)
                        .foregroundStyle(OverParTheme.secondary)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("How many holes?")
                        .font(.headline)
                    HStack(spacing: 12) {
                        holeCountButton(9)
                        holeCountButton(18)
                    }
                }
                if count == 9 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How is the layout played?")
                            .font(.headline)
                        Text("Save the nine physical holes once, then choose how many loops make a normal round.")
                            .font(.caption)
                            .foregroundStyle(OverParTheme.secondary)
                        HStack(spacing: 10) {
                            loopButton(1, label: "9 holes")
                            loopButton(2, label: "18 holes")
                            loopButton(3, label: "27 holes")
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("How will you map it?")
                        .font(.headline)
                    ForEach(RecordingMethod.allCases) { option in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                method = option
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: option == .satellite ? "map.fill" : "location.fill")
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(method == option ? .white.opacity(0.18) : OverParTheme.mint, in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.rawValue).font(.headline)
                                    Text(option == .satellite
                                         ? "Drop tee and green points onto satellite imagery."
                                         : "Walk to each point and capture stable live GPS.")
                                        .font(.caption)
                                        .foregroundStyle(method == option ? .white.opacity(0.82) : OverParTheme.secondary)
                                }
                                Spacer()
                                Image(systemName: method == option ? "checkmark.circle.fill" : "circle")
                            }
                            .foregroundStyle(method == option ? .white : OverParTheme.ink)
                            .padding(16)
                            .background(method == option ? OverParTheme.forest : .white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(method == option ? OverParTheme.forest : OverParTheme.line))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
    }

    private func holeStep(index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                wizardHeading(
                    eyebrow: "Hole \(index + 1) of \(count)",
                    title: "Build hole \(index + 1)",
                    detail: method == .satellite
                        ? "Choose a point, then tap its position on the satellite map."
                        : "Stand safely at each point and let GPS settle before saving."
                )
                parSelector(index: index)
                if method == .satellite {
                    satelliteRecorder(index: index)
                } else {
                    gpsRecorder(index: index)
                }
                captureStatus(index: index)
            }
            .padding(20)
        }
        .onAppear {
            if let point = holes[index].tee ?? holes[index].greenReference {
                moveCamera(to: point.clLocationCoordinate)
            } else if index > 0, let previousPoint = holes[index - 1].greenReference ?? holes[index - 1].tee {
                moveCamera(to: previousPoint.clLocationCoordinate)
            } else if let point = location.location?.coordinate {
                moveCamera(to: point)
            }
        }
    }

    private func parSelector(index: Int) -> some View {
        OverParCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Par for this hole")
                    .font(.headline)
                HStack(spacing: 10) {
                    ForEach(3...6, id: \.self) { par in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                holes[index].par = par
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(par)")
                                    .font(.system(.title2, design: .rounded, weight: .heavy))
                                Text("PAR").font(.caption2.bold())
                            }
                            .foregroundStyle(holes[index].par == par ? .white : OverParTheme.forest)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(holes[index].par == par ? OverParTheme.forest : OverParTheme.mint, in: RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func satelliteRecorder(index: Int) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(OverParTheme.secondary)
                    TextField("Search address or postcode", text: $mapSearchQuery)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit { searchMap() }
                    if isSearchingMap {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(OverParTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(OverParTheme.line))
                Button {
                    searchMap()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.headline)
                        .frame(width: 50, height: 50)
                        .foregroundStyle(.white)
                        .background(OverParTheme.forest, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(mapSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearchingMap)
            }
            if let mapSearchError {
                Label(mapSearchError, systemImage: "exclamationmark.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                placementButton("Tee box", symbol: "figure.golf", value: "tee", complete: holes[index].tee != nil)
                placementButton("Green", symbol: "flag.fill", value: "green", complete: holes[index].greenReference != nil)
            }
            CourseHoleSatelliteMap(
                hole: $holes[index],
                placementTarget: $placementTarget,
                focus: mapFocus
            )
            Text(placementTarget == "tee" ? "Tap the tee box on the map" : "Now tap the centre of the green")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(OverParTheme.forest)
        }
    }

    private func gpsRecorder(index: Int) -> some View {
        OverParCard {
            VStack(spacing: 12) {
                locationButton("Capture tee box", symbol: "figure.golf") { point in
                    holes[index].tee = point
                }
                locationButton("Capture green reference", symbol: "flag.fill") { point in
                    holes[index].greenReference = point
                }
                if location.isSettling {
                    HStack {
                        ProgressView()
                        Text("Collecting fresh GPS samples…")
                            .font(.subheadline)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
                if let error = location.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func captureStatus(index: Int) -> some View {
        HStack(spacing: 12) {
            capturePill("Tee", complete: holes[index].tee != nil)
            capturePill("Green", complete: holes[index].greenReference != nil)
        }
    }

    private func locationButton(_ title: String, symbol: String, apply: @escaping (Coordinate) -> Void) -> some View {
        Button {
            location.captureStablePoint { point in
                if let point { apply(point) }
            }
        } label: {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(location.isSettling)
    }

    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                wizardHeading(
                    eyebrow: "Ready for the community",
                    title: "Review your course",
                    detail: editingCourseID == nil
                        ? "Check every hole before publishing the first permanent revision."
                        : "Check every hole before saving a new permanent revision."
                )
                OverParCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(name).font(.title2.bold())
                        Text(facility.isEmpty ? name : facility)
                            .foregroundStyle(OverParTheme.secondary)
                        HStack {
                            Label(loopCount > 1 ? "\(count)-hole layout ×\(loopCount)" : "\(count) holes", systemImage: "figure.golf")
                            Label("Round par \(holes.reduce(0) { $0 + $1.par } * loopCount)", systemImage: "flag.fill")
                        }
                        .font(.subheadline.bold())
                        if !city.isEmpty {
                            Label(city, systemImage: "mappin")
                                .font(.subheadline)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(holes.enumerated()), id: \.element.id) { index, hole in
                        Button {
                            go(to: index + 1)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Hole \(hole.number)").font(.headline)
                                    Text("Par \(hole.par)").font(.caption)
                                }
                                Spacer()
                                Image(systemName: hole.tee != nil && hole.greenReference != nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(hole.tee != nil && hole.greenReference != nil ? OverParTheme.forest : .orange)
                            }
                            .padding(14)
                            .background(OverParTheme.surface, in: RoundedRectangle(cornerRadius: 17))
                            .overlay(RoundedRectangle(cornerRadius: 17).stroke(OverParTheme.line))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("The physical cup moves. OverPar saves a persistent green reference. Later material corrections create a new revision instead of overwriting this one.")
                    .font(.caption)
                    .foregroundStyle(OverParTheme.secondary)
            }
            .padding(20)
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 12) {
            if step > firstEditableStep {
                Button {
                    go(to: step - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 54, height: 56)
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            Button {
                if step == totalSteps - 1 {
                    publish()
                } else {
                    go(to: step + 1)
                }
            } label: {
                HStack {
                    if isPublishing { ProgressView().tint(.white) }
                    Text(step == totalSteps - 1
                         ? (editingCourseID == nil ? "Publish course" : "Save changes")
                         : step == 0 ? "Start hole 1" : step == count ? "Review course" : "Next hole")
                    if !isPublishing { Image(systemName: step == totalSteps - 1 ? "checkmark" : "arrow.right") }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canAdvance || isPublishing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func wizardHeading(eyebrow: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased())
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(OverParTheme.forest)
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
            Text(detail)
                .foregroundStyle(OverParTheme.secondary)
        }
    }

    private func creatorField(
        _ title: String,
        symbol: String,
        text: Binding<String>,
        contentType: UITextContentType
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(OverParTheme.forest)
                .frame(width: 24)
            TextField(title, text: text)
                .textContentType(contentType)
                .textInputAutocapitalization(.words)
        }
        .padding(14)
        .background(OverParTheme.canvas, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(OverParTheme.line))
    }

    private func holeCountButton(_ value: Int) -> some View {
        Button {
            updateHoleCount(value)
        } label: {
            VStack(spacing: 3) {
                Text("\(value)").font(.system(.title, design: .rounded, weight: .heavy))
                Text("HOLES").font(.caption.bold())
            }
            .foregroundStyle(count == value ? .white : OverParTheme.forest)
            .frame(maxWidth: .infinity, minHeight: 82)
            .background(count == value ? OverParTheme.forest : .white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(count == value ? OverParTheme.forest : OverParTheme.line))
        }
        .buttonStyle(.plain)
    }

    private func loopButton(_ value: Int, label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                loopCount = value
            }
        } label: {
            VStack(spacing: 3) {
                Text("×\(value)")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                Text(label)
                    .font(.caption2.bold())
            }
            .foregroundStyle(loopCount == value ? .white : OverParTheme.forest)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(loopCount == value ? OverParTheme.forest : OverParTheme.surface, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(loopCount == value ? OverParTheme.forest : OverParTheme.line))
        }
        .buttonStyle(.plain)
    }

    private func placementButton(_ title: String, symbol: String, value: String, complete: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { placementTarget = value }
        } label: {
            HStack {
                Image(systemName: symbol)
                Text(title).font(.subheadline.bold())
                Spacer()
                if complete { Image(systemName: "checkmark.circle.fill") }
            }
            .foregroundStyle(placementTarget == value ? .white : OverParTheme.forest)
            .padding(14)
            .background(placementTarget == value ? OverParTheme.forest : OverParTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(placementTarget == value ? OverParTheme.forest : OverParTheme.line))
        }
        .buttonStyle(.plain)
    }

    private func capturePill(_ title: String, complete: Bool) -> some View {
        Label(complete ? "\(title) saved" : "\(title) needed", systemImage: complete ? "checkmark.circle.fill" : "circle")
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(complete ? OverParTheme.forest : OverParTheme.secondary)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(complete ? OverParTheme.mint : .white, in: Capsule())
            .overlay(Capsule().stroke(OverParTheme.line))
    }

    private var progress: Double {
        Double(step + 1) / Double(totalSteps)
    }

    private var stepTitle: String {
        if step == 0 { return "Course details" }
        if step == totalSteps - 1 { return "Final review" }
        return "Hole \(step)"
    }

    private var canAdvance: Bool {
        if step == 0 {
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if let currentHoleIndex {
            let hole = holes[currentHoleIndex]
            return (3...6).contains(hole.par) && hole.tee != nil && hole.greenReference != nil
        }
        return isPublishable
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func updateHoleCount(_ value: Int) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            count = value
            if value != 9 { loopCount = 1 }
            if holes.count < value {
                holes.append(contentsOf: ((holes.count + 1)...value).map { Hole(number: $0, par: 4) })
            } else {
                holes = Array(holes.prefix(value))
            }
        }
    }

    private func go(to newStep: Int) {
        placementTarget = "tee"
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            step = max(firstEditableStep, min(newStep, totalSteps - 1))
        }
    }

    private func moveCamera(to coordinate: CLLocationCoordinate2D) {
        mapFocus = Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private func searchMap() {
        let query = mapSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearchingMap = true
        mapSearchError = nil
        Task { @MainActor in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            do {
                let response = try await MKLocalSearch(request: request).start()
                guard let coordinate = response.mapItems.first?.placemark.coordinate else {
                    mapSearchError = "No matching place found. Try adding the town or postcode."
                    isSearchingMap = false
                    return
                }
                withAnimation(.easeInOut(duration: 0.55)) {
                    moveCamera(to: coordinate)
                }
            } catch {
                mapSearchError = "That search did not work. Check the address and try again."
            }
            isSearchingMap = false
        }
    }

    private func publish() {
        guard isPublishable else { return }
        isPublishing = true
        terrainProgress = 0
        terrainStatus = "Preparing the terrain scan…"

        Task {
            do {
                var enrichedHoles = holes
                for index in enrichedHoles.indices {
                    terrainStatus = "Reading contours for hole \(index + 1) of \(enrichedHoles.count)…"
                    enrichedHoles[index].terrainProfile = try await TerrainElevationService.profile(
                        for: enrichedHoles[index]
                    )
                    withAnimation(.easeInOut(duration: 0.25)) {
                        terrainProgress = Double(index + 1) / Double(enrichedHoles.count)
                    }
                }
                terrainStatus = "Saving your course…"
                holes = enrichedHoles
                finishPublishing(holes: enrichedHoles)
            } catch {
                isPublishing = false
                showTerrainFailure = true
            }
        }
    }

    private func publishWithoutTerrain() {
        isPublishing = true
        terrainProgress = 1
        terrainStatus = "Saving your course…"
        finishPublishing(holes: holes)
    }

    private func finishPublishing(holes publishedHoles: [Hole]) {
        if let editingCourseID {
            store.updateCourse(
                courseID: editingCourseID,
                name: name,
                facility: facility,
                city: city,
                postcode: "",
                holes: publishedHoles,
                loopCount: loopCount,
                coverPhotoData: coverPhotoData
            )
        } else {
            store.publishCourse(
                name: name,
                facility: facility,
                city: city,
                postcode: "",
                holes: publishedHoles,
                loopCount: loopCount,
                coverPhotoData: coverPhotoData
            )
        }
        dismiss()
    }

    private var isPublishable: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        holes.count == count &&
        holes.allSatisfy { (3...6).contains($0.par) && $0.tee != nil && $0.greenReference != nil }
    }
}

private struct TerrainLoadingView: View {
    let progress: Double
    let status: String
    @State private var animateContours = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    ForEach(0..<4, id: \.self) { ring in
                        RoundedRectangle(cornerRadius: CGFloat(28 + ring * 5), style: .continuous)
                            .stroke(
                                OverParTheme.forest.opacity(0.18 + Double(ring) * 0.11),
                                lineWidth: 2
                            )
                            .frame(
                                width: CGFloat(82 + ring * 24),
                                height: CGFloat(58 + ring * 18)
                            )
                            .rotationEffect(.degrees(Double(ring * 11)))
                            .scaleEffect(animateContours ? 1.04 : 0.96)
                            .animation(
                                .easeInOut(duration: 1.3 + Double(ring) * 0.16)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(ring) * 0.08),
                                value: animateContours
                            )
                    }
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(OverParTheme.forest)
                }
                .frame(height: 150)

                VStack(spacing: 8) {
                    Text("Reading the landscape")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                    Text(status)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(OverParTheme.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(OverParTheme.line)
                            Capsule()
                                .fill(OverParTheme.forest)
                                .frame(width: geometry.size.width * max(0.03, progress))
                        }
                    }
                    .frame(height: 9)
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(OverParTheme.forest)
                }
                .frame(maxWidth: 260)

                Text("OverPar is automatically mapping uphill and downhill changes. You don’t need to enter any contours.")
                    .font(.caption)
                    .foregroundStyle(OverParTheme.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 290)
            }
            .padding(28)
            .background(
                Color.white.opacity(0.9),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white, lineWidth: 1))
            .shadow(color: .black.opacity(0.16), radius: 28, y: 12)
            .padding(24)
        }
        .onAppear { animateContours = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reading the course landscape. \(status)")
    }
}
