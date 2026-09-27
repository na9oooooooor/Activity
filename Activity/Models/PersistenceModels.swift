

import Foundation
import SwiftData

// MARK: - Imported workout

@Model
final class StoredWorkout {

    @Attribute(.unique)
    var healthKitUUID: String

    var startDate: Date
    var endDate: Date


    var activityTypeRawValue: Int

    var sourceName: String
    var sourceBundleIdentifier: String
    var importedAt: Date


    var isRecognizedStrengthWorkout: Bool


    var moderateMinutes: Double?
    var vigorousMinutes: Double?

    /*
     Examples:
     "physicalEffort"
     "userReviewed"
     "unknown"
     */
    var intensitySourceRawValue: String

    init(
        healthKitUUID: String,
        startDate: Date,
        endDate: Date,
        activityTypeRawValue: Int,
        sourceName: String,
        sourceBundleIdentifier: String,
        importedAt: Date = .now,
        isRecognizedStrengthWorkout: Bool = false,
        moderateMinutes: Double? = nil,
        vigorousMinutes: Double? = nil,
        intensitySourceRawValue: String = "unknown"
    ) {
        self.healthKitUUID = healthKitUUID
        self.startDate = startDate
        self.endDate = endDate
        self.activityTypeRawValue = activityTypeRawValue
        self.sourceName = sourceName
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.importedAt = importedAt
        self.isRecognizedStrengthWorkout =
            isRecognizedStrengthWorkout
        self.moderateMinutes =
            moderateMinutes.map { max(0, $0) }
        self.vigorousMinutes =
            vigorousMinutes.map { max(0, $0) }
        self.intensitySourceRawValue =
            intensitySourceRawValue
    }

    var durationMinutes: Double {
        max(
            0,
            endDate.timeIntervalSince(startDate) / 60
        )
    }

    var needsIntensityReview: Bool {
        moderateMinutes == nil
            && vigorousMinutes == nil
            && !isRecognizedStrengthWorkout
    }
}

// MARK: - Calculated daily summary

@Model
final class DailyActivityRecord {

    @Attribute(.unique)
    var dayKey: String

    var dayStart: Date

    var moderateMinutes: Double
    var vigorousMinutes: Double
    var unknownIntensityMinutes: Double

    
    var strengthWorkoutCount: Int

    var recordedSteps: Int?
    var appleExerciseMinutes: Double?
    var standHours: Int?
    var activeEnergyKilocalories: Double?
    var walkingRunningDistanceMeters: Double?
    var cyclingDistanceMeters: Double?

    
    var aerobicCoverageRawValue: String
    var strengthCoverageRawValue: String

    var lastCalculatedAt: Date

    init(
        dayKey: String,
        dayStart: Date,
        moderateMinutes: Double = 0,
        vigorousMinutes: Double = 0,
        unknownIntensityMinutes: Double = 0,
        strengthWorkoutCount: Int = 0,
        recordedSteps: Int? = nil,
        appleExerciseMinutes: Double? = nil,
        standHours: Int? = nil,
        activeEnergyKilocalories: Double? = nil,
        walkingRunningDistanceMeters: Double? = nil,
        cyclingDistanceMeters: Double? = nil,
        aerobicCoverage: DataCoverage = .partial,
        strengthCoverage: DataCoverage = .partial,
        lastCalculatedAt: Date = .now
    ) {
        self.dayKey = dayKey
        self.dayStart = dayStart

        self.moderateMinutes = max(0, moderateMinutes)
        self.vigorousMinutes = max(0, vigorousMinutes)
        self.unknownIntensityMinutes =
            max(0, unknownIntensityMinutes)

        self.strengthWorkoutCount =
            max(0, strengthWorkoutCount)

        self.recordedSteps =
            recordedSteps.map { max(0, $0) }

        self.appleExerciseMinutes =
            appleExerciseMinutes.map { max(0, $0) }

        self.standHours =
            standHours.map { max(0, $0) }

        self.activeEnergyKilocalories =
            activeEnergyKilocalories.map { max(0, $0) }

        self.walkingRunningDistanceMeters =
            walkingRunningDistanceMeters.map { max(0, $0) }

        self.cyclingDistanceMeters =
            cyclingDistanceMeters.map { max(0, $0) }

        self.aerobicCoverageRawValue =
            aerobicCoverage.rawValue

        self.strengthCoverageRawValue =
            strengthCoverage.rawValue

        self.lastCalculatedAt = lastCalculatedAt
    }

    var moderateEquivalentMinutes: Double {
        moderateMinutes + (2 * vigorousMinutes)
    }

    var isStrengthDay: Bool {
        strengthWorkoutCount > 0
    }

    var aerobicCoverage: DataCoverage {
        DataCoverage(
            rawValue: aerobicCoverageRawValue
        ) ?? .partial
    }

    var strengthCoverage: DataCoverage {
        DataCoverage(
            rawValue: strengthCoverageRawValue
        ) ?? .partial
    }
}

// MARK: - Daily user check-in

@Model
final class StoredDailyCheckIn {
    @Attribute(.unique)
    var dayKey: String

    var wantsRecovery: Bool
    var reportsLowMovement: Bool
    var updatedAt: Date

    init(
        dayKey: String,
        wantsRecovery: Bool = false,
        reportsLowMovement: Bool = false,
        updatedAt: Date = .now
    ) {
        self.dayKey = dayKey
        self.wantsRecovery = wantsRecovery
        self.reportsLowMovement = reportsLowMovement
        self.updatedAt = updatedAt
    }
}

// MARK: - App settings

@Model
final class AppSettings {

    @Attribute(.unique)
    var settingsID: String

    var hasCompletedOnboarding: Bool

    var ageBandRawValue: String
    var usesGeneralAdultGuidance: Bool


    var analysisTimeZoneIdentifier: String
    var activityDayStartHour: Int = 0

    var showActiveEnergy: Bool
    var showStandHours: Bool
    var showDistance: Bool

    var createdAt: Date
    var updatedAt: Date

    init(
        settingsID: String = "primary",
        hasCompletedOnboarding: Bool = false,
        ageBandRawValue: String = "18to64",
        usesGeneralAdultGuidance: Bool = true,
        analysisTimeZoneIdentifier: String =
            TimeZone.current.identifier,
        activityDayStartHour: Int = 0,
        showActiveEnergy: Bool = true,
        showStandHours: Bool = true,
        showDistance: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.settingsID = settingsID
        self.hasCompletedOnboarding =
            hasCompletedOnboarding
        self.ageBandRawValue = ageBandRawValue
        self.usesGeneralAdultGuidance =
            usesGeneralAdultGuidance
        self.analysisTimeZoneIdentifier =
            analysisTimeZoneIdentifier

        self.activityDayStartHour = min(
            8,
            max(0, activityDayStartHour)
        )

        self.showActiveEnergy = showActiveEnergy
        self.showStandHours = showStandHours
        self.showDistance = showDistance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
