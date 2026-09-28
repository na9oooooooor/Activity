import Foundation

struct PersonalMetricComparison: Sendable {
    let currentValue: Double
    let usualValue: Double
    let percentChange: Double?
}

struct PersonalBaselineComparison: Sendable {
    let aerobic:
        PersonalMetricComparison?

    let steps:
        PersonalMetricComparison?

    let standHours:
        PersonalMetricComparison?
}
