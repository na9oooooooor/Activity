import Foundation
import HealthKit

struct WorkoutRoleDecision {
    let role: WorkoutRole
    let source: WorkoutRoleSource

    var needsReview: Bool {
        role == .unknown
    }
}

enum WorkoutClassifier {
    static func classify(
        activityTypeRawValue: Int,
        settingsOverride: WorkoutRole? = nil
    ) -> WorkoutRoleDecision {
        /*
         A user setting works even when this app version
         does not recognize the workout type.
         */
        if let settingsOverride,
           settingsOverride != .unknown {
            return WorkoutRoleDecision(
                role: settingsOverride,
                source: .settingsOverride
            )
        }

        guard WorkoutTypeCatalog.definition(
            forRawValue: activityTypeRawValue
        ) != nil else {
            return WorkoutRoleDecision(
                role: .unknown,
                source: .unclassified
            )
        }

        guard
            let unsignedRawValue = UInt(
                exactly: activityTypeRawValue
            ),
            let activityType =
                HKWorkoutActivityType(
                    rawValue: unsignedRawValue
                )
        else {
            return WorkoutRoleDecision(
                role: .unknown,
                source: .unclassified
            )
        }

        return WorkoutRoleDecision(
            role: defaultRole(
                for: activityType
            ),
            source: .automatic
        )
    }

    static func defaultRole(
        for activityType: HKWorkoutActivityType
    ) -> WorkoutRole {
        switch activityType {
        case .traditionalStrengthTraining,
             .functionalStrengthTraining,
             .coreTraining:
            return .strength

        case .preparationAndRecovery,
             .flexibility,
             .cooldown,
             .yoga,
             .mindAndBody,
             .pilates,
             .barre,
             .taiChi,
             .transition,
             .other:
            return .neither

        default:
            return .aerobic
        }
    }
}
