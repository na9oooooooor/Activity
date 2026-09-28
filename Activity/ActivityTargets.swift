import Foundation

struct ActivityTargets:
    Sendable,
    Equatable {

    let aerobicMinimumMinutes: Double
    let strengthMinimumDays: Int

    /*
     This remains a research reference. It is not a
     personal score or a maximum safe amount.
     */
    let aerobicAdditionalRangeMinutes: Double

    static let generalAdultGuidance =
        ActivityTargets(
            aerobicMinimumMinutes: 150,
            strengthMinimumDays: 2,
            aerobicAdditionalRangeMinutes: 300
        )
}
