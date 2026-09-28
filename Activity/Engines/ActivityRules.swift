import Foundation

struct ActivityRuleConfiguration: Equatable, Sendable {
    let aerobicTargetMinutes: Double
    let upperAerobicReferenceMinutes: Double
    let strengthTargetDays: Int

    let workoutPromptGapMinutes: Double
    let completedSessionThresholdMinutes: Double

    static let version1 = ActivityRuleConfiguration(
        aerobicTargetMinutes: 150,
        upperAerobicReferenceMinutes: 300,
        strengthTargetDays: 2,
        workoutPromptGapMinutes: 30,
        completedSessionThresholdMinutes: 20
    )
}

extension ActivityRuleConfiguration {
    static func using(
        _ targets: ActivityTargets
    ) -> ActivityRuleConfiguration {
        ActivityRuleConfiguration(
            aerobicTargetMinutes:
                targets.aerobicMinimumMinutes,
            upperAerobicReferenceMinutes:
                targets
                    .aerobicAdditionalRangeMinutes,
            strengthTargetDays:
                targets.strengthMinimumDays,
            workoutPromptGapMinutes:
                30,
            completedSessionThresholdMinutes:
                20
        )
    }
}

enum ActivityRules {
    static func assess(
        snapshot: ActivitySnapshot,
        checkIn: TodayCheckIn,
        configuration: ActivityRuleConfiguration = .version1
    ) -> ActivityAssessment {
        let aerobicMinutes = snapshot.moderateEquivalentMinutes

        let aerobicTargetMet =
            aerobicMinutes >= configuration.aerobicTargetMinutes

        let strengthTargetMet =
            snapshot.strengthDays >= configuration.strengthTargetDays

        let targetsMet = aerobicTargetMet && strengthTargetMet

        let status: ActivityHealthStatus

        switch snapshot.recordState {
        case .importing:
            status = .updating

        case .stale:
            status = .updating

        case .unavailable:
            status = .unavailable

        case .current:
            status =
                targetsMet
                ? .meetingTargets
                : .belowTargets
        }

        let recommendation = makeTodayRecommendation(
            snapshot: snapshot,
            checkIn: checkIn,
            targetsMet: targetsMet,
            aerobicTargetMet: aerobicTargetMet,
            strengthTargetMet: strengthTargetMet,
            configuration: configuration
        )

        return ActivityAssessment(
            status: status,
            recommendation: recommendation,
            aerobicTargetMet: aerobicTargetMet,
            strengthTargetMet: strengthTargetMet,
            aboveAerobicReferenceRange:
                targetsMet
                && aerobicMinutes
                    > configuration.upperAerobicReferenceMinutes
        )
    }

    private static func makeTodayRecommendation(
        snapshot: ActivitySnapshot,
        checkIn: TodayCheckIn,
        targetsMet: Bool,
        aerobicTargetMet: Bool,
        strengthTargetMet: Bool,
        configuration: ActivityRuleConfiguration
    ) -> TodayRecommendation {
        guard snapshot.isInsideGuidedScope else {
            return TodayRecommendation(
                outcome: nil,
                reason: .outsideGuidedScope
            )
        }

        switch snapshot.recordState {
        case .unavailable:
            return TodayRecommendation(
                outcome: nil,
                reason: .unavailableRecords
            )

        case .stale:
            return TodayRecommendation(
                outcome: nil,
                reason: .staleRecords
            )

        case .importing:
            return TodayRecommendation(
                outcome: nil,
                reason: .importing
            )

        case .current:
            break
        }

        if checkIn.wantsRecovery {
            return TodayRecommendation(
                outcome: .recovery,
                reason: .recoveryChoice
            )
        }

        if !strengthTargetMet
            && !snapshot.strengthRecordedTodayOrYesterday {
            return TodayRecommendation(
                outcome: .workoutRecommended,
                reason: .strengthGap
            )
        }

        let aerobicGap = max(
            0,
            configuration.aerobicTargetMinutes
                - snapshot.moderateEquivalentMinutes
        )

        if aerobicGap >= configuration.workoutPromptGapMinutes
            && snapshot.aerobicMinutesCompletedToday
                < configuration.completedSessionThresholdMinutes {
            return TodayRecommendation(
                outcome: .workoutRecommended,
                reason: .aerobicGap
            )
        }

        if !targetsMet {
            if !strengthTargetMet {
                return TodayRecommendation(
                    outcome: .activityRecommended,
                    reason: .recentStrengthSession
                )
            }

            if !aerobicTargetMet
                && snapshot.aerobicMinutesCompletedToday
                    >= configuration.completedSessionThresholdMinutes {
                return TodayRecommendation(
                    outcome: .activityRecommended,
                    reason: .aerobicSessionAlreadyCompleted
                )
            }

            return TodayRecommendation(
                outcome: .activityRecommended,
                reason: .smallRemainingGap
            )
        }

        if checkIn.reportsLowMovement {
            return TodayRecommendation(
                outcome: .activityRecommended,
                reason: .lowMovement
            )
        }

        return TodayRecommendation(
            outcome: .workoutOptional,
            reason: .targetsMet
        )
    }
}
