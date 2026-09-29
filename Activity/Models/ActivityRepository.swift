

import Foundation
import SwiftData

struct ActivityStripDay:
    Identifiable,
    Sendable {

    let dayStart: Date

    let moderateEquivalentMinutes:
        Double

    let isStrengthDay: Bool
    let hasData: Bool
    let isToday: Bool

    var id: Date {
        dayStart
    }
}

struct DashboardInput {
    let snapshot: ActivitySnapshot
    let checkIn: TodayCheckIn

    let comparison:
        PersonalBaselineComparison
    
    let activityStripDays:
        [ActivityStripDay]

    let targets: ActivityTargets

    let usesCustomActivityTargets: Bool

    let windowStart: Date
    let windowEnd: Date
}

enum ActivityRepositoryError: Error {
    case unableToCreateDateWindow
}


enum ManualWorkoutError: LocalizedError {
    case invalidActivityType
    case invalidDuration
    case workoutNotFinished
    case roleRequired
    case intensityRequired
    case invalidAerobicMinutes
    case aerobicMinutesExceedDuration

    var errorDescription: String? {
        switch self {
        case .invalidActivityType:
            return "Choose a workout type."

        case .invalidDuration:
            return """
            Enter a workout duration between 1 minute \
            and 24 hours.
            """

        case .workoutNotFinished:
            return """
            A manual workout must finish before the \
            current time.
            """

        case .roleRequired:
            return """
            Choose whether the workout was aerobic, \
            strength, both or neither.
            """

        case .intensityRequired:
            return """
            Choose the aerobic intensity.
            """

        case .invalidAerobicMinutes:
            return """
            Enter valid aerobic minutes.
            """

        case .aerobicMinutesExceedDuration:
            return """
            Aerobic minutes cannot be longer than the \
            workout duration.
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
            
            let effectiveRole =
                incoming.manualRole
                    ?? decision.role

            let effectiveRoleSource:
                WorkoutRoleSource =
                    incoming.manualRole == nil
                    ? decision.source
                    : .manualEntry

            let effectiveIntensity:
                AutomaticIntensityResult

            if incoming.manualRole != nil {
                if effectiveRole.includesAerobic {
                    effectiveIntensity =
                        AutomaticIntensityResult(
                            moderateMinutes:
                                incoming
                                    .manualModerateMinutes
                                ?? 0,
                            vigorousMinutes:
                                incoming
                                    .manualVigorousMinutes
                                ?? 0,
                            sourceRawValue:
                                "manualEntry"
                        )
                } else {
                    effectiveIntensity =
                        AutomaticIntensityResult(
                            moderateMinutes: nil,
                            vigorousMinutes: nil,
                            sourceRawValue:
                                "notApplicable"
                        )
                }
            } else {
                effectiveIntensity =
                    effectiveRole.includesAerobic
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
            }

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

                let keepOlderLocalManualEntry =
                    incoming.manualRole == nil
                    && existing.workoutRoleSource
                        == .manualEntry

                if !keepOlderLocalManualEntry {
                    existing.workoutRole =
                        effectiveRole

                    existing.workoutRoleSource =
                        effectiveRoleSource

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
                        effectiveRole,
                    workoutRoleSource:
                        effectiveRoleSource,
                    moderateMinutes:
                        effectiveIntensity
                            .moderateMinutes,
                    vigorousMinutes:
                        effectiveIntensity
                            .vigorousMinutes,
                    intensitySourceRawValue:
                        effectiveIntensity
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

        return WorkoutImportResult(
            insertedCount: insertedCount,
            updatedCount: updatedCount
        )
    }
    
    func deleteStoredWorkout(
        _ workout: StoredWorkout,
        now: Date = .now
    ) throws {
        let startDate = workout.startDate
        let endDate = workout.endDate

        modelContext.delete(workout)
        try modelContext.save()

        try rebuildDailyActivityRecords(
            from: startDate,
            through: endDate,
            calculatedAt: now
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


            let unknownIntensityMinutes = 0.0

            let strengthWorkoutCount =
                dailyWorkouts.filter {
                    $0.countsTowardStrength
                }.count

            let previousRecord =
                recordsByKey[dayKey]

            let aerobicCoverage:
                DataCoverage = .confirmed

            let strengthCoverage:
                DataCoverage = .confirmed


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
        
        let stripWorkouts =
            try fetchStoredWorkouts(
                from: windowStart,
                until: tomorrowStart
            )

        let activityStripDays =
            try makeActivityStripDays(
                records: records,
                workouts: stripWorkouts,
                windowStart: windowStart,
                tomorrowStart: tomorrowStart,
                currentDayKey: currentDayKey,
                calendar: calendar,
                activityDayStartHour:
                    settings.activityDayStartHour
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
                && settings.ageBand
                    .supportsCoreActivityGuidance,
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
            activityStripDays:
                   activityStripDays,
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
    func completeOnboarding(
        ageBand: ActivityAgeBand,
        now: Date = .now
    ) throws {
        guard let defaultTargets =
            ageBand.defaultTargets
        else {
            return
        }

        let settings =
            try loadOrCreateSettings()

        settings.ageBand = ageBand

        settings.aerobicTargetMinutes =
            defaultTargets
                .aerobicMinimumMinutes

        settings.strengthTargetDays =
            defaultTargets
                .strengthMinimumDays

        settings.usesCustomActivityTargets =
            false

        settings.hasCompletedOnboarding =
            true

        settings.updatedAt = now

        try modelContext.save()
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
        let allWorkouts =
            try modelContext.fetch(
                FetchDescriptor<StoredWorkout>()
            )

        return allWorkouts
            .filter { workout in
                workout.startDate >= startDate
                    && workout.startDate < endDate
            }
            .sorted { first, second in
                first.startDate < second.startDate
            }
    }

    private func fetchDailyRecords(
        from startDate: Date,
        until endDate: Date
    ) throws -> [DailyActivityRecord] {

        let allRecords =
            try modelContext.fetch(
                FetchDescriptor<DailyActivityRecord>()
            )

        return allRecords
            .filter { record in
                record.dayStart >= startDate
                    && record.dayStart < endDate
            }
            .sorted { first, second in
                first.dayStart < second.dayStart
            }
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

    private func makeActivityStripDays(
        records: [DailyActivityRecord],
        workouts: [StoredWorkout],
        windowStart: Date,
        tomorrowStart: Date,
        currentDayKey: String,
        calendar: Calendar,
        activityDayStartHour: Int
    ) throws -> [ActivityStripDay] {
        let recordsByKey =
            Dictionary(
                uniqueKeysWithValues:
                    records.map { record in
                        (
                            record.dayKey,
                            record
                        )
                    }
            )

        let workoutsByKey =
            Dictionary(
                grouping: workouts
            ) { workout in
                let workoutDayStart =
                    activityDayStart(
                        containing:
                            workout.startDate,
                        calendar: calendar,
                        startHour:
                            activityDayStartHour
                    )

                return makeDayKey(
                    forActivityDayStarting:
                        workoutDayStart,
                    calendar: calendar
                )
            }

        var result: [ActivityStripDay] = []
        var dayStart = windowStart

        while dayStart < tomorrowStart {
            let dayKey =
                makeDayKey(
                    forActivityDayStarting:
                        dayStart,
                    calendar: calendar
                )

            let record =
                recordsByKey[dayKey]

            let dailyWorkouts =
                workoutsByKey[dayKey] ?? []


            let hasMovementData =
                record.map { record in
                    record.recordedSteps != nil
                        || record
                            .appleExerciseMinutes
                            != nil
                        || record.standHours != nil
                        || record
                            .activeEnergyKilocalories
                            != nil
                        || record
                            .walkingRunningDistanceMeters
                            != nil
                        || record
                            .cyclingDistanceMeters
                            != nil
                } ?? false

            let hasData =
                hasMovementData
                || !dailyWorkouts.isEmpty

            result.append(
                ActivityStripDay(
                    dayStart: dayStart,
                    moderateEquivalentMinutes:
                        record?
                            .guidelineModerateEquivalentMinutes
                        ?? 0,
                    isStrengthDay:
                        record?.isStrengthDay
                        ?? dailyWorkouts.contains {
                            $0.countsTowardStrength
                        },
                    hasData: hasData,
                    isToday:
                        dayKey == currentDayKey
                )
            )
            

            guard let nextDay =
                calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: dayStart
                )
            else {
                throw ActivityRepositoryError
                    .unableToCreateDateWindow
            }

            dayStart = nextDay
        }

        return result
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
            let previouslyIncludedAerobic =
                workout.workoutRole
                    .includesAerobic

            workout.workoutRole =
                effectiveDecision.role

            workout.workoutRoleSource =
                effectiveDecision.source

            if effectiveDecision.role
                .includesAerobic {
                let hasUsableIntensity =
                    workout.moderateMinutes != nil
                    || workout.vigorousMinutes != nil

                if !previouslyIncludedAerobic
                    || !hasUsableIntensity {

                    workout.moderateMinutes =
                        workout.durationMinutes

                    workout.vigorousMinutes = 0

                    workout.intensitySourceRawValue =
                        "workoutDurationConservative"
                }
            } else {

                workout.moderateMinutes = nil
                workout.vigorousMinutes = nil

                workout.intensitySourceRawValue =
                    "notApplicable"
            }
        }

        try modelContext.save()

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
    func resetAllWorkoutRolePreferences()
        throws {

        let preferences =
            try modelContext.fetch(
                FetchDescriptor<
                    WorkoutRolePreference
                >()
            )

        for preference in preferences {
            modelContext.delete(preference)
        }

        let workouts =
            try modelContext.fetch(
                FetchDescriptor<StoredWorkout>()
            )

        let importedWorkouts =
            workouts.filter {
                $0.workoutRoleSource
                    != .manualEntry
            }

        for workout in importedWorkouts {
            let previouslyIncludedAerobic =
                workout.workoutRole
                    .includesAerobic

            let defaultDecision =
                WorkoutClassifier.classify(
                    activityTypeRawValue:
                        workout.activityTypeRawValue,
                    settingsOverride: nil
                )

            workout.workoutRole =
                defaultDecision.role

            workout.workoutRoleSource =
                defaultDecision.source

            if defaultDecision.role
                .includesAerobic {

                let hasUsableIntensity =
                    workout.moderateMinutes != nil
                    || workout.vigorousMinutes != nil

                if !previouslyIncludedAerobic
                    || !hasUsableIntensity {

                    workout.moderateMinutes =
                        workout.durationMinutes

                    workout.vigorousMinutes = 0

                    workout.intensitySourceRawValue =
                        "workoutDurationConservative"
                }
            } else {
                workout.moderateMinutes = nil
                workout.vigorousMinutes = nil

                workout.intensitySourceRawValue =
                    "notApplicable"
            }
        }

        try modelContext.save()

        if
            let earliestDate =
                importedWorkouts
                    .map(\.startDate)
                    .min(),
            let latestDate =
                importedWorkouts
                    .map(\.startDate)
                    .max()
        {
            try rebuildDailyActivityRecords(
                from: earliestDate,
                through: latestDate
            )
        }
    }
    
    
    @discardableResult
    func addManualWorkout(
        healthKitUUID: String? = nil,
        activityTypeRawValue: Int,
        startDate: Date,
        durationMinutes: Double,
        role: WorkoutRole,
        intensity: WorkoutIntensityChoice?,
        aerobicMinutes: Double,
        moderateMinutes: Double,
        vigorousMinutes: Double,
        now: Date = .now
    ) throws -> StoredWorkout {
        guard WorkoutTypeCatalog.definition(
            forRawValue: activityTypeRawValue
        ) != nil else {
            throw ManualWorkoutError
                .invalidActivityType
        }

        guard durationMinutes.isFinite,
              durationMinutes >= 1,
              durationMinutes <= 1_440
        else {
            throw ManualWorkoutError
                .invalidDuration
        }

        let endDate =
            startDate.addingTimeInterval(
                durationMinutes * 60
            )

        guard endDate <=
            now.addingTimeInterval(60)
        else {
            throw ManualWorkoutError
                .workoutNotFinished
        }

        guard role != .unknown else {
            throw ManualWorkoutError
                .roleRequired
        }

        let savedModerateMinutes: Double?
        let savedVigorousMinutes: Double?
        let intensitySource: String

        if role.includesAerobic {
            guard let intensity else {
                throw ManualWorkoutError
                    .intensityRequired
            }

            let calculatedModerate: Double
            let calculatedVigorous: Double

            switch intensity {
            case .light:
                calculatedModerate = 0
                calculatedVigorous = 0

            case .moderate:
                guard aerobicMinutes.isFinite,
                      aerobicMinutes > 0
                else {
                    throw ManualWorkoutError
                        .invalidAerobicMinutes
                }

                calculatedModerate =
                    aerobicMinutes

                calculatedVigorous = 0

            case .vigorous:
                guard aerobicMinutes.isFinite,
                      aerobicMinutes > 0
                else {
                    throw ManualWorkoutError
                        .invalidAerobicMinutes
                }

                calculatedModerate = 0

                calculatedVigorous =
                    aerobicMinutes

            case .mixed:
                guard moderateMinutes.isFinite,
                      vigorousMinutes.isFinite,
                      moderateMinutes >= 0,
                      vigorousMinutes >= 0,
                      moderateMinutes
                        + vigorousMinutes > 0
                else {
                    throw ManualWorkoutError
                        .invalidAerobicMinutes
                }

                calculatedModerate =
                    moderateMinutes

                calculatedVigorous =
                    vigorousMinutes
            }

            guard calculatedModerate
                    + calculatedVigorous
                    <= durationMinutes + 0.01
            else {
                throw ManualWorkoutError
                    .aerobicMinutesExceedDuration
            }

            savedModerateMinutes =
                calculatedModerate

            savedVigorousMinutes =
                calculatedVigorous

            intensitySource = "manualEntry"
        } else {
            savedModerateMinutes = nil
            savedVigorousMinutes = nil
            intensitySource = "notApplicable"
        }

        let workout = StoredWorkout(
            healthKitUUID:
                healthKitUUID
                    ?? "manual:\(UUID().uuidString)",
            startDate: startDate,
            endDate: endDate,
            recordedDurationMinutes:
                durationMinutes,
            activityTypeRawValue:
                activityTypeRawValue,
            sourceName: "Manual entry",
            sourceBundleIdentifier:
                "activity.manual",
            importedAt: now,
            workoutRole: role,
            workoutRoleSource:
                .manualEntry,
            moderateMinutes:
                savedModerateMinutes,
            vigorousMinutes:
                savedVigorousMinutes,
            intensitySourceRawValue:
                intensitySource
        )

        modelContext.insert(workout)
        try modelContext.save()

        try rebuildDailyActivityRecords(
            from: startDate,
            through: endDate,
            calculatedAt: now
        )

        return workout
    }
    
    
    
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
