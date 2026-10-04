import Foundation
import Observation
import UserNotifications

enum ReminderPermissionState:
    Equatable {

    case checking
    case notRequested
    case allowed
    case denied
}

private enum SmartReminderKind:
    String {

    case aerobicGap
    case strengthGap
    case generalGap
    case movement
    case aerobicExpiry
    case strengthExpiry
    case bothExpiry
}

private struct SmartReminderPlan {
    let kind: SmartReminderKind
    let body: String
    let minimumDaysFromNow: Int
}

@MainActor
@Observable
final class ReminderService {
    static let enabledKey =
        "enough.reminders.enabled"

    static let hourKey =
        "enough.reminders.hour"

    static let minuteKey =
        "enough.reminders.minute"

    static let nextDateKey =
        "enough.reminders.nextDate"

    private static let lastPlannedDateKey =
        "enough.reminders.lastPlannedDate"

    private static let requestIdentifier =
        "enough.smart-reminder"

    private let center =
        UNUserNotificationCenter.current()

    private let defaults =
        UserDefaults.standard

    private(set) var permissionState:
        ReminderPermissionState = .checking

    private(set) var errorMessage:
        String?

    func refreshPermission() async {
        let settings =
            await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            permissionState = .notRequested

        case .authorized,
             .provisional,
             .ephemeral:
            permissionState = .allowed

        case .denied:
            permissionState = .denied

        @unknown default:
            permissionState = .denied
        }
    }

    func requestPermission() async -> Bool {
        errorMessage = nil

        do {
            _ = try await center
                .requestAuthorization(
                    options: [
                        .alert,
                        .sound
                    ]
                )

            await refreshPermission()

            return permissionState == .allowed
        } catch {
            errorMessage =
                error.localizedDescription

            await refreshPermission()

            return false
        }
    }

    @discardableResult
    func updateSmartReminder(
        enabled: Bool,
        preferredHour: Int,
        preferredMinute: Int,
        snapshot: ActivitySnapshot?,
        assessment: ActivityAssessment?,
        now: Date = .now
    ) async -> Date? {
        await refreshPermission()

        guard enabled,
              permissionState == .allowed,
              let snapshot,
              let assessment
        else {
            cancelScheduledReminder()
            return nil
        }

        guard let plan = makePlan(
            snapshot: snapshot,
            assessment: assessment
        ) else {
            cancelScheduledReminder()
            return nil
        }

        guard let notificationDate =
                plannedDate(
                    minimumDaysFromNow:
                        plan.minimumDaysFromNow,
                    preferredHour:
                        preferredHour,
                    preferredMinute:
                        preferredMinute,
                    now: now
                )
        else {
            cancelScheduledReminder()
            return nil
        }

        return await schedule(
            plan: plan,
            at: notificationDate
        )
    }

    func cancelScheduledReminder() {
        let oldWeekdayIdentifiers =
            (1...7).map {
                "enough.reminder.\($0)"
            }

        center.removePendingNotificationRequests(
            withIdentifiers:
                [
                    Self.requestIdentifier
                ] + oldWeekdayIdentifiers
        )

        defaults.set(
            0,
            forKey: Self.nextDateKey
        )
    }

    private func makePlan(
        snapshot: ActivitySnapshot,
        assessment: ActivityAssessment
    ) -> SmartReminderPlan? {
        switch assessment
            .recommendation
            .reason {

        case .bothTargetsExpiringSoon:
            return SmartReminderPlan(
                kind: .bothExpiry,
                body:
                    """
                    Your rolling week may change soon. \
                    See what may need replacing.
                    """,
                minimumDaysFromNow: 0
            )

        case .aerobicCoverageExpiringSoon:
            return SmartReminderPlan(
                kind: .aerobicExpiry,
                body:
                    """
                    Some aerobic activity may leave your \
                    rolling week soon.
                    """,
                minimumDaysFromNow: 0
            )

        case .strengthCoverageExpiringSoon:
            return SmartReminderPlan(
                kind: .strengthExpiry,
                body:
                    """
                    A strength day may leave your rolling \
                    week soon.
                    """,
                minimumDaysFromNow: 0
            )

        case .aerobicGap:
            return SmartReminderPlan(
                kind: .aerobicGap,
                body:
                    """
                    A little aerobic activity may help \
                    complete your rolling week.
                    """,
                minimumDaysFromNow:
                    daysUntilGapReminder(
                        snapshot:
                            snapshot,
                        threshold: 2
                    )
            )

        case .strengthGap:
            return SmartReminderPlan(
                kind: .strengthGap,
                body:
                    """
                    A little strength activity may help \
                    complete your rolling week.
                    """,
                minimumDaysFromNow:
                    daysUntilGapReminder(
                        snapshot:
                            snapshot,
                        threshold: 2
                    )
            )

        case .smallRemainingGap:
            return SmartReminderPlan(
                kind: .generalGap,
                body:
                    """
                    You are close to enough. See what could \
                    complete your rolling week.
                    """,
                minimumDaysFromNow:
                    daysUntilGapReminder(
                        snapshot:
                            snapshot,
                        threshold: 3
                    )
            )

        case .movementBelowUsual:
            return SmartReminderPlan(
                kind: .movement,
                body:
                    """
                    A little movement may feel useful today.
                    """,
                minimumDaysFromNow: 0
            )

        /*
         Do not notify in these states.

         This includes safely covered targets, Recovery,
         incomplete data and activity already completed today.
         */
        case .targetsMet,
             .recentStrengthSession,
             .aerobicSessionAlreadyCompleted,
             .lowMovement,
             .recoveryChoice,
             .unavailableRecords,
             .staleRecords,
             .importing,
             .outsideGuidedScope:
            return nil
        }
    }

    private func daysUntilGapReminder(
        snapshot: ActivitySnapshot,
        threshold: Int
    ) -> Int {
        guard let inactiveDays =
                snapshot
                    .daysSinceLastTargetActivity
        else {
            /*
             No qualifying activity was found.
             The next preferred time is appropriate.
             */
            return 0
        }

        return max(
            0,
            threshold - inactiveDays
        )
    }

    private func plannedDate(
        minimumDaysFromNow: Int,
        preferredHour: Int,
        preferredMinute: Int,
        now: Date
    ) -> Date? {
        let calendar =
            Calendar.autoupdatingCurrent

        guard let earliestDay =
                calendar.date(
                    byAdding: .day,
                    value:
                        max(
                            0,
                            minimumDaysFromNow
                        ),
                    to:
                        calendar.startOfDay(
                            for: now
                        )
                )
        else {
            return nil
        }

        let initialEarliestDate: Date

        if minimumDaysFromNow == 0 {
            /*
             Avoid firing immediately while the person
             is currently using the app.
             */
            initialEarliestDate =
                now.addingTimeInterval(
                    15 * 60
                )
        } else {
            initialEarliestDate =
                earliestDay
        }

        guard var candidate =
                preferredDate(
                    onOrAfter:
                        initialEarliestDate,
                    hour:
                        preferredHour,
                    minute:
                        preferredMinute,
                    calendar:
                        calendar
                )
        else {
            return nil
        }

        let lastTimestamp =
            defaults.double(
                forKey:
                    Self.lastPlannedDateKey
            )

        if lastTimestamp > 0 {
            let lastPlannedDate =
                Date(
                    timeIntervalSince1970:
                        lastTimestamp
                )

            /*
             Only apply the cooldown after the previous
             planned delivery time has passed.

             Sixty hours normally becomes three days once
             aligned to the chosen reminder time.
             */
            if lastPlannedDate <= now {
                let cooldownEnd =
                    lastPlannedDate
                        .addingTimeInterval(
                            60 * 60 * 60
                        )

                if candidate < cooldownEnd,
                   let cooledCandidate =
                        preferredDate(
                            onOrAfter:
                                cooldownEnd,
                            hour:
                                preferredHour,
                            minute:
                                preferredMinute,
                            calendar:
                                calendar
                        ) {

                    candidate =
                        cooledCandidate
                }
            }
        }

        return candidate
    }

    private func preferredDate(
        onOrAfter earliestDate: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date? {
        let safeHour =
            min(23, max(0, hour))

        let safeMinute =
            min(59, max(0, minute))

        var components =
            calendar.dateComponents(
                [
                    .year,
                    .month,
                    .day
                ],
                from: earliestDate
            )

        components.hour = safeHour
        components.minute = safeMinute
        components.second = 0
        components.timeZone =
            TimeZone.autoupdatingCurrent

        guard var candidate =
                calendar.date(
                    from: components
                )
        else {
            return nil
        }

        if candidate < earliestDate {
            candidate =
                calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: candidate
                ) ?? candidate
        }

        return candidate
    }

    private func schedule(
        plan: SmartReminderPlan,
        at date: Date
    ) async -> Date? {
        errorMessage = nil

        cancelScheduledReminder()

        let content =
            UNMutableNotificationContent()

        content.title = "Enough"
        content.body = plan.body
        content.sound = .default

        content.threadIdentifier =
            "enough.activity-reminders"

        content.userInfo = [
            "kind": plan.kind.rawValue
        ]

        var components =
            Calendar.autoupdatingCurrent
                .dateComponents(
                    [
                        .year,
                        .month,
                        .day,
                        .hour,
                        .minute
                    ],
                    from: date
                )

        components.timeZone =
            TimeZone.autoupdatingCurrent

        let trigger =
            UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

        let request =
            UNNotificationRequest(
                identifier:
                    Self.requestIdentifier,
                content: content,
                trigger: trigger
            )

        do {
            try await center.add(request)

            let timestamp =
                date.timeIntervalSince1970

            defaults.set(
                timestamp,
                forKey:
                    Self.nextDateKey
            )

            defaults.set(
                timestamp,
                forKey:
                    Self.lastPlannedDateKey
            )

            return date
        } catch {
            errorMessage =
                error.localizedDescription

            cancelScheduledReminder()

            return nil
        }
    }
}
