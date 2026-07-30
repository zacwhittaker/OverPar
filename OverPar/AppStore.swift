import CoreLocation
import Foundation
import UIKit

private enum ClubDistanceFamily: Hashable {
    case teeWood
    case fairwayWood
    case hybrid
    case utilityIron
    case iron
    case wedge
}

private struct FamilyCarryModel {
    var scaleMetres: Double
    var credibleClubIDs: Set<UUID>
}

private struct OpenMeteoPlayingResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let wind_speed_10m: Double
        let wind_direction_10m: Double
    }
    struct Daily: Decodable {
        let temperature_2m_max: [Double]
        let precipitation_sum: [Double]
        let et0_fao_evapotranspiration: [Double]
    }
    let current: Current
    let daily: Daily
}

@MainActor
final class AppStore: ObservableObject {
    @Published var profile: UserProfile { didSet { persist() } }
    @Published var courses: [GolfCourse] { didSet { persist() } }
    @Published var clubs: [GolfClub] { didSet { persist() } }
    @Published var rangeHits: [RangeHit] { didSet { persist() } }
    @Published var gallery: [GalleryItem] { didSet { persist() } }
    @Published var activeRound: ActiveRound? { didSet { persist() } }
    @Published var completedRounds: [CompletedRound] { didSet { persist() } }
    @Published private(set) var playingConditions: PlayingConditions?

    private let saveURL: URL
    private var isLoading = true

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OverPar", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        saveURL = directory.appendingPathComponent("release-1.0.json")

        if let data = try? Data(contentsOf: saveURL),
           let saved = try? JSONDecoder().decode(AppData.self, from: data) {
            profile = saved.profile
            courses = saved.courses
            clubs = saved.clubs
            rangeHits = saved.rangeHits
            gallery = saved.gallery
            activeRound = saved.activeRound
            completedRounds = saved.completedRounds ?? []
            playingConditions = nil
            removeReleaseOneDemoHitsIfNeeded()
            removeReleaseOneDemoCourseIfNeeded()
            normalizeStoredCourseCoversIfNeeded()
        } else {
            let seed = Self.seedData()
            profile = seed.profile
            courses = seed.courses
            clubs = seed.clubs
            rangeHits = seed.rangeHits
            gallery = seed.gallery
            activeRound = nil
            completedRounds = seed.completedRounds ?? []
            playingConditions = nil
        }
        isLoading = false
        persist()
    }

    var activeBag: [GolfClub] { clubs.filter(\.isActive) }

    func publishCourse(
        name: String,
        facility: String,
        city: String,
        postcode: String,
        holes: [Hole],
        loopCount: Int = 1,
        coverPhotoData: Data? = nil
    ) {
        var course = GolfCourse(
            name: name,
            facilityName: facility.isEmpty ? name : facility,
            city: city,
            postcode: postcode,
            isVerified: false,
            isSaved: true,
            currentRevision: CourseRevision(revisionNumber: 1, holes: holes),
            defaultLoopCount: loopCount,
            createdByCurrentUser: true,
            creatorUsername: profile.username
        )
        course.coverPhotoFilename = saveCourseCover(coverPhotoData, courseID: course.id)
        courses.append(course)
    }

    func updateCourse(
        courseID: UUID,
        name: String,
        facility: String,
        city: String,
        postcode: String,
        holes: [Hole],
        loopCount: Int,
        coverPhotoData: Data?
    ) {
        guard let index = courses.firstIndex(where: { $0.id == courseID }),
              courses[index].canCurrentUserEdit
        else { return }
        var course = courses[index]
        course.name = name
        course.facilityName = facility.isEmpty ? name : facility
        course.city = city
        course.postcode = postcode
        course.defaultLoopCount = loopCount
        course.createdByCurrentUser = true
        course.currentRevision = CourseRevision(
            revisionNumber: course.currentRevision.revisionNumber + 1,
            holes: holes
        )
        if let coverPhotoData {
            course.coverPhotoFilename = saveCourseCover(coverPhotoData, courseID: course.id)
        }
        courses[index] = course
    }

    func updateCourseDetails(
        courseID: UUID,
        name: String,
        facility: String,
        city: String,
        postcode: String,
        coverPhotoData: Data?,
        useDefaultCover: Bool
    ) {
        guard let index = courses.firstIndex(where: { $0.id == courseID }),
              courses[index].canCurrentUserEdit
        else { return }
        var course = courses[index]
        course.name = name
        course.facilityName = facility.isEmpty ? name : facility
        course.city = city
        course.postcode = postcode
        course.createdByCurrentUser = true
        course.creatorUsername = course.creatorUsername ?? profile.username
        if useDefaultCover {
            if let filename = course.coverPhotoFilename {
                try? FileManager.default.removeItem(at: courseCoverDirectory.appendingPathComponent(filename))
            }
            course.coverPhotoFilename = nil
        } else if let coverPhotoData {
            course.coverPhotoFilename = saveCourseCover(coverPhotoData, courseID: course.id)
        }
        courses[index] = course
    }

    func courseCoverData(for course: GolfCourse) -> Data? {
        guard let filename = course.coverPhotoFilename else { return nil }
        return try? Data(contentsOf: courseCoverDirectory.appendingPathComponent(filename))
    }

    private var courseCoverDirectory: URL {
        let directory = saveURL.deletingLastPathComponent().appendingPathComponent("CourseCovers", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func saveCourseCover(_ data: Data?, courseID: UUID) -> String? {
        guard let data else { return nil }
        let filename = "\(courseID.uuidString).jpg"
        do {
            try data.write(to: courseCoverDirectory.appendingPathComponent(filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    @discardableResult
    func publishTerrainRevision(courseID: UUID, holes: [Hole]) -> GolfCourse? {
        guard let index = courses.firstIndex(where: { $0.id == courseID }) else { return nil }
        var course = courses[index]
        course.currentRevision = CourseRevision(
            revisionNumber: course.currentRevision.revisionNumber + 1,
            holes: holes
        )
        courses[index] = course
        return course
    }

    func startRound(course: GolfCourse, format: RoundFormat, rulesCompliant: Bool, loopCount: Int) {
        activeRound = ActiveRound(
            courseID: course.id,
            courseRevisionID: course.currentRevision.id,
            format: format,
            rulesCompliant: rulesCompliant,
            selectedLoopCount: loopCount
        )
    }

    @discardableResult
    func endRound(save: Bool) -> CompletedRound? {
        guard let round = activeRound else { return nil }
        defer { activeRound = nil }
        guard save, let course = courses.first(where: { $0.id == round.courseID }) else {
            return nil
        }
        let completed = CompletedRound(
            courseID: round.courseID,
            courseRevisionID: round.courseRevisionID,
            courseName: course.name,
            format: round.format,
            scores: round.scores,
            shots: round.shots,
            selectedLoopCount: round.selectedLoopCount,
            startedAt: round.startedAt
        )
        completedRounds.append(completed)
        return completed
    }

    func addRangeHit(clubID: UUID, displayedDistance: Double, kind: DistanceKind, mishit: Bool) {
        let metres = profile.units == "yards" ? displayedDistance * 0.9144 : displayedDistance
        rangeHits.append(
            RangeHit(
                clubID: clubID,
                metres: metres,
                kind: kind,
                isMishit: mishit,
                source: .drivingRange
            )
        )
    }

    func recordOnCourseShot(_ shot: LoggedShot) {
        guard let clubID = shot.clubID, let start = shot.start, let end = shot.end else { return }
        let metres = CLLocation(
            latitude: start.latitude,
            longitude: start.longitude
        ).distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
        guard metres >= 1 else { return }
        let poorStrike = shot.strike.map { $0 != .solid } ?? false
        rangeHits.append(
            RangeHit(
                clubID: clubID,
                metres: metres,
                kind: .total,
                isMishit: poorStrike,
                source: .onCourseGPS
            )
        )
    }

    func stats(for club: GolfClub, kind: DistanceKind = .carry) -> (average: Double, playing: Double, low: Double, high: Double, maximum: Double, count: Int)? {
        let valid = rangeHits.filter {
            $0.clubID == club.id && $0.kind == kind && !$0.isMishit && !$0.isPartial
        }.map(\.metres).sorted()
        guard !valid.isEmpty else { return nil }
        let mean = valid.reduce(0, +) / Double(valid.count)
        let median = valid[valid.count / 2]
        let low = percentile(valid, 0.2)
        let high = percentile(valid, 0.8)
        return convert((mean, median, low, high, valid.last ?? mean, valid.count))
    }

    func carryInsight(for club: GolfClub) -> ClubCarryInsight {
        let measured = statsInMetres(for: club)
        let estimate = estimatedCarryMetres(for: club)
        let threshold = estimate.map { max(8.25, $0 * 0.18) }
        let isAnomaly = measured != nil && estimate != nil && threshold != nil
            ? abs(measured! - estimate!) > threshold!
            : false
        let anchorCount = familyProfile(for: club)
            .flatMap { familyModel(for: $0.family)?.credibleClubIDs.count } ?? 0
        return ClubCarryInsight(
            estimatedMetres: estimate,
            isEstimate: measured == nil && estimate != nil,
            isPossibleAnomaly: isAnomaly,
            anchorCount: anchorCount
        )
    }

    func recommendedClub(
        distanceMetres: Double,
        hole: Hole? = nil,
        player: Coordinate? = nil
    ) -> ClubRecommendation? {
        if activeRound?.rulesCompliant == true { return nil }
        let adjustedTarget = adjustedPlayingDistance(
            rawDistanceMetres: distanceMetres,
            hole: hole,
            player: player
        )
        var carryOptions = activeBag
            .filter { $0.category != .putter && $0.category != .chipper }
            .compactMap { club -> ClubRecommendation? in
                let insight = carryInsight(for: club)
                if let measured = statsInMetres(for: club), !insight.isPossibleAnomaly {
                    return ClubRecommendation(club: club, carryMetres: measured, isEstimated: false)
                }
                if let playingDistance = onCourseDistanceMetres(for: club) {
                    return ClubRecommendation(club: club, carryMetres: playingDistance, isEstimated: true)
                }
                if let estimated = insight.estimatedMetres {
                    return ClubRecommendation(club: club, carryMetres: estimated, isEstimated: true)
                }
                return nil
            }
        if adjustedTarget <= 110 {
            let approachOptions = carryOptions.filter {
                switch $0.club.category {
                case .iron, .pitchingWedge, .gapWedge, .sandWedge, .lobWedge:
                    return true
                default:
                    return false
                }
            }
            if !approachOptions.isEmpty {
                carryOptions = approachOptions
            }
        }
        guard !carryOptions.isEmpty else { return nil }

        let slopeRatio = targetSlopeRatio(
            rawDistanceMetres: distanceMetres,
            hole: hole,
            player: player
        )
        let terrainTrend = targetTerrainTrend(hole: hole)
        let landingSlope = landingSlopeRatio(hole: hole)
        let elevationChange = slopeRatio * distanceMetres
        // An iron lay-up is exceptional: require a genuinely material slope
        // and start from a golfer-specific longest-iron + 100-yard window.
        // Slope severity may widen that window conservatively below.
        let significantUphill = elevationChange >= 4
            || slopeRatio >= 0.015
            || (terrainTrend == .uphill && elevationChange >= 2)
        let significantDownhill = elevationChange <= -4
            || slopeRatio <= -0.015
            || (terrainTrend == .downhill && elevationChange <= -2)
        let materiallySloped = significantUphill || significantDownhill
        let longestAvailableCarry = carryOptions.map(\.carryMetres).max() ?? 0
        let targetIsUnreachable = adjustedTarget > longestAvailableCarry * 1.08
        let controlledIronOptions = carryOptions.filter {
            $0.club.category == .iron || $0.club.category == .utilityIron
        }
        let longestIronCarry = controlledIronOptions.map(\.carryMetres).max()
        // Steeper shots need a wider controlled-club window. Add 15 yards for
        // each percentage point of absolute grade, capped at 60 yards, on top
        // of the golfer-specific iron + 100 yard baseline.
        let terrainAllowanceYards = min(60, abs(slopeRatio) * 100 * 15)
        let terrainAllowanceMetres = terrainAllowanceYards / 1.09361
        let isWithinIronLayUpWindow = longestIronCarry.map {
            distanceMetres <= $0 + 91.44 + terrainAllowanceMetres
        } ?? false

        // Prefer the shortest suitable carry that reaches the elevation-adjusted
        // target. Rollout is reported separately and never substituted for carry
        // when the shot must reach or hold a green.
        let selected: ClubRecommendation?
        if materiallySloped, isWithinIronLayUpWindow,
           targetIsUnreachable, !controlledIronOptions.isEmpty {
            // Club order is the stronger signal when sparse/noisy observations
            // invert normal iron gapping. Prefer the lowest-numbered standard
            // iron in the active bag (5 before 6 before 7), then fall back to
            // credible carry for unnumbered/utility irons.
            let numberedIrons = controlledIronOptions.compactMap { option -> (Int, ClubRecommendation)? in
                guard option.club.category == .iron,
                      let number = clubNumber(for: option.club)
                else { return nil }
                return (number, option)
            }
            selected = numberedIrons.min(by: { $0.0 < $1.0 })?.1
                ?? controlledIronOptions.max(by: { $0.carryMetres < $1.carryMetres })
        } else {
            // A green recommendation must account for release as well as carry.
            // Prefer the closest expected finish, with an additional penalty
            // for running beyond the target. This prevents firm-ground advice
            // from selecting a club whose displayed outcome contradicts the
            // distance the golfer is trying to cover.
            selected = carryOptions.min { lhs, rhs in
                let lhsRoll = estimatedRoll(
                    carryMetres: lhs.carryMetres,
                    club: lhs.club,
                    hole: hole,
                    player: player,
                    rawDistanceMetres: distanceMetres,
                    targetSlopeRatio: slopeRatio
                )
                let rhsRoll = estimatedRoll(
                    carryMetres: rhs.carryMetres,
                    club: rhs.club,
                    hole: hole,
                    player: player,
                    rawDistanceMetres: distanceMetres,
                    targetSlopeRatio: slopeRatio
                )
                let lhsFinish = lhs.carryMetres + lhsRoll
                let rhsFinish = rhs.carryMetres + rhsRoll
                let lhsOvershoot = max(0, lhsFinish - adjustedTarget)
                let rhsOvershoot = max(0, rhsFinish - adjustedTarget)
                let lhsCost = abs(lhsFinish - adjustedTarget) + lhsOvershoot * 0.75
                let rhsCost = abs(rhsFinish - adjustedTarget) + rhsOvershoot * 0.75
                return lhsCost < rhsCost
            }
        }
        guard var recommendation = selected else { return nil }
        recommendation.adjustedTargetMetres = adjustedTarget
        recommendation.estimatedRollMetres = estimatedRoll(
            carryMetres: recommendation.carryMetres,
            club: recommendation.club,
            hole: hole,
            player: player,
            rawDistanceMetres: distanceMetres,
            targetSlopeRatio: slopeRatio
        )
        let groundSummary = conditionsSummary(
            hole: hole,
            elevationChangeMetres: elevationChange,
            slopeRatio: slopeRatio,
            terrainTrend: terrainTrend,
            landingSlope: landingSlope
        )
        if materiallySloped, isWithinIronLayUpWindow, targetIsUnreachable,
           recommendation.club.category == .iron || recommendation.club.category == .utilityIron {
            recommendation.conditionsSummary = [groundSummary, "Controlled Iron Lay-Up"]
                .compactMap { $0 }
                .joined(separator: " · ")
        } else {
            recommendation.conditionsSummary = groundSummary
        }
        return recommendation
    }

    private func clubNumber(for club: GolfClub) -> Int? {
        club.name
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init)
            .first
    }

    private enum TargetTerrainTrend {
        case uphill
        case downhill
        case mixedOrFlat
    }

    private func targetTerrainTrend(hole: Hole?) -> TargetTerrainTrend {
        guard let samples = hole?.terrainProfile?.samples.sorted(by: {
            $0.fractionAlongHole < $1.fractionAlongHole
        }), samples.count >= 4 else { return .mixedOrFlat }

        // Smooth neighbouring DEM points before classifying direction. At the
        // 100-point resolution, raw adjacent samples are closer together than
        // the source raster and otherwise repeat/jump at cell boundaries.
        let radius = max(1, samples.count / 40)
        let smoothed = samples.indices.map { index -> Double in
            let lower = max(0, index - radius)
            let upper = min(samples.count - 1, index + radius)
            let values = samples[lower...upper].map(\.elevationMetres)
            return values.reduce(0, +) / Double(values.count)
        }
        var uphillSteps = 0
        var downhillSteps = 0
        for pair in zip(smoothed, smoothed.dropFirst()) {
            let change = pair.1 - pair.0
            if change > 0.06 { uphillSteps += 1 }
            if change < -0.06 { downhillSteps += 1 }
        }
        let directionalSteps = uphillSteps + downhillSteps
        let endpointWindow = min(5, samples.count / 2)
        let startElevation = smoothed.prefix(endpointWindow).reduce(0, +) / Double(endpointWindow)
        let endElevation = smoothed.suffix(endpointWindow).reduce(0, +) / Double(endpointWindow)
        guard directionalSteps > 0,
              abs(endElevation - startElevation) >= 1.5
        else { return .mixedOrFlat }

        if Double(uphillSteps) / Double(directionalSteps) >= 0.7 { return .uphill }
        if Double(downhillSteps) / Double(directionalSteps) >= 0.7 { return .downhill }
        return .mixedOrFlat
    }

    private func targetSlopeRatio(
        rawDistanceMetres: Double,
        hole: Hole?,
        player: Coordinate?
    ) -> Double {
        guard rawDistanceMetres > 1,
              let hole,
              let profile = hole.terrainProfile,
              let greenElevation = profile.greenElevationMetres,
              let originElevation = interpolatedElevation(profile: profile, hole: hole, player: player)
                ?? profile.teeElevationMetres
        else { return 0 }
        return (greenElevation - originElevation) / rawDistanceMetres
    }

    private func adjustedPlayingDistance(
        rawDistanceMetres: Double,
        hole: Hole?,
        player: Coordinate?
    ) -> Double {
        guard let hole, let profile = hole.terrainProfile,
              let greenElevation = profile.greenElevationMetres
        else { return rawDistanceMetres }
        let playerElevation = interpolatedElevation(profile: profile, hole: hole, player: player)
            ?? profile.teeElevationMetres
        guard let playerElevation else { return rawDistanceMetres }
        let elevationChange = greenElevation - playerElevation
        return max(1, rawDistanceMetres + elevationChange)
    }

    private func estimatedRoll(
        carryMetres: Double,
        club: GolfClub,
        hole: Hole?,
        player: Coordinate?,
        rawDistanceMetres: Double,
        targetSlopeRatio: Double
    ) -> Double {
        let baseRatio: Double
        switch club.category {
        case .driver, .miniDriver: baseRatio = 0.105
        case .fairwayWood: baseRatio = 0.08
        case .hybrid: baseRatio = 0.062
        case .utilityIron: baseRatio = 0.052
        case .iron:
            switch clubNumber(for: club) {
            case let number? where number <= 5: baseRatio = 0.055
            case 6: baseRatio = 0.048
            case 7: baseRatio = 0.04
            case 8: baseRatio = 0.03
            case 9: baseRatio = 0.022
            default: baseRatio = 0.04
            }
        case .pitchingWedge, .gapWedge, .sandWedge, .lobWedge: baseRatio = 0.012
        case .chipper: baseRatio = 0.07
        case .putter, .custom: baseRatio = 0.03
        }
        let firmnessMultiplier: Double
        switch playingConditions?.firmness {
        case .soft: firmnessMultiplier = 0.25
        case .firm: firmnessMultiplier = 1.45
        case .veryFirm: firmnessMultiplier = 2.15
        case .normal, .none: firmnessMultiplier = 1
        }
        let predictedLandingSlope = predictedLandingSlopeRatio(
            hole: hole,
            player: player,
            carryMetres: carryMetres,
            rawDistanceMetres: rawDistanceMetres
        )
        // Use the terrain where this club is predicted to land—not the terrain
        // beside the green. Downhill rollout grows nonlinearly once gravity
        // overcomes turf resistance, particularly on firm ground.
        var effectiveRollSlope = predictedLandingSlope * 0.75 + targetSlopeRatio * 0.25
        if playingConditions?.firmness == .veryFirm, targetSlopeRatio <= -0.02 {
            // A single locally flatter DEM window must not erase the sustained
            // gravitational release visible across a materially downhill,
            // baked-out shot. Retain most of the whole-shot downhill grade as
            // a minimum input; soft/normal ground deliberately gets no floor.
            effectiveRollSlope = min(effectiveRollSlope, targetSlopeRatio * 0.8)
        }
        let slopeMultiplier: Double
        if effectiveRollSlope < 0 {
            slopeMultiplier = 1 + min(8, abs(effectiveRollSlope) * 220)
        } else {
            slopeMultiplier = max(0.15, 1 - effectiveRollSlope * 28)
        }
        return max(0, carryMetres * baseRatio * firmnessMultiplier * slopeMultiplier)
    }

    private func predictedLandingSlopeRatio(
        hole: Hole?,
        player: Coordinate?,
        carryMetres: Double,
        rawDistanceMetres: Double
    ) -> Double {
        guard let hole,
              let profile = hole.terrainProfile,
              profile.samples.count >= 8,
              rawDistanceMetres > 1
        else { return 0 }
        let originFraction = playerFraction(on: hole, player: player)
        let remainingFraction = max(0, 1 - originFraction)
        let landingFraction = min(
            1,
            originFraction + remainingFraction * min(1, carryMetres / rawDistanceMetres)
        )
        let ordered = profile.samples.sorted { $0.fractionAlongHole < $1.fractionAlongHole }
        let radius = 0.06
        let local = ordered.filter {
            abs($0.fractionAlongHole - landingFraction) <= radius
        }
        guard local.count >= 3, let start = local.first, let end = local.last else { return 0 }
        let edgeCount = min(3, max(1, local.count / 3))
        let startElevation = local.prefix(edgeCount).map(\.elevationMetres).reduce(0, +)
            / Double(edgeCount)
        let endElevation = local.suffix(edgeCount).map(\.elevationMetres).reduce(0, +)
            / Double(edgeCount)
        let horizontal = CLLocation(
            latitude: start.coordinate.latitude,
            longitude: start.coordinate.longitude
        ).distance(from: CLLocation(
            latitude: end.coordinate.latitude,
            longitude: end.coordinate.longitude
        ))
        guard horizontal > 1 else { return 0 }
        return (endElevation - startElevation) / horizontal
    }

    private func playerFraction(on hole: Hole, player: Coordinate?) -> Double {
        guard let player, let tee = hole.tee, let green = hole.greenReference else { return 0 }
        let dx = green.longitude - tee.longitude
        let dy = green.latitude - tee.latitude
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return 0 }
        return max(0, min(1,
            ((player.longitude - tee.longitude) * dx + (player.latitude - tee.latitude) * dy)
                / lengthSquared
        ))
    }

    private func landingSlopeRatio(hole: Hole?) -> Double {
        guard let samples = hole?.terrainProfile?.samples.sorted(by: {
            $0.fractionAlongHole < $1.fractionAlongHole
        }), samples.count >= 3 else { return 0 }
        // Average the beginning/end of the final 15% of the hole. This is much
        // less sensitive to one DEM cell than comparing two individual points.
        let landingCount = max(3, Int((Double(samples.count) * 0.15).rounded()))
        let landing = Array(samples.suffix(landingCount))
        let averageCount = min(4, max(1, landing.count / 3))
        let startElevation = landing.prefix(averageCount).map(\.elevationMetres).reduce(0, +)
            / Double(averageCount)
        let endElevation = landing.suffix(averageCount).map(\.elevationMetres).reduce(0, +)
            / Double(averageCount)
        guard let start = landing.first, let end = landing.last else { return 0 }
        let horizontal = CLLocation(
            latitude: start.coordinate.latitude,
            longitude: start.coordinate.longitude
        ).distance(from: CLLocation(
            latitude: end.coordinate.latitude,
            longitude: end.coordinate.longitude
        ))
        guard horizontal > 1 else { return 0 }
        return (endElevation - startElevation) / horizontal
    }

    private func interpolatedElevation(
        profile: HoleTerrainProfile,
        hole: Hole,
        player: Coordinate?
    ) -> Double? {
        guard let player, let tee = hole.tee, let green = hole.greenReference,
              profile.samples.count >= 2
        else { return nil }
        let dx = green.longitude - tee.longitude
        let dy = green.latitude - tee.latitude
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return profile.teeElevationMetres }
        let fraction = max(0, min(1,
            ((player.longitude - tee.longitude) * dx + (player.latitude - tee.latitude) * dy)
                / lengthSquared
        ))
        let scaled = fraction * Double(profile.samples.count - 1)
        let lower = Int(scaled.rounded(.down))
        let upper = min(profile.samples.count - 1, lower + 1)
        let weight = scaled - Double(lower)
        return profile.samples[lower].elevationMetres * (1 - weight)
            + profile.samples[upper].elevationMetres * weight
    }

    private func conditionsSummary(
        hole: Hole?,
        elevationChangeMetres: Double,
        slopeRatio: Double,
        terrainTrend: TargetTerrainTrend,
        landingSlope: Double
    ) -> String? {
        guard hole?.terrainProfile != nil else { return nil }
        let ground = playingConditions.map { "Estimated \($0.firmness.rawValue.lowercased()) ground" }
            ?? "Weather Unavailable"
        let grade = abs(slopeRatio) * 100
        let terrain: String
        if elevationChangeMetres >= 1.5
            || slopeRatio >= 0.006
            || (terrainTrend == .uphill && elevationChangeMetres >= 1) {
            terrain = "Climbs \(Int(abs(elevationChangeMetres).rounded())) m"
        } else if elevationChangeMetres <= -1.5
                    || slopeRatio <= -0.006
                    || (terrainTrend == .downhill && elevationChangeMetres <= -1) {
            terrain = "Drops \(Int(abs(elevationChangeMetres).rounded())) m"
        } else if landingSlope >= 0.03 {
            terrain = "Uphill landing"
        } else if landingSlope <= -0.03 {
            terrain = "Downhill landing"
        } else {
            terrain = "Near level"
        }
        return "\(ground) · \(terrain)"
    }

    func onCourseDistance(for club: GolfClub) -> (distance: Double, count: Int)? {
        let values = validOnCourseValues(for: club)
        guard !values.isEmpty else { return nil }
        let factor = profile.units == "yards" ? 1.09361 : 1
        return (values[values.count / 2] * factor, values.count)
    }

    func refreshPlayingConditions(at coordinate: Coordinate) async {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.6f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.6f", coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,precipitation_sum,et0_fao_evapotranspiration"),
            URLQueryItem(name: "past_days", value: "7"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components?.url else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode)
            else { return }
            let decoded = try JSONDecoder().decode(OpenMeteoPlayingResponse.self, from: data)
            let rain = decoded.daily.precipitation_sum.reduce(0, +)
            let drying = decoded.daily.et0_fao_evapotranspiration.reduce(0, +)
            let hotDays = decoded.daily.temperature_2m_max.filter { $0 >= 24 }.count
            let balance = drying - rain
            let firmness: PlayingConditions.Firmness
            if rain >= 18 || balance <= -10 {
                firmness = .soft
            } else if balance >= 20 && hotDays >= 3 {
                firmness = .veryFirm
            } else if balance >= 8 {
                firmness = .firm
            } else {
                firmness = .normal
            }
            playingConditions = PlayingConditions(
                fetchedAt: Date(),
                temperatureCelsius: decoded.current.temperature_2m,
                windSpeedKPH: decoded.current.wind_speed_10m,
                windDirectionDegrees: decoded.current.wind_direction_10m,
                sevenDayRainMM: rain,
                sevenDayEvapotranspirationMM: drying,
                recentHotDays: hotDays,
                firmness: firmness,
                confidence: "Weather-based estimate · irrigation and mowing unknown"
            )
        } catch {
            // Raw GPS distance and carry recommendations remain available.
        }
    }

    func moveClubs(from offsets: IndexSet, to destination: Int) {
        let moving = offsets.sorted().map { clubs[$0] }
        for index in offsets.sorted(by: >) {
            clubs.remove(at: index)
        }
        let removedBeforeDestination = offsets.filter { $0 < destination }.count
        clubs.insert(contentsOf: moving, at: max(0, min(destination - removedBeforeDestination, clubs.count)))
    }

    func deleteClubs(at offsets: IndexSet) {
        let deletedIDs = Set(offsets.map { clubs[$0].id })
        for index in offsets.sorted(by: >) {
            clubs.remove(at: index)
        }
        rangeHits.removeAll { deletedIDs.contains($0.clubID) }
    }

    func addGalleryVideo(
        filename: String,
        courseName: String?,
        hole: Int?,
        tracePoints: [GalleryItem.TracePoint] = [],
        observedPointCount: Int = 0
    ) {
        let status: String
        if observedPointCount >= 3 {
            status = "Live trace ready"
        } else {
            status = "Original saved · trace not found"
        }
        gallery.insert(
            GalleryItem(
                title: "Recorded shot",
                localVideoFilename: filename,
                courseName: courseName,
                holeNumber: hole,
                tracerStatus: status,
                tracePoints: tracePoints,
                observedPointCount: observedPointCount
            ),
            at: 0
        )
    }

    @discardableResult
    func deleteGalleryItem(id: UUID) -> Bool {
        guard let index = gallery.firstIndex(where: { $0.id == id }) else { return false }
        let item = gallery[index]
        if let filename = item.localVideoFilename {
            let safeFilename = URL(fileURLWithPath: filename).lastPathComponent
            let videoURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Gallery", isDirectory: true)
                .appendingPathComponent(safeFilename)
            if FileManager.default.fileExists(atPath: videoURL.path) {
                do {
                    try FileManager.default.removeItem(at: videoURL)
                } catch {
                    return false
                }
            }
        }
        gallery.remove(at: index)
        return true
    }

    private func statsInMetres(for club: GolfClub) -> Double? {
        let values = rangeHits.filter {
            $0.clubID == club.id && $0.kind == .carry && !$0.isMishit && !$0.isPartial
        }.map(\.metres).sorted()
        guard !values.isEmpty else { return nil }
        return values[values.count / 2]
    }

    private func onCourseDistanceMetres(for club: GolfClub) -> Double? {
        let values = validOnCourseValues(for: club)
        return values.isEmpty ? nil : values[values.count / 2]
    }

    private func validOnCourseValues(for club: GolfClub) -> [Double] {
        rangeHits.filter {
            $0.clubID == club.id
                && $0.kind == .total
                && $0.observationSource == .onCourseGPS
                && !$0.isMishit
                && !$0.isPartial
        }.map(\.metres).sorted()
    }

    private func estimatedCarryMetres(for club: GolfClub) -> Double? {
        guard let profile = familyProfile(for: club),
              let model = familyModel(for: profile.family)
        else { return nil }
        return profile.index * model.scaleMetres
    }

    private func familyModel(for family: ClubDistanceFamily) -> FamilyCarryModel? {
        let observations = activeBag.compactMap { club -> (club: GolfClub, index: Double, carry: Double, count: Int)? in
            guard let profile = familyProfile(for: club),
                  profile.family == family,
                  let carry = statsInMetres(for: club)
            else { return nil }
            let count = validCarryValues(for: club).count
            return (club, profile.index, carry, count)
        }
        guard let strongest = observations.max(by: { $0.carry < $1.carry }) else { return nil }

        // Start with the strongest robust playing carry in this family. A shorter
        // contradictory observation cannot drag the entire curve down.
        let provisionalScale = strongest.carry / strongest.index
        let credible = observations.filter { observation in
            if observation.club.id == strongest.club.id { return true }
            let expected = observation.index * provisionalScale
            return abs(observation.carry - expected) <= max(8.25, expected * 0.18)
        }

        // Consistent clubs refine the benchmark. Repeating ratios by capped sample
        // count gives better-calibrated clubs more influence without domination.
        let weightedScales = credible.flatMap { observation in
            Array(repeating: observation.carry / observation.index, count: max(1, min(observation.count, 10)))
        }.sorted()
        let scale = weightedScales[weightedScales.count / 2]
        return FamilyCarryModel(
            scaleMetres: scale,
            credibleClubIDs: Set(credible.map(\.club.id))
        )
    }

    private func validCarryValues(for club: GolfClub) -> [Double] {
        rangeHits.filter {
            $0.clubID == club.id && $0.kind == .carry && !$0.isMishit && !$0.isPartial
        }.map(\.metres).sorted()
    }

    private func familyProfile(for club: GolfClub) -> (family: ClubDistanceFamily, index: Double)? {
        let number = club.name
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init)
            .first

        switch club.category {
        case .driver:
            return (.teeWood, loftAdjusted(base: 1.00, nominalLoft: 10.5, actualLoft: club.loft, changePerDegree: 0.012))
        case .miniDriver:
            return (.teeWood, loftAdjusted(base: 0.95, nominalLoft: 13.5, actualLoft: club.loft, changePerDegree: 0.012))
        case .fairwayWood:
            let profiles: [Int: (Double, Double)] = [
                3: (0.90, 15), 4: (0.87, 17), 5: (0.84, 19),
                7: (0.78, 22), 9: (0.72, 25), 11: (0.66, 28), 13: (0.60, 31)
            ]
            guard let value = profiles[number ?? 3] else { return nil }
            return (.fairwayWood, loftAdjusted(base: value.0, nominalLoft: value.1, actualLoft: club.loft, changePerDegree: 0.015))
        case .hybrid:
            guard let clubNumber = number, (1...9).contains(clubNumber) else { return nil }
            let base = 0.99 - Double(clubNumber) * 0.05
            let nominalLoft = 13 + Double(clubNumber) * 3
            return (.hybrid, loftAdjusted(base: base, nominalLoft: nominalLoft, actualLoft: club.loft, changePerDegree: 0.016))
        case .utilityIron:
            guard let clubNumber = number, (1...6).contains(clubNumber) else { return nil }
            let base = 0.99 - Double(clubNumber) * 0.05
            let nominalLoft = 14 + Double(clubNumber) * 3
            return (.utilityIron, loftAdjusted(base: base, nominalLoft: nominalLoft, actualLoft: club.loft, changePerDegree: 0.016))
        case .iron:
            guard let clubNumber = number, (1...9).contains(clubNumber) else { return nil }
            let base = 0.99 - Double(clubNumber) * 0.05
            let nominalLofts: [Int: Double] = [1: 16, 2: 18, 3: 20, 4: 23, 5: 26, 6: 29, 7: 33, 8: 37, 9: 41]
            return (.iron, loftAdjusted(base: base, nominalLoft: nominalLofts[clubNumber]!, actualLoft: club.loft, changePerDegree: 0.0125))
        case .pitchingWedge:
            return (.wedge, loftAdjusted(base: 0.50, nominalLoft: 46, actualLoft: club.loft, changePerDegree: 0.008))
        case .gapWedge:
            return (.wedge, loftAdjusted(base: 0.46, nominalLoft: 51, actualLoft: club.loft, changePerDegree: 0.008))
        case .sandWedge:
            return (.wedge, loftAdjusted(base: 0.42, nominalLoft: 56, actualLoft: club.loft, changePerDegree: 0.008))
        case .lobWedge:
            return (.wedge, loftAdjusted(base: 0.39, nominalLoft: 60, actualLoft: club.loft, changePerDegree: 0.008))
        case .chipper, .putter, .custom:
            return nil
        }
    }

    private func loftAdjusted(
        base: Double,
        nominalLoft: Double,
        actualLoft: Double?,
        changePerDegree: Double
    ) -> Double {
        guard let actualLoft else { return base }
        return max(0.2, base + (nominalLoft - actualLoft) * changePerDegree)
    }

    private func convert(_ values: (Double, Double, Double, Double, Double, Int)) -> (Double, Double, Double, Double, Double, Int) {
        let factor = profile.units == "yards" ? 1.09361 : 1
        return (values.0 * factor, values.1 * factor, values.2 * factor, values.3 * factor, values.4 * factor, values.5)
    }

    private func percentile(_ values: [Double], _ fraction: Double) -> Double {
        guard values.count > 1 else { return values[0] }
        let position = fraction * Double(values.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        let weight = position - Double(lower)
        return values[lower] * (1 - weight) + values[upper] * weight
    }

    private func persist() {
        guard !isLoading else { return }
        let value = AppData(
            profile: profile,
            courses: courses,
            clubs: clubs,
            rangeHits: rangeHits,
            gallery: gallery,
            activeRound: activeRound,
            completedRounds: completedRounds
        )
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func removeReleaseOneDemoHitsIfNeeded() {
        let migrationKey = "overpar.migrations.removedReleaseOneDemoRangeHits"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        rangeHits.removeAll()
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    private func removeReleaseOneDemoCourseIfNeeded() {
        let migrationKey = "overpar.migrations.removedRoyalMeadowDemoCourse"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let demoIDs = Set(courses.filter {
            $0.name == "Royal Meadow"
                && $0.facilityName == "Royal Meadow Golf Club"
                && $0.city == "Leeds"
                && $0.postcode == "LS1"
        }.map(\.id))

        courses.removeAll { demoIDs.contains($0.id) }
        if let homeCourseID = profile.homeCourseID, demoIDs.contains(homeCourseID) {
            profile.homeCourseID = nil
        }
        if let courseID = activeRound?.courseID, demoIDs.contains(courseID) {
            activeRound = nil
        }
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    private func normalizeStoredCourseCoversIfNeeded() {
        for course in courses {
            guard let filename = course.coverPhotoFilename else { continue }
            let url = courseCoverDirectory.appendingPathComponent(filename)
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data),
                  image.size != CGSize(width: 1600, height: 900),
                  let normalized = CourseCoverProcessor.prepare(data)
            else { continue }
            try? normalized.write(to: url, options: .atomic)
        }
    }

    private static func seedData() -> AppData {
        let clubs = [
            GolfClub(category: .driver, name: "Driver"),
            GolfClub(category: .fairwayWood, name: "5 Wood"),
            GolfClub(category: .iron, name: "7 Iron"),
            GolfClub(category: .pitchingWedge, name: "Pitching Wedge"),
            GolfClub(category: .putter, name: "Putter")
        ]
        return AppData(
            profile: UserProfile(),
            courses: [],
            clubs: clubs,
            rangeHits: [],
            gallery: [],
            activeRound: nil,
            completedRounds: []
        )
    }
}
