//
//  DashboardInput.swift
//  Activity
//
//  Created by NASER ALALI on 27/09/2026.
//


import Foundation
import SwiftData

struct DashboardInput {
    let snapshot: ActivitySnapshot
    let checkIn: TodayCheckIn

    let windowStart: Date
    let windowEnd: Date
}

enum ActivityRepositoryError: Error {
    case unableToCreateDateWindow
}

@MainActor
final class ActivityRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
            )
        else {
            throw ActivityRepositoryError
                .unableToCreateDateWindow
        }

        let records = try fetchDailyRecords(
            from: windowStart,
            until: tomorrowStart
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
}
