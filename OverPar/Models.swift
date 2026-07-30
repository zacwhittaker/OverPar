import CoreLocation
import Foundation

struct Coordinate: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double?
    var capturedAt: Date?

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TerrainSample: Codable, Hashable {
    var fractionAlongHole: Double
    var coordinate: Coordinate
    var elevationMetres: Double
}

struct HoleTerrainProfile: Codable, Hashable {
    var source: String
    var fetchedAt: Date
    var samples: [TerrainSample]

    var teeElevationMetres: Double? { samples.first?.elevationMetres }
    var greenElevationMetres: Double? { samples.last?.elevationMetres }
    var elevationChangeMetres: Double? {
        guard let teeElevationMetres, let greenElevationMetres else { return nil }
        return greenElevationMetres - teeElevationMetres
    }
}

struct Hole: Codable, Identifiable, Hashable {
    var id = UUID()
    var number: Int
    var par: Int
    var tee: Coordinate?
    var greenReference: Coordinate?
    var terrainProfile: HoleTerrainProfile?
}

struct CourseRevision: Codable, Identifiable, Hashable {
    var id = UUID()
    var revisionNumber: Int
    var createdAt = Date()
    var holes: [Hole]
}

struct GolfCourse: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var facilityName: String
    var city: String
    var postcode: String
    var isVerified: Bool
    var isSaved: Bool
    var currentRevision: CourseRevision
    var defaultLoopCount: Int? = nil
    var coverPhotoFilename: String? = nil
    var createdByCurrentUser: Bool? = nil
    var creatorUsername: String? = nil

    var holeCount: Int { currentRevision.holes.count }
    var totalPar: Int { currentRevision.holes.reduce(0) { $0 + $1.par } }
    var loopCount: Int { max(1, min(defaultLoopCount ?? 1, 3)) }
    var roundHoleCount: Int { holeCount * loopCount }
    var roundTotalPar: Int { totalPar * loopCount }
    var repeatsLayout: Bool { loopCount > 1 }
    var canCurrentUserEdit: Bool { createdByCurrentUser ?? !isVerified }

    func hole(forRoundHole number: Int) -> Hole? {
        guard holeCount > 0, (1...roundHoleCount).contains(number) else { return nil }
        return currentRevision.holes[(number - 1) % holeCount]
    }

    var referenceCoordinate: Coordinate? {
        currentRevision.holes.first?.tee ?? currentRevision.holes.first?.greenReference
    }
}

enum ClubCategory: String, Codable, CaseIterable, Identifiable {
    case driver = "Driver"
    case miniDriver = "Mini Driver"
    case fairwayWood = "Fairway Wood"
    case hybrid = "Hybrid / Rescue"
    case utilityIron = "Utility / Driving Iron"
    case iron = "Iron"
    case pitchingWedge = "Pitching Wedge"
    case gapWedge = "Approach / Gap Wedge"
    case sandWedge = "Sand Wedge"
    case lobWedge = "Lob Wedge"
    case chipper = "Chipper"
    case putter = "Putter"
    case custom = "Custom"
    var id: String { rawValue }
}

struct GolfClub: Codable, Identifiable, Hashable {
    var id = UUID()
    var category: ClubCategory
    var name: String
    var nickname: String = ""
    var loft: Double?
    var isActive = true

    var displayName: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? name : trimmed
    }

    var showsNickname: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var iconLabel: String {
        let source = name.uppercased()
        if source.contains("DRIVER") && !source.contains("MINI") { return "D" }
        if source.contains("MINI") { return "MD" }
        if let match = source.range(of: #"\d{1,2}\s*(WOOD|W)\b"#, options: .regularExpression) {
            return source[match].filter(\.isNumber) + "W"
        }
        if let match = source.range(of: #"\d\s*(HYBRID|H)\b"#, options: .regularExpression) {
            return source[match].filter(\.isNumber) + "H"
        }
        if let match = source.range(of: #"\d\s*(UTILITY|U)\b"#, options: .regularExpression) {
            return source[match].filter(\.isNumber) + "U"
        }
        if let match = source.range(of: #"\d\s*(IRON|I)\b"#, options: .regularExpression) {
            return source[match].filter(\.isNumber) + "I"
        }
        switch category {
        case .driver: return "D"
        case .miniDriver: return "MD"
        case .fairwayWood: return "W"
        case .hybrid: return "H"
        case .utilityIron: return "U"
        case .iron: return "I"
        case .pitchingWedge: return "PW"
        case .gapWedge: return source.contains("AW") ? "AW" : source.contains("UW") ? "UW" : "GW"
        case .sandWedge: return "SW"
        case .lobWedge: return "LW"
        case .chipper: return "CH"
        case .putter: return "P"
        case .custom: return "★"
        }
    }
}

enum DistanceKind: String, Codable, CaseIterable, Identifiable {
    case carry = "Carry"
    case total = "Total"
    var id: String { rawValue }
}

enum DistanceObservationSource: String, Codable {
    case drivingRange
    case onCourseGPS
}

struct RangeHit: Codable, Identifiable, Hashable {
    var id = UUID()
    var clubID: UUID
    var metres: Double
    var kind: DistanceKind
    var isMishit = false
    var isPartial = false
    var createdAt = Date()
    var source: DistanceObservationSource?

    var observationSource: DistanceObservationSource { source ?? .drivingRange }
}

struct ClubCarryInsight {
    var estimatedMetres: Double?
    var isEstimate: Bool
    var isPossibleAnomaly: Bool
    var anchorCount: Int
}

struct ClubRecommendation {
    var club: GolfClub
    var carryMetres: Double
    var isEstimated: Bool
    var adjustedTargetMetres: Double? = nil
    var estimatedRollMetres: Double = 0
    var conditionsSummary: String? = nil
}

struct PlayingConditions {
    enum Firmness: String {
        case soft = "Soft"
        case normal = "Normal"
        case firm = "Firm"
        case veryFirm = "Very firm"
    }

    var fetchedAt: Date
    var temperatureCelsius: Double
    var windSpeedKPH: Double
    var windDirectionDegrees: Double
    var sevenDayRainMM: Double
    var sevenDayEvapotranspirationMM: Double
    var recentHotDays: Int
    var firmness: Firmness
    var confidence: String
}

enum TargetDirection: String, Codable, CaseIterable, Identifiable {
    case onTarget = "On target"
    case left = "Left"
    case right = "Right"
    var id: String { rawValue }
}

enum BallFlight: String, Codable, CaseIterable, Identifiable {
    case straight = "Straight"
    case draw = "Draw"
    case fade = "Fade"
    case hook = "Hook"
    case slice = "Slice"
    case pull = "Pull"
    case push = "Push"
    var id: String { rawValue }
}

enum StrikeQuality: String, Codable, CaseIterable, Identifiable {
    case solid = "Solid"
    case fat = "Fat / heavy"
    case thin = "Thin"
    case topped = "Topped"
    case shank = "Shank"
    case sky = "Sky / pop-up"
    case toe = "Toe"
    case heel = "Heel"
    var id: String { rawValue }
}

enum FinishingLie: String, Codable, CaseIterable, Identifiable {
    case fairway = "Fairway"
    case rough = "Rough"
    case bunker = "Bunker"
    case fringe = "Fringe"
    case green = "Green"
    case penaltyArea = "Penalty area"
    case outOfBounds = "Out of bounds / lost"
    case holed = "Holed"
    var id: String { rawValue }
}

enum ReliefProcedure: String, Codable, CaseIterable, Identifiable {
    case strokeAndDistance = "Stroke and distance (+1)"
    case localRuleE5 = "Local Rule E-5 (+2)"
    case provisional = "Provisional ball (+1 if used)"
    case casualDrop = "Casual nearby drop (+1, non-conforming)"
    var id: String { rawValue }
    var strokes: Int { self == .localRuleE5 ? 2 : 1 }
}

struct LoggedShot: Codable, Identifiable, Hashable {
    var id = UUID()
    var startedAt = Date()
    var start: Coordinate?
    var end: Coordinate?
    var clubID: UUID?
    var direction: TargetDirection?
    var ballFlight: BallFlight?
    var strike: StrikeQuality?
    var finishingLie: FinishingLie?
    var relief: ReliefProcedure?
}

enum RoundFormat: String, Codable, CaseIterable, Identifiable {
    case strokePlay = "Stroke Play"
    case stableford = "Stableford"
    case matchPlay = "Match Play"
    case gpsOnly = "GPS only"
    var id: String { rawValue }
}

struct ActiveRound: Codable, Identifiable {
    var id = UUID()
    var courseID: UUID
    var courseRevisionID: UUID
    var format: RoundFormat
    var rulesCompliant: Bool
    var holeNumber = 1
    var scores: [Int: Int] = [:]
    var shots: [Int: [LoggedShot]] = [:]
    var manualPlayerLocation: Coordinate?
    var startedAt = Date()
}

struct CompletedRound: Codable, Identifiable {
    var id = UUID()
    var courseID: UUID
    var courseRevisionID: UUID
    var courseName: String
    var format: RoundFormat
    var scores: [Int: Int]
    var shots: [Int: [LoggedShot]]
    var startedAt: Date
    var endedAt = Date()

    var holesPlayed: Int { scores.filter { $0.value > 0 }.count }
    var totalScore: Int { scores.values.reduce(0, +) }
    var shotCount: Int { shots.values.reduce(0) { $0 + $1.count } }
}

struct GalleryItem: Codable, Identifiable, Hashable {
    struct TracePoint: Codable, Hashable {
        enum Source: String, Codable {
            case observed
            case extrapolated
        }

        var x: Double
        var y: Double
        var source: Source
    }

    var id = UUID()
    var createdAt = Date()
    var title: String
    var localVideoFilename: String?
    var courseName: String?
    var holeNumber: Int?
    var clubName: String?
    var isPrivate = true
    var tracerStatus = "Needs trace"
    var tracePoints: [TracePoint]?
    var observedPointCount: Int?
}

struct UserProfile: Codable {
    var displayName = "Zac Whittaker"
    var username = "zacwhittaker"
    var biography = "Weekend golfer, course mapper and founder of OverPar."
    var broadLocation = "Leeds, United Kingdom"
    var units = "yards"
    var isRightHanded = true
    var assistantEnabled = true
    var hasCompletedOnboarding = false
    var homeCourseID: UUID?
}

struct AppData: Codable {
    var profile: UserProfile
    var courses: [GolfCourse]
    var clubs: [GolfClub]
    var rangeHits: [RangeHit]
    var gallery: [GalleryItem]
    var activeRound: ActiveRound?
    var completedRounds: [CompletedRound]?
}
