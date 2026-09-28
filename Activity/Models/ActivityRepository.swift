

import Foundation
import SwiftData

struct DashboardInput {
    let snapshot: ActivitySnapshot
    let checkIn: TodayCheckIn

    let comparison:
        PersonalBaselineComparison

    let targets: ActivityTargets

    let usesCustomActivityTargets: Bool

    let windowStart: Date
    let windowEnd: Date
}

enum ActivityRepositoryError: Error {
    case unableToCreateDateWindow
}

enum WorkoutReviewError: LocalizedError {
    case roleRequired
    case intensityRequired
    case invalidMinutes
    case minutesExceedWorkout

    var errorDescription: String? {
        switch self {
        case .roleRequired:
            return "Choose what this workout included."

        case .intensityRequired:
            return "Choose the aerobic intensity."

        case .invalidMinutes:
            return "Enter a valid number of aerobic minutes."

        case .minutesExceedWorkout:
            return """
            Aerobic minutes cannot be longer than the workout.
            """
        }
    }
}

@MainActor
final class ActivityRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func workoutImportRange(
        completedHistoryDays: Int = 97,
        now: Date = .now
    ) throws -> DateInterval {
        let settings = try loadOrCreateSettings()
        let calendar = makeCalendar(using: settings)

        let currentDayStart = activityDayStart(
            containing: now,
            calendar: calendar,
            startHour:
                settings.activityDayStartHour
        )

        let safeHistoryDays = max(
            1,
            completedHistoryDays
        )

        guard let historyStart = calendar.date(
            byAdding: .day,
            value: -safeHistoryDays,
            to: currentDayStart
        ) else {
            throw ActivityRepositoryError
                .unableToCreateDateWindow
        }

        return DateInterval(
            start: historyStart,
            end: now
        )
    }
    
    func healthKitImportPlan(
        completedHistoryDays: Int = 97,
        now: Date = .now
    ) throws -> HealthKitImportPlan {
        let settings = try loadOrCreateSettings()

        let range = try workoutImportRange(
            completedHistoryDays:
                completedHistoryDays,
            now: now
        )

        return HealthKitImportPlan(
            startDate: range.start,
            endDate: range.end,
            timeZoneIdentifier:
                settings.analysisTimeZoneIdentifier,
            activityDayStartHour:
                settings.activityDayStartHour
        )
    }
    
    func applyDailyMovement(
        _ values: [HealthKitDailyMovementValue],
        calculatedAt: Date = .now
    ) throws {
        guard
            let firstDay =
                values.map(\.dayStart).min(),
            let lastDay =
                values.map(\.dayStart).max()
        else {
            return
        }

        let settings = try loadOrCreateSettings()
        let calendar = makeCalendar(using: settings)

        guard let endExclusive =
            calendar.date(
                byAdding: .day,
                value: 1,
                to: lastDay
            )
        else {
            throw ActivityRepositoryError
                .unableToCreateDateWindow
        }

        let records = try fetchDailyRecords(
            from: firstDay,
            until: endExclusive
        )

        var recordsByKey:
            [String: DailyActivityRecord] = [:]

        for record in records {
            recordsByKey[record.dayKey] = record
        }

        for value in values {
            let dayKey = makeDayKey(
                forActivityDayStarting:
                    value.dayStart,
                calendar: calendar
            )

            guard let record =
                recordsByKey[dayKey]
            else {
                continue
            }

            record.recordedSteps =
                value.steps

            record.appleExerciseMinutes =
                value.appleExerciseMinutes

            record.standHours =
                value.standHours
            
            record.activeEnergyKilocalories =
                value.activeEnergyKilocalories

            record.walkingRunningDistanceMeters =
                value.walkingRunningDistanceMeters

            record.cyclingDistanceMeters =
                value.cyclingDistanceMeters

            record.lastCalculatedAt =
                calculatedAt
        }

        try modelContext.save()
    }
    
    func importWorkouts(
        _ incomingWorkouts: [HealthKitWorkoutValue],
        importedAt: Date = .now
    ) throws -> WorkoutImportResult {
        let storedWorkouts = try modelContext.fetch(
            FetchDescriptor<StoredWorkout>()
        )

        var storedByUUID = Dictionary(
            uniqueKeysWithValues:
                storedWorkouts.map { workout in
                    (
                        workout.healthKitUUID,
                        workout
                    )
                }
        )

        let preferences = try modelContext.fetch(
            FetchDescriptor<WorkoutRolePreference>()
        )

        let preferenceByType = Dictionary(
            uniqueKeysWithValues:
                preferences.map { preference in
                    (
                        preference.activityTypeRawValue,
                        preference.workoutRole
                    )
                }
        )

        var insertedCount = 0
        var updatedCount = 0

        for incoming in incomingWorkouts {
            let settingsOverride =
                preferenceByType[
                    incoming.activityTypeRawValue
                ]
            let decision = WorkoutClassifier.classify(
                activityTypeRawValue:
                    incoming.activityTypeRawValue,
                settingsOverride: settingsOverride
                
            )
            
            let automaticIntensity =
                decision.role.includesAerobic
                ? AutomaticIntensityClassifier
                    .classify(
                        workoutStart:
                            incoming.startDate,
                        workoutEnd:
                            incoming.endDate,
                        recordedDurationMinutes:
                            incoming
                                .recordedDurationMinutes,
                        physicalEffort:
                            incoming
                                .physicalEffortSamples,
                        averageMETs:
                            incoming.averageMETs
                    )
                : AutomaticIntensityResult(
                    moderateMinutes: nil,
                    vigorousMinutes: nil,
                    sourceRawValue: "notApplicable"
                )

            if let existing =
                storedByUUID[incoming.healthKitUUID] {
                existing.startDate =
                    incoming.startDate

                existing.endDate =
                    incoming.endDate

 
                existing.recordedDurationMinutes =
                    incoming.recordedDurationMinutes

                existing.activityTypeRawValue =
                    incoming.activityTypeRawValue

                existing.sourceName =
                    incoming.sourceName

                existing.sourceBundleIdentifier =
                    incoming.sourceBundleIdentifier

                existing.importedAt = importedAt


                if existing.workoutRoleSource
                    != .userReview {
                    existing.workoutRole =
                        decision.role

                    existing.workoutRoleSource =
                        decision.source
                }


                if existing.intensitySourceRawValue
                    != "userReviewed" {
                    let effectiveIntensity =
                        existing.workoutRole.includesAerobic
                        ? AutomaticIntensityClassifier
                            .classify(
                                workoutStart:
                                    incoming.startDate,
                                workoutEnd:
                                    incoming.endDate,
                                recordedDurationMinutes:
                                    incoming
                                        .recordedDurationMinutes,
                                physicalEffort:
                                    incoming
                                        .physicalEffortSamples,
                                averageMETs:
                                    incoming.averageMETs
                            )
                        : AutomaticIntensityResult(
                            moderateMinutes: nil,
                            vigorousMinutes: nil,
                            sourceRawValue:
                                "notApplicable"
                        )

                    existing.moderateMinutes =
                        effectiveIntensity
                            .moderateMinutes

                    existing.vigorousMinutes =
                        effectiveIntensity
                            .vigorousMinutes

                    existing.intensitySourceRawValue =
                        effectiveIntensity
                            .sourceRawValue
                }

                updatedCount += 1
            } else {
                let stored = StoredWorkout(
                    healthKitUUID:
                        incoming.healthKitUUID,
                    startDate:
                        incoming.startDate,
                    endDate:
                        incoming.endDate,
                    recordedDurationMinutes:
                        incoming.recordedDurationMinutes,
                    activityTypeRawValue:
                        incoming.activityTypeRawValue,
                    sourceName:
                        incoming.sourceName,
                    sourceBundleIdentifier:
                        incoming.sourceBundleIdentifier,
                    importedAt:
                        importedAt,
                    workoutRole:
                        decision.role,
                    workoutRoleSource:
                        decision.source,
                    moderateMinutes:
                        automaticIntensity
                            .moderateMinutes,
                    vigorousMinutes:
                        automaticIntensity
                            .vigorousMinutes,
                    intensitySourceRawValue:
                        automaticIntensity
                            .sourceRawValue
                )

                modelContext.insert(stored)

                storedByUUID[
                    incoming.healthKitUUID
                ] = stored

                insertedCount += 1
            }
        }

        try modelContext.save()

        let importedUUIDs = Set(
            incomingWorkouts.map(\.healthKitUUID)
        )

        let importedRecords = storedByUUID.values.filter {
            importedUUIDs.contains(
                $0.healthKitUUID
            )
        }

        let roleReviewCount = importedRecords.filter {
            $0.needsRoleReview
        }.count

        let intensityReviewCount =
            importedRecords.filter {
                $0.needsIntensityReview
            }.count

        return WorkoutImportResult(
            insertedCount: insertedCount,
            updatedCount: updatedCount,
            roleReviewCount: roleReviewCount,
            intensityReviewCount:
                intensityReviewCount
        )
    }

    func rebuildDailyActivityRecords(
        from firstDate: Date,
        through lastDate: Date,
        calculatedAt: Date = .now
    ) throws {
        let settings = try loadOrCreateSettings()
        let calendar = makeCalendar(
            using: settings
        )

        let earlierDate = min(
            firstDate,
            lastDate
        )

        let laterDate = max(
            firstDate,
            lastDate
        )

        let firstDayStart = activityDayStart(
            containing: earlierDate,
            calendar: calendar,
            startHour:
                settings.activityDayStartHour
        )

        let lastDayStart = activityDayStart(
            containing: laterDate,
            calendar: calendar,
            startHour:
                settings.activityDayStartHour
        )

        guard let endExclusive =
            calendar.date(
                byAdding: .day,
                value: 1,
                to: lastDayStart
            )
        else {
            throw ActivityRepositoryError
                .unableToCreateDateWindow
        }

        let workouts =
            try fetchStoredWorkouts(
                from: firstDayStart,
                until: endExclusive
            )

        let existingRecords =
            try fetchDailyRecords(
                from: firstDayStart,
                until: endExclusive
            )

        var recordsByKey = Dictionary(
            uniqueKeysWithValues:
                existingRecords.map { record in
                    (
                        record.dayKey,
                        record
                    )
                }
        )


        
        let workoutsByDayKey = Dictionary(
            grouping: workouts
        ) { workout in
            let workoutDayStart =
                activityDayStart(
                    containing:
                        workout.startDate,
                    calendar: calendar,
                    startHour:
                        settings
                            .activityDayStartHour
                )

            return makeDayKey(
                forActivityDayStarting:
                    workoutDayStart,
                calendar: calendar
            )
        }

        var dayStart = firstDayStart

        while dayStart < endExclusive {
            let dayKey = makeDayKey(
                forActivityDayStarting: dayStart,
                calendar: calendar
            )

            let dailyWorkouts =
                workoutsByDayKey[dayKey] ?? []

            let moderateMinutes =
                dailyWorkouts.reduce(0) {
                    total,
                    workout in

                    total
                        + (
                            workout.moderateMinutes
                            ?? 0
                        )
                }

            let vigorousMinutes =
                dailyWorkouts.reduce(0) {
                    total,
                    workout in

                    total
                        + (
                            workout.vigorousMinutes
                            ?? 0
                        )
                }

            /*
             Only an aerobic candidate with unresolved
             intensity contributes unknown minutes.
             */
            let unknownIntensityMinutes =
                dailyWorkouts.reduce(0) {
                    total,
                    workout in

                    guard
                        workout
                            .workoutRole
                            .includesAerobic,
                        workout.needsIntensityReview
                    else {
                        return total
                    }

                    return total
                        + workout.durationMinutes
                }

            let strengthWorkoutCount =
                dailyWorkouts.filter {
                    $0.countsTowardStrength
                }.count

            /*
             An unknown role might eventually be aerobic,
             strength, both or neither. We cannot declare
             either category complete yet.
             */
            let hasUnresolvedRole =
                dailyWorkouts.contains {
                    $0.needsRoleReview
                }

            let previousRecord =
                recordsByKey[dayKey]

            let previousAerobicCoverage =
                previousRecord?
                    .aerobicCoverage
                ?? .partial

            let previousStrengthCoverage =
                previousRecord?
                    .strengthCoverage
                ?? .partial

            let aerobicCoverage:
                DataCoverage =
                hasUnresolvedRole
                || unknownIntensityMinutes > 0
                ? .partial
                : previousAerobicCoverage

            let strengthCoverage:
                DataCoverage =
                hasUnresolvedRole
                ? .partial
                : previousStrengthCoverage

            if let existing =
                previousRecord {
                existing.dayStart = dayStart

                existing.moderateMinutes =
                    moderateMinutes

                existing.vigorousMinutes =
                    vigorousMinutes

                existing.unknownIntensityMinutes =
                    unknownIntensityMinutes

                existing.strengthWorkoutCount =
                    strengthWorkoutCount

                existing.aerobicCoverageRawValue =
                    aerobicCoverage.rawValue

                existing.strengthCoverageRawValue =
                    strengthCoverage.rawValue

                existing.lastCalculatedAt =
                    calculatedAt
            } else {
                let record =
                    DailyActivityRecord(
                        dayKey: dayKey,
                        dayStart: dayStart,
                        moderateMinutes:
                            moderateMinutes,
                        vigorousMinutes:
                            vigorousMinutes,
                        unknownIntensityMinutes:
                            unknownIntensityMinutes,
                        strengthWorkoutCount:
                            strengthWorkoutCount,
                        aerobicCoverage:
                            aerobicCoverage,
                        strengthCoverage:
                            strengthCoverage,
                        lastCalculatedAt:
                            calculatedAt
                    )

                modelContext.insert(record)
                recordsByKey[dayKey] = record
            }

            guard let nextDayStart =
                calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: dayStart
                )
            else {
                throw ActivityRepositoryError
                    .unableToCreateDateWindow
            }

            dayStart = nextDayStart
        }

        try modelContext.save()
    }
    func loadDashboardInput(
        now: Date = .now
    ) throws -> DashboardInput {
        let settings = try loadOrCreateSettings()
        let calendar = makeCalendar(using: settings)

        let todayStart = activityDayStart(
            containing: now,
            calendar: calendar,
            startHour: settings.activityDayStartHour
        )

        let currentDayKey = makeDayKey(
            forActivityDayStarting: todayStart,
            calendar: calendar
        )
        guard
            let windowStart = calendar.date(
                byAdding: .day,
                value: -6,
                to: todayStart
            ),
            let tomorrowStart = calendar.date(
                byAdding: .day,
                value: 1,
                to: todayStart
            ),
            let yesterdayStart = calendar.date(
                byAdding: .day,
                value: -1,
                to: todayStart
            ),
      
            let comparisonCurrentStart =
                calendar.date(
                    byAdding: .day,
                    value: -7,
                    to: todayStart
                ),
            let comparisonBaselineStart =
                calendar.date(
                    byAdding: .day,
                    value: -90,
                    to: comparisonCurrentStart
                )
        else {
            throw ActivityRepositoryError
                .unableToCreateDateWindow
        }

        let records = try fetchDailyRecords(
            from: windowStart,
            until: tomorrowStart
        )
        
        let comparisonRecords =
            try fetchDailyRecords(
                from: comparisonBaselineStart,
                until: todayStart
            )

        let currentComparisonRecords =
            comparisonRecords.filter { record in
                record.dayStart >=
                    comparisonCurrentStart
            }

        let baselineRecords =
            comparisonRecords.filter { record in
                record.dayStart <
                    comparisonCurrentStart
            }

        let personalComparison =
            makePersonalBaselineComparison(
                currentRecords:
                    currentComparisonRecords,
                baselineRecords:
                    baselineRecords
            )

        let aerobicCoverage = combinedCoverage(
            records.map(\.aerobicCoverage),
            expectedDayCount: 7
        )

        let strengthCoverage = combinedCoverage(
            records.map(\.strengthCoverage),
            expectedDayCount: 7
        )

        let moderateMinutes = records.reduce(0) {
            currentTotal,
            record in

            currentTotal + record.moderateMinutes
        }

        let vigorousMinutes = records.reduce(0) {
            currentTotal,
            record in

            currentTotal + record.vigorousMinutes
        }
        
        let supplementalAppleExerciseMinutes =
            records.reduce(0) {
                currentTotal,
                record in

                currentTotal
                    + record
                        .supplementalAppleExerciseMinutes
            }

        let unknownMinutes = records.reduce(0) {
            currentTotal,
            record in

            currentTotal
                + record.unknownIntensityMinutes
        }

        let strengthDays = records.filter {
            $0.isStrengthDay
        }.count

        let strengthRecordedTodayOrYesterday =
            records.contains { record in
                record.dayStart >= yesterdayStart
                    && record.isStrengthDay
            }

        let todayRecord = records.first { record in
            record.dayKey == currentDayKey
        }

        let snapshot = ActivitySnapshot(
            moderateMinutes: moderateMinutes,
            vigorousMinutes: vigorousMinutes,
            supplementalAppleExerciseMinutes:
                supplementalAppleExerciseMinutes,
            unknownIntensityMinutes: unknownMinutes,
            strengthDays: strengthDays,
            aerobicCoverage: aerobicCoverage,
            strengthCoverage: strengthCoverage,
            recordState:
                records.isEmpty ? .unavailable : .current,
            isInsideGuidedScope:
                settings.usesGeneralAdultGuidance
                && settings.ageBandRawValue == "18to64",
            strengthRecordedTodayOrYesterday:
                strengthRecordedTodayOrYesterday,
            aerobicMinutesCompletedToday:
                todayRecord?.moderateEquivalentMinutes ?? 0,
            recordedStepsToday:
                todayRecord?.recordedSteps
        )

        let storedCheckIn = try fetchCheckIn(
            dayKey: currentDayKey
        )

        let checkIn = TodayCheckIn(
            wantsRecovery:
                storedCheckIn?.wantsRecovery ?? false,
            reportsLowMovement:
                storedCheckIn?.reportsLowMovement ?? false
        )

        return DashboardInput(
            snapshot: snapshot,
            checkIn: checkIn,
            comparison:
                personalComparison,
            targets:
                settings.activityTargets,
            usesCustomActivityTargets:
                settings.usesCustomActivityTargets,
            windowStart: windowStart,
            windowEnd: now
        )
    }

    func saveTodayCheckIn(
        wantsRecovery: Bool,
        reportsLowMovement: Bool,
        now: Date = .now
    ) throws {
        let settings = try loadOrCreateSettings()
        let calendar = makeCalendar(using: settings)

        let currentDayStart = activityDayStart(
            containing: now,
            calendar: calendar,
            startHour: settings.activityDayStartHour
        )

        let dayKey = makeDayKey(
            forActivityDayStarting: currentDayStart,
            calendar: calendar
        )

        if let existing = try fetchCheckIn(
            dayKey: dayKey
        ) {
            existing.wantsRecovery = wantsRecovery
            existing.reportsLowMovement =
                reportsLowMovement
            existing.updatedAt = now
        } else {
            let checkIn = StoredDailyCheckIn(
                dayKey: dayKey,
                wantsRecovery: wantsRecovery,
                reportsLowMovement:
                    reportsLowMovement,
                updatedAt: now
            )

            modelContext.insert(checkIn)
        }

        try modelContext.save()
    }

    func updateActivityTargets(
        aerobicMinutes: Double,
        strengthDays: Int,
        now: Date = .now
    ) throws {
        let settings = try loadOrCreateSettings()

        settings.aerobicTargetMinutes =
            min(
                600,
                max(30, aerobicMinutes)
            )

        settings.strengthTargetDays =
            min(
                7,
                max(1, strengthDays)
            )

        settings.usesCustomActivityTargets =
            true

        settings.updatedAt = now

        try modelContext.save()
    }

    func resetActivityTargets(
        now: Date = .now
    ) throws {
        let settings = try loadOrCreateSettings()
        let defaults =
            ActivityTargets
                .generalAdultGuidance

        settings.aerobicTargetMinutes =
            defaults.aerobicMinimumMinutes

        settings.strengthTargetDays =
            defaults.strengthMinimumDays

        settings.usesCustomActivityTargets =
            false

        settings.updatedAt = now

        try modelContext.save()
    }
    
    func loadOrCreateSettings() throws -> AppSettings {
        var request = FetchDescriptor<AppSettings>(
            predicate: #Predicate<AppSettings> {
                settings in

                settings.settingsID == "primary"
            }
        )

        request.fetchLimit = 1

        if let existing = try modelContext
            .fetch(request)
            .first {
            return existing
        }

        let settings = AppSettings()
        modelContext.insert(settings)
        try modelContext.save()

        return settings
    }
    
    
    private func makePersonalBaselineComparison(
        currentRecords: [DailyActivityRecord],
        baselineRecords: [DailyActivityRecord]
    ) -> PersonalBaselineComparison {
        let currentAerobic: [Double] =
            currentRecords.compactMap {
                record -> Double? in

                guard record.aerobicCoverage
                    != .unavailable
                else {
                    return nil
                }

                return record
                    .guidelineModerateEquivalentMinutes
            }

        let baselineAerobic: [Double] =
            baselineRecords.compactMap {
                record -> Double? in

                guard record.aerobicCoverage
                    != .unavailable
                else {
                    return nil
                }

                return record
                    .guidelineModerateEquivalentMinutes
            }

        let currentSteps: [Double] =
            currentRecords.compactMap {
                record -> Double? in

                guard let steps =
                    record.recordedSteps
                else {
                    return nil
                }

                return Double(steps)
            }

        let baselineSteps: [Double] =
            baselineRecords.compactMap {
                record -> Double? in

                guard let steps =
                    record.recordedSteps
                else {
                    return nil
                }

                return Double(steps)
            }

        let currentStandHours: [Double] =
            currentRecords.compactMap {
                record -> Double? in

                guard let hours =
                    record.standHours
                else {
                    return nil
                }

                return Double(hours)
            }

        let baselineStandHours: [Double] =
            baselineRecords.compactMap {
                record -> Double? in

                guard let hours =
                    record.standHours
                else {
                    return nil
                }

                return Double(hours)
            }

        return PersonalBaselineComparison(
            aerobic:
                makeSevenDayTotalComparison(
                    currentValues:
                        currentAerobic,
                    baselineValues:
                        baselineAerobic
                ),
            steps:
                makeDailyAverageComparison(
                    currentValues:
                        currentSteps,
                    baselineValues:
                        baselineSteps
                ),
            standHours:
                makeDailyAverageComparison(
                    currentValues:
                        currentStandHours,
                    baselineValues:
                        baselineStandHours
                )
        )
    }

    private func makeSevenDayTotalComparison(
        currentValues: [Double],
        baselineValues: [Double]
    ) -> PersonalMetricComparison? {

        guard currentValues.count == 7,
              baselineValues.count >= 28
        else {
            return nil
        }

        let currentTotal =
            currentValues.reduce(0, +)

        let baselineDailyAverage =
            baselineValues.reduce(0, +)
            / Double(baselineValues.count)

        let usualSevenDayTotal =
            baselineDailyAverage * 7

        return PersonalMetricComparison(
            currentValue: currentTotal,
            usualValue: usualSevenDayTotal,
            percentChange:
                percentageChange(
                    current: currentTotal,
                    usual: usualSevenDayTotal
                )
        )
    }

    private func makeDailyAverageComparison(
        currentValues: [Double],
        baselineValues: [Double]
    ) -> PersonalMetricComparison? {
        guard currentValues.count == 7,
              baselineValues.count >= 28
        else {
            return nil
        }

        let currentAverage =
            currentValues.reduce(0, +)
            / Double(currentValues.count)

        let baselineAverage =
            baselineValues.reduce(0, +)
            / Double(baselineValues.count)

        return PersonalMetricComparison(
            currentValue: currentAverage,
            usualValue: baselineAverage,
            percentChange:
                percentageChange(
                    current: currentAverage,
                    usual: baselineAverage
                )
        )
    }

    private func percentageChange(
        current: Double,
        usual: Double
    ) -> Double? {
        guard usual > 0 else {
            return nil
        }

        return (
            (current - usual)
            / usual
        ) * 100
    }
    
    private func fetchStoredWorkouts(
        from startDate: Date,
        until endDate: Date
    ) throws -> [StoredWorkout] {
        let request =
            FetchDescriptor<StoredWorkout>(
                predicate:
                    #Predicate<StoredWorkout> {
                        workout in

                        workout.startDate
                            >= startDate
                        && workout.startDate
                            < endDate
                    },
                sortBy: [
                    SortDescriptor(
                        \StoredWorkout.startDate,
                        order: .forward
                    )
                ]
            )

        return try modelContext.fetch(request)
    }

    private func fetchDailyRecords(
        from startDate: Date,
        until endDate: Date
    ) throws -> [DailyActivityRecord] {
        let request = FetchDescriptor<DailyActivityRecord>(
            predicate: #Predicate<DailyActivityRecord> {
                record in

                record.dayStart >= startDate
                    && record.dayStart < endDate
            },
            sortBy: [
                SortDescriptor(
                    \DailyActivityRecord.dayStart,
                    order: .forward
                )
            ]
        )

        return try modelContext.fetch(request)
    }

    private func fetchCheckIn(
        dayKey: String
    ) throws -> StoredDailyCheckIn? {
        var request =
            FetchDescriptor<StoredDailyCheckIn>(
                predicate:
                    #Predicate<StoredDailyCheckIn> {
                        checkIn in

                        checkIn.dayKey == dayKey
                    }
            )

        request.fetchLimit = 1

        return try modelContext
            .fetch(request)
            .first
    }

    private func combinedCoverage(
        _ values: [DataCoverage],
        expectedDayCount: Int
    ) -> DataCoverage {
        if values.contains(.unavailable) {
            return .unavailable
        }

        let hasEveryExpectedDay =
            values.count == expectedDayCount

        let everyDayIsConfirmed = values.allSatisfy {
            $0 == .confirmed
        }

        if hasEveryExpectedDay
            && everyDayIsConfirmed {
            return .confirmed
        }

        return .partial
    }

    private func makeCalendar(
        using settings: AppSettings
    ) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone =
            TimeZone(
                identifier:
                    settings.analysisTimeZoneIdentifier
            ) ?? .current

        return calendar
    }

    private func activityDayStart(
        containing date: Date,
        calendar: Calendar,
        startHour: Int
    ) -> Date {
        let safeStartHour = min(
            8,
            max(0, startHour)
        )

        let calendarMidnight =
            calendar.startOfDay(for: date)

        let todayBoundary =
            calendar.date(
                byAdding: .hour,
                value: safeStartHour,
                to: calendarMidnight
            ) ?? calendarMidnight

        if date >= todayBoundary {
            return todayBoundary
        }

        let previousMidnight =
            calendar.date(
                byAdding: .day,
                value: -1,
                to: calendarMidnight
            ) ?? calendarMidnight

        return calendar.date(
            byAdding: .hour,
            value: safeStartHour,
            to: previousMidnight
        ) ?? previousMidnight
    }

    private func makeDayKey(
        forActivityDayStarting dayStart: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: dayStart
        )

        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0

        return String(
            format: "%04d-%02d-%02d",
            year,
            month,
            day
        )
    }
    
    func setWorkoutRolePreference(
        activityTypeRawValue: Int,
        role: WorkoutRole?
    ) throws {
        var preferenceRequest =
            FetchDescriptor<WorkoutRolePreference>(
                predicate:
                    #Predicate<WorkoutRolePreference> {
                        preference in

                        preference.activityTypeRawValue
                            == activityTypeRawValue
                    }
            )

        preferenceRequest.fetchLimit = 1

        let existingPreference =
            try modelContext
                .fetch(preferenceRequest)
                .first

        let validOverride: WorkoutRole?

        if let role,
           role != .unknown {
            validOverride = role
        } else {
            validOverride = nil
        }

        if let validOverride {
            if let existingPreference {
                existingPreference.workoutRole =
                    validOverride
            } else {
                let newPreference =
                    WorkoutRolePreference(
                        activityTypeRawValue:
                            activityTypeRawValue,
                        workoutRole:
                            validOverride
                    )

                modelContext.insert(newPreference)
            }
        } else if let existingPreference {

            modelContext.delete(existingPreference)
        }

        let effectiveDecision =
            WorkoutClassifier.classify(
                activityTypeRawValue:
                    activityTypeRawValue,
                settingsOverride:
                    validOverride
                
            )

        let workoutRequest =
            FetchDescriptor<StoredWorkout>(
                predicate:
                    #Predicate<StoredWorkout> {
                        workout in

                        workout.activityTypeRawValue
                            == activityTypeRawValue
                    }
            )

        let matchingWorkouts =
            try modelContext.fetch(workoutRequest)

        for workout in matchingWorkouts {
            /*
             Preserve a deliberate override made on one specific
             workout.
             */
            guard workout.workoutRoleSource
                != .userReview
            else {
                continue
            }

            workout.workoutRole =
                effectiveDecision.role

            workout.workoutRoleSource =
                effectiveDecision.source
        }

        if
            let earliestDate =
                matchingWorkouts
                    .map(\.startDate)
                    .min(),
            let latestDate =
                matchingWorkouts
                    .map(\.startDate)
                    .max()
        {
            try rebuildDailyActivityRecords(
                from: earliestDate,
                through: latestDate
            )
        }    }
    
    func reviewWorkout(
        _ workout: StoredWorkout,
        role: WorkoutRole,
        intensity: WorkoutIntensityChoice?,
        aerobicMinutes: Double,
        moderateMinutes: Double,
        vigorousMinutes: Double
    ) throws {
        guard role != .unknown else {
            throw WorkoutReviewError.roleRequired
        }

        workout.workoutRole = role
        workout.workoutRoleSource = .userReview

        guard role.includesAerobic else {

            workout.moderateMinutes = nil
            workout.vigorousMinutes = nil
            workout.intensitySourceRawValue =
                "notApplicable"

            try modelContext.save()

            try rebuildDailyActivityRecords(
                from: workout.startDate,
                through: workout.startDate
            )

            return
        }

        guard let intensity else {
            throw WorkoutReviewError
                .intensityRequired
        }

        let workoutDuration =
            workout.durationMinutes

        let reviewedModerate: Double
        let reviewedVigorous: Double

        switch intensity {
        case .light:

            reviewedModerate = 0
            reviewedVigorous = 0

        case .moderate:
            guard aerobicMinutes.isFinite,
                  aerobicMinutes > 0
            else {
                throw WorkoutReviewError
                    .invalidMinutes
            }

            reviewedModerate = aerobicMinutes
            reviewedVigorous = 0

        case .vigorous:
            guard aerobicMinutes.isFinite,
                  aerobicMinutes > 0
            else {
                throw WorkoutReviewError
                    .invalidMinutes
            }

            reviewedModerate = 0
            reviewedVigorous = aerobicMinutes

        case .mixed:
            guard moderateMinutes.isFinite,
                  vigorousMinutes.isFinite,
                  moderateMinutes >= 0,
                  vigorousMinutes >= 0,
                  moderateMinutes + vigorousMinutes > 0
            else {
                throw WorkoutReviewError
                    .invalidMinutes
            }

            reviewedModerate = moderateMinutes
            reviewedVigorous = vigorousMinutes
        }

        let reviewedTotal =
            reviewedModerate + reviewedVigorous

        guard reviewedTotal <= workoutDuration + 0.01
        else {
            throw WorkoutReviewError
                .minutesExceedWorkout
        }

        workout.moderateMinutes =
            reviewedModerate

        workout.vigorousMinutes =
            reviewedVigorous

        workout.intensitySourceRawValue =
            "userReviewed"

        try modelContext.save()

        try rebuildDailyActivityRecords(
            from: workout.startDate,
            through: workout.startDate
        )    }
    
    @discardableResult
    func updateActivityDayStartHour(
        _ requestedHour: Int,
        now: Date = .now
    ) throws -> Bool {
        let settings = try loadOrCreateSettings()

        let safeHour = min(
            8,
            max(0, requestedHour)
        )

        guard settings.activityDayStartHour
            != safeHour
        else {
            return false
        }

        settings.activityDayStartHour =
            safeHour

        settings.updatedAt = now

        /*
         Daily summaries use the old day boundary, so they
         must be rebuilt.

         Stored workouts and workout classifications remain.
         */
        let dailyRecords =
            try modelContext.fetch(
                FetchDescriptor<
                    DailyActivityRecord
                >()
            )

        for record in dailyRecords {
            modelContext.delete(record)
        }

        /*
         A Today selection also belongs to a particular
         activity-day key. Remove it when boundaries change.
         */
        let checkIns =
            try modelContext.fetch(
                FetchDescriptor<
                    StoredDailyCheckIn
                >()
            )

        for checkIn in checkIns {
            modelContext.delete(checkIn)
        }

        try modelContext.save()

        return true
    }
}
