import Foundation

struct HealthKitImportPlan: Sendable {
    let startDate: Date
    let endDate: Date

    let timeZoneIdentifier: String
    let activityDayStartHour: Int
}

struct HealthKitDailyMovementValue: Sendable {
    let dayStart: Date

    let steps: Int?
    let appleExerciseMinutes: Double?
    let standHours: Int?
    let activeEnergyKilocalories: Double?
    let walkingRunningDistanceMeters: Double?
    let cyclingDistanceMeters: Double?
}
