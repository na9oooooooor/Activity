import Foundation

struct ActivityRuleConfiguration: Equatable, Sendable {
    let aerobicTargetMinutes: Double
    let upperAerobicReferenceMinutes: Double
    let strengthTargetDays: Int

    let workoutPromptGapMinutes: Double
    let completedSessionThresholdMinutes: Double
    let movementComparisonRatio: Double
    let movementContextCeilingSteps: Double
    
    init(
        aerobicTargetMinutes: Double,
        upperAerobicReferenceMinutes: Double,
        strengthTargetDays: Int,
        workoutPromptGapMinutes: Double,
        completedSessionThresholdMinutes: Double,
        movementComparisonRatio: Double = 0.70,
        movementContextCeilingSteps: Double = 7_000
    ) {
        self.aerobicTargetMinutes =
            aerobicTargetMinutes

        self.upperAerobicReferenceMinutes =
            upperAerobicReferenceMinutes

        self.strengthTargetDays =
            strengthTargetDays

        self.workoutPromptGapMinutes =
            workoutPromptGapMinutes

        self.completedSessionThresholdMinutes =
            completedSessionThresholdMinutes

        self.movementComparisonRatio =
            movementComparisonRatio

        self.movementContextCeilingSteps =
            movementContextCeilingSteps
    }
    
    static let version1 =
        ActivityRuleConfiguration(
            aerobicTargetMinutes: 150,
            upperAerobicReferenceMinutes: 300,
            strengthTargetDays: 2,
            workoutPromptGapMinutes: 30,
            completedSessionThresholdMinutes: 20,
            movementComparisonRatio: 0.70,
            movementContextCeilingSteps: 7_000
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
                20,
            movementComparisonRatio: 0.70,
            movementContextCeilingSteps: 7_000
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
            && !snapshot
                .strengthRecordedTodayOrYesterday {

            return TodayRecommendation(
                outcome: .workoutRecommended,
                reason: .strengthGap
            )
        }

        let aerobicGap =
            max(
                0,
                configuration.aerobicTargetMinutes
                    - snapshot
                        .moderateEquivalentMinutes
            )

        if aerobicGap
            >= configuration.workoutPromptGapMinutes
            && snapshot.aerobicMinutesCompletedToday
                < configuration
                    .completedSessionThresholdMinutes {

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
                && snapshot
                    .aerobicMinutesCompletedToday
                    >= configuration
                        .completedSessionThresholdMinutes {

                return TodayRecommendation(
                    outcome: .activityRecommended,
                    reason:
                        .aerobicSessionAlreadyCompleted
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

        let aerobicMinutesAfterExpiry =
            max(
                0,
                snapshot
                    .moderateEquivalentMinutes
                    - snapshot
                        .aerobicMinutesExpiringSoon
            )

        let strengthDaysAfterExpiry =
            max(
                0,
                snapshot.strengthDays
                    - snapshot
                        .strengthDaysExpiringSoon
            )

        let aerobicTargetAtRisk =
            aerobicTargetMet
            && aerobicMinutesAfterExpiry
                < configuration
                    .aerobicTargetMinutes

        let strengthTargetAtRisk =
            strengthTargetMet
            && strengthDaysAfterExpiry
                < configuration
                    .strengthTargetDays

        if aerobicTargetAtRisk
            && strengthTargetAtRisk {

            return TodayRecommendation(
                outcome: .activityRecommended,
                reason: .bothTargetsExpiringSoon
            )
        }

        if strengthTargetAtRisk {
            return TodayRecommendation(
                outcome: .activityRecommended,
                reason:
                    .strengthCoverageExpiringSoon
            )
        }

        if aerobicTargetAtRisk {
            return TodayRecommendation(
                outcome: .activityRecommended,
                reason:
                    .aerobicCoverageExpiringSoon
            )
        }

        if let recentAverageSteps =
                snapshot.recentAverageSteps,
           let usualAverageSteps =
                snapshot.usualAverageSteps,
           usualAverageSteps > 0,
           recentAverageSteps
                < usualAverageSteps
                    * configuration
                        .movementComparisonRatio,
           recentAverageSteps
                < configuration
                    .movementContextCeilingSteps {

            return TodayRecommendation(
                outcome: .activityRecommended,
                reason: .movementBelowUsual
            )
        }

        return TodayRecommendation(
            outcome: .workoutOptional,
            reason: .targetsMet
        )
    }
}
