import Foundation

enum DataCoverage: String, Codable, Sendable {
    case confirmed
    case partial
    case unavailable
}

enum RecordState: String, Codable, Sendable {
    case current
    case importing
    case stale
    case unavailable
}

enum WorkoutRole:
    String,
    Codable,
    Sendable,
    Hashable
{
    case unknown
    case aerobic
    case strength
    case both
    case neither

    static let userChoices: [WorkoutRole] = [
        .aerobic,
        .strength,
        .both,
        .neither
    ]

    var title: String {
        switch self {
        case .unknown:
            return "Needs review"

        case .aerobic:
            return "Aerobic"

        case .strength:
            return "Strength"

        case .both:
            return "Aerobic and strength"

        case .neither:
            return "Neither / light activity"
        }
    }

    var includesAerobic: Bool {
        self == .aerobic || self == .both
    }

    var includesStrength: Bool {
        self == .strength || self == .both
    }
}

enum WorkoutRoleSource: String, Codable, Sendable {
    case unclassified
    case automatic
    case settingsOverride
    case userReview
    case manualEntry
}


struct ActivitySnapshot: Equatable, Sendable {
    var moderateMinutes: Double
    var vigorousMinutes: Double
    var unknownIntensityMinutes: Double

    /*
     One strength day means at least one recognized strength workout
     occurred on that calendar date.

     Multiple strength workouts on the same date still count as one day.
     */
    var strengthDays: Int

    /*
     Coverage describes whether the available records appear complete.
     It does not describe muscle-group coverage.
     */
    var aerobicCoverage: DataCoverage
    var strengthCoverage: DataCoverage
    var recordState: RecordState

    var isInsideGuidedScope: Bool
    var strengthRecordedTodayOrYesterday: Bool
    var aerobicMinutesCompletedToday: Double

    var recordedStepsToday: Int?

    init(
        moderateMinutes: Double = 0,
        vigorousMinutes: Double = 0,
        unknownIntensityMinutes: Double = 0,
        strengthDays: Int = 0,
        aerobicCoverage: DataCoverage = .partial,
        strengthCoverage: DataCoverage = .partial,
        recordState: RecordState = .current,
        isInsideGuidedScope: Bool = true,
        strengthRecordedTodayOrYesterday: Bool = false,
        aerobicMinutesCompletedToday: Double = 0,
        recordedStepsToday: Int? = nil
    ) {
        self.moderateMinutes = max(0, moderateMinutes)
        self.vigorousMinutes = max(0, vigorousMinutes)
        self.unknownIntensityMinutes =
            max(0, unknownIntensityMinutes)

        self.strengthDays = min(7, max(0, strengthDays))

        self.aerobicCoverage = aerobicCoverage
        self.strengthCoverage = strengthCoverage
        self.recordState = recordState

        self.isInsideGuidedScope = isInsideGuidedScope
        self.strengthRecordedTodayOrYesterday =
            strengthRecordedTodayOrYesterday

        self.aerobicMinutesCompletedToday =
            max(0, aerobicMinutesCompletedToday)

        self.recordedStepsToday =
            recordedStepsToday.map { max(0, $0) }
    }

    var moderateEquivalentMinutes: Double {
        moderateMinutes + (2 * vigorousMinutes)
    }
}

struct TodayCheckIn: Equatable, Sendable {
    var wantsRecovery: Bool
    var reportsLowMovement: Bool

    init(
        wantsRecovery: Bool = false,
        reportsLowMovement: Bool = false
    ) {
        self.wantsRecovery = wantsRecovery
        self.reportsLowMovement = reportsLowMovement
    }
}

enum ActivityHealthStatus: String, Sendable {
    case meetingTargets = "Meeting the core activity targets"
    case belowTargets = "Room to build your activity"
    case needsReview = "More information needed"
    case updating = "Updating activity"
    case unavailable = "No accessible activity data"
}

enum TodayOutcome: String, Sendable {
    case workoutRecommended = "Workout recommended"
    case activityRecommended = "Activity recommended"
    case workoutOptional = "Workout optional"
    case recovery = "Recovery / light movement"
}

enum DecisionReason: String, Sendable {
    case targetsMet
    case aerobicGap
    case strengthGap
    case smallRemainingGap
    case recentStrengthSession
    case aerobicSessionAlreadyCompleted
    case lowMovement
    case recoveryChoice
    case incompleteRecords
    case unavailableRecords
    case staleRecords
    case importing
    case outsideGuidedScope
}

struct TodayRecommendation: Equatable, Sendable {
    let outcome: TodayOutcome?
    let reason: DecisionReason
}

struct ActivityAssessment: Equatable, Sendable {
    let status: ActivityHealthStatus
    let recommendation: TodayRecommendation
    let aerobicTargetMet: Bool
    let strengthTargetMet: Bool
    let aboveAerobicReferenceRange: Bool
}

struct HealthKitWorkoutValue: Sendable {
    let healthKitUUID: String

    let startDate: Date
    let endDate: Date

    let activityTypeRawValue: Int

    let sourceName: String
    let sourceBundleIdentifier: String
}

struct WorkoutImportResult: Equatable, Sendable {
    let insertedCount: Int
    let updatedCount: Int

    let roleReviewCount: Int
    let intensityReviewCount: Int

    var totalImportedCount: Int {
        insertedCount + updatedCount
    }
}
