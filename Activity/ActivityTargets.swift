import Foundation

struct ActivityTargets:
    Sendable,
    Equatable {

    let aerobicMinimumMinutes: Double
    let strengthMinimumDays: Int
    let aerobicAdditionalRangeMinutes: Double

    static let generalAdultGuidance =
        ActivityTargets(
            aerobicMinimumMinutes: 150,
            strengthMinimumDays: 2,
            aerobicAdditionalRangeMinutes: 300
        )
}
