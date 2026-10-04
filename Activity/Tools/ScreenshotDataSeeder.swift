import Foundation
import HealthKit
import SwiftData

enum ScreenshotDataSeeder {
    @MainActor
    static func seed(
        modelContext: ModelContext
    ) throws {
        guard AppRuntime.isScreenshotMode
        else {
            return
        }

        if AppRuntime.screenshotScenario
            == .onboarding {

            modelContext.insert(
                AppSettings(
                    hasCompletedOnboarding:
                        false,
                    analysisTimeZoneIdentifier:
                        "Asia/Kuwait"
                )
            )

            try modelContext.save()
            return
        }

        let now = AppRuntime.now

        var calendar =
            Calendar(identifier: .gregorian)

        calendar.timeZone =
            TimeZone(
                identifier: "Asia/Kuwait"
            )!

        let today =
            calendar.startOfDay(
                for: now
            )

        let settings =
            AppSettings(
                hasCompletedOnboarding:
                    true,
                ageBandRawValue:
                    "18to64",
                usesGeneralAdultGuidance:
                    true,
                analysisTimeZoneIdentifier:
                    "Asia/Kuwait",
                activityDayStartHour: 0,
                showActiveEnergy: true,
                showStandHours: true,
                showDistance: true,
                createdAt: now,
                updatedAt: now,
                aerobicTargetMinutes: 150,
                strengthTargetDays: 2,
                usesCustomActivityTargets:
                    false
            )

        modelContext.insert(settings)

        let recentAerobicMinutes: [Double]
        let recentStrengthIndexes: Set<Int>

        switch AppRuntime.screenshotScenario {
        case .covered:
            /*
             Safely covered: 150 aerobic minutes remain even
             after the oldest two days leave the window.
             */
            recentAerobicMinutes = [
                0,
                0,
                32,
                28,
                26,
                34,
                30
            ]

            recentStrengthIndexes = [
                2,
                5
            ]

        default:
            /*
             Recommendation: aerobic target reached while
             strength remains unfinished.
             */
            recentAerobicMinutes = [
                32,
                0,
                30,
                38,
                0,
                40,
                24
            ]

            recentStrengthIndexes = []
        }

        let recentSteps: [Int] = [
            8_200,
            7_600,
            8_800,
            9_100,
            6_900,
            9_300,
            8_970
        ]

        let usualAerobicMinutes:
            [Double] = [
                28,
                18,
                24,
                32,
                14,
                30,
                14
            ]

        let usualSteps: [Int] = [
            7_800,
            8_200,
            7_600,
            8_500,
            8_100,
            7_900,
            8_040
        ]

        for daysAgo in stride(
            from: 96,
            through: 0,
            by: -1
        ) {
            guard let dayStart =
                    calendar.date(
                        byAdding: .day,
                        value: -daysAgo,
                        to: today
                    )
            else {
                continue
            }

            let isRecent =
                daysAgo <= 6

            let patternIndex: Int

            if isRecent {
                patternIndex =
                    6 - daysAgo
            } else {
                patternIndex =
                    calendar.component(
                        .weekday,
                        from: dayStart
                    ) - 1
            }

            let moderateMinutes =
                isRecent
                ? recentAerobicMinutes[
                    patternIndex
                ]
                : usualAerobicMinutes[
                    patternIndex
                ]

            let steps =
                isRecent
                ? recentSteps[patternIndex]
                : usualSteps[patternIndex]

            let weekday =
                calendar.component(
                    .weekday,
                    from: dayStart
                )

            /*
             The current seven days intentionally contain
             no confirmed strength day, producing the
             established "Room to build" design.

             Older history averages about two strength
             days per week for Trends.
             */
            let isStrengthDay: Bool

            if isRecent {
                isStrengthDay =
                    recentStrengthIndexes.contains(
                        patternIndex
                    )
            } else {
                isStrengthDay =
                    weekday == 3
                    || weekday == 6
            }

            let key =
                dayKey(
                    for: dayStart,
                    calendar: calendar
                )

            modelContext.insert(
                DailyActivityRecord(
                    dayKey: key,
                    dayStart: dayStart,
                    moderateMinutes:
                        moderateMinutes,
                    vigorousMinutes: 0,
                    unknownIntensityMinutes:
                        0,
                    strengthWorkoutCount:
                        isStrengthDay ? 1 : 0,
                    recordedSteps: steps,
                    appleExerciseMinutes:
                        moderateMinutes,
                    standHours:
                        9
                        + (
                            patternIndex % 3
                        ),
                    activeEnergyKilocalories:
                        430
                        + Double(
                            patternIndex * 14
                        ),
                    walkingRunningDistanceMeters:
                        5_900
                        + Double(
                            patternIndex * 180
                        ),
                    cyclingDistanceMeters:
                        nil,
                    aerobicCoverage:
                        .confirmed,
                    strengthCoverage:
                        .confirmed,
                    lastCalculatedAt: now
                )
            )
        }
        if AppRuntime.screenshotScenario
            == .recovery {

            modelContext.insert(
                StoredDailyCheckIn(
                    dayKey:
                        dayKey(
                            for: today,
                            calendar: calendar
                        ),
                    wantsRecovery: true,
                    reportsLowMovement: false,
                    updatedAt: now
                )
            )
        }
        seedRecentWorkouts(
            modelContext:
                modelContext,
            now: now,
            calendar: calendar
        )

        try modelContext.save()
    }

    @MainActor
    private static func seedRecentWorkouts(
        modelContext: ModelContext,
        now: Date,
        calendar: Calendar
    ) {
        let today =
            calendar.startOfDay(
                for: now
            )

        let walkStart =
            calendar.date(
                bySettingHour: 9,
                minute: 12,
                second: 0,
                of: today
            )!

        modelContext.insert(
            StoredWorkout(
                healthKitUUID:
                    "screenshot-walk",
                startDate: walkStart,
                endDate:
                    walkStart
                    .addingTimeInterval(
                        24 * 60
                    ),
                recordedDurationMinutes: 24,
                activityTypeRawValue:
                    Int(
                        HKWorkoutActivityType
                            .walking
                            .rawValue
                    ),
                sourceName: "Apple Watch",
                sourceBundleIdentifier:
                    "com.apple.health",
                importedAt: now,
                workoutRole: .aerobic,
                workoutRoleSource:
                    .automatic,
                moderateMinutes: 24,
                vigorousMinutes: 0,
                intensitySourceRawValue:
                    "screenshot"
            )
        )

        let strengthStart =
            calendar.date(
                byAdding: .day,
                value: -6,
                to: today
            )!
            .addingTimeInterval(
                17 * 60 * 60
            )

        modelContext.insert(
            StoredWorkout(
                healthKitUUID:
                    "screenshot-strength",
                startDate: strengthStart,
                endDate:
                    strengthStart
                    .addingTimeInterval(
                        32 * 60
                    ),
                recordedDurationMinutes: 32,
                activityTypeRawValue:
                    Int(
                        HKWorkoutActivityType
                            .functionalStrengthTraining
                            .rawValue
                    ),
                sourceName: "Apple Watch",
                sourceBundleIdentifier:
                    "com.apple.health",
                importedAt: now,
                workoutRole: .unknown,
                workoutRoleSource:
                    .unclassified,
                moderateMinutes: nil,
                vigorousMinutes: nil,
                intensitySourceRawValue:
                    "unknown"
            )
        )

        let cycleStart =
            calendar.date(
                byAdding: .day,
                value: -8,
                to: today
            )!
            .addingTimeInterval(
                11 * 60 * 60
            )

        modelContext.insert(
            StoredWorkout(
                healthKitUUID:
                    "screenshot-cycle",
                startDate: cycleStart,
                endDate:
                    cycleStart
                    .addingTimeInterval(
                        41 * 60
                    ),
                recordedDurationMinutes: 41,
                activityTypeRawValue:
                    Int(
                        HKWorkoutActivityType
                            .cycling
                            .rawValue
                    ),
                sourceName: "Apple Watch",
                sourceBundleIdentifier:
                    "com.apple.health",
                importedAt: now,
                workoutRole: .aerobic,
                workoutRoleSource:
                    .automatic,
                moderateMinutes: 31,
                vigorousMinutes: 5,
                intensitySourceRawValue:
                    "screenshot"
            )
        )
    }

    private static func dayKey(
        for date: Date,
        calendar: Calendar
    ) -> String {
        let components =
            calendar.dateComponents(
                [
                    .year,
                    .month,
                    .day
                ],
                from: date
            )

        return String(
            format:
                "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
