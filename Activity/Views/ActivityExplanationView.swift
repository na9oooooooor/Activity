import SwiftUI

struct ActivityExplanationView: View {
    let input: DashboardInput
    let assessment: ActivityAssessment
    let recommendationReason: String

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            List {
                statusSection
                aerobicSection
                strengthSection
                rollingWindowSection
                todaySection
                baselineSection
                methodSection
            }
            .navigationTitle(
                "How It’s Calculated"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var rollingWindowSection:
        some View {

        Section("Rolling window") {
            LabeledContent(
                "Current window",
                value:
                    """
                    \(shortDate(input.windowStart))–\
                    \(shortDate(input.windowEnd))
                    """
            )

            LabeledContent(
                "Aerobic leaving soon",
                value:
                    """
                    \(formatted(
                        input.snapshot
                            .aerobicMinutesExpiringSoon
                    )) min
                    """
            )

            LabeledContent(
                "Strength days leaving soon",
                value:
                    input.snapshot
                        .strengthDaysExpiringSoon
                        .formatted()
            )

            Text(
                """
                “Leaving soon” means the activity is on one \
                of the two oldest days in your current \
                seven-day window. It will stop counting as \
                the window moves forward.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
    
    private var statusSection:
        some View {

        Section("Activity Health") {
            Text(assessment.status.rawValue)
                .font(.title2)
                .fontWeight(.semibold)

            Text(
                """
                The status uses aerobic activity and \
                strength frequency from your rolling \
                seven activity days.
                """
            )
            .foregroundStyle(.secondary)
        }
    }

    private var aerobicSection:
        some View {

        Section("Aerobic activity") {
            LabeledContent(
                "Classified moderate",
                value:
                    "\(formatted(input.snapshot.moderateMinutes)) min"
            )
            
            if input.snapshot
                .supplementalAppleExerciseMinutes > 0 {

                LabeledContent(
                    "Other Apple Exercise",
                    value:
                        """
                        \(formatted(
                            input.snapshot
                                .supplementalAppleExerciseMinutes
                        )) min
                        """
                )
            }
            LabeledContent(
                "Vigorous",
                value:
                    "\(formatted(input.snapshot.vigorousMinutes)) min"
            )

            LabeledContent(
                "Moderate-equivalent",
                value:
                    "\(formatted(input.snapshot.moderateEquivalentMinutes)) min"
            )
            .fontWeight(.semibold)

            Text(
                """
                Moderate-equivalent minutes = classified moderate \
                + other Apple Exercise + 2 × vigorous minutes. \
                Activity already represented by classified workouts \
                is removed from Apple Exercise before calculation.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

        }
    }

    private var strengthSection:
        some View {

        Section("Strength") {
            LabeledContent(
                "Recorded days",
                value:
                    """
                    \(input.snapshot.strengthDays) / \
                    \(input.targets.strengthMinimumDays)
                    """
            )
            .fontWeight(.semibold)

            Text(
                """
                Strength counts distinct activity days \
                containing at least one workout classified \
                as Strength or Both.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            Text(
                """
                The app does not infer muscles, sets, or \
                repetitions from HealthKit.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var todaySection:
        some View {

        Section("Today") {
            Text(
                assessment
                    .recommendation
                    .outcome?
                    .rawValue
                ?? "Recommendation unavailable"
            )
            .font(.headline)

            Text(recommendationReason)
                .foregroundStyle(.secondary)
            if let days =
                input.snapshot
                    .daysSinceLastTargetActivity {

                LabeledContent(
                    "Last counted activity",
                    value: recencyText(days)
                )
            } else if input.snapshot.recordState
                        == .current {

                LabeledContent(
                    "Last counted activity",
                    value: "None in the last 7 days"
                )
            }

            Text(
                """
                Counted activity means aerobic minutes or a \
                strength day. This is context, not a streak \
                or an additional target.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            if input.checkIn.wantsRecovery {
                LabeledContent(
                    "Your selection",
                    value: "Recovery"
                )
            } else if input.checkIn
                .reportsLowMovement {

                LabeledContent(
                    "Your selection",
                    value: "Low movement"
                )
            } else {
                LabeledContent(
                    "Your selection",
                    value: "Normal day"
                )
            }

            Text(
                """
                Today’s result interprets recorded activity. \
                It does not measure illness, injury, or \
                medical readiness.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var baselineSection:
        some View {

        Section("Compared with you") {
            baselineRow(
                "Aerobic",
                comparison:
                    input.comparison.aerobic,
                unit: "min/week"
            )

            baselineRow(
                "Steps",
                comparison:
                    input.comparison.steps,
                unit: "steps/day"
            )

            baselineRow(
                "Stand Hours",
                comparison:
                    input.comparison.standHours,
                unit: "hours/day"
            )

            Text(
                """
                The last 7 completed activity days are \
                compared with the preceding 90 completed \
                days. Today is excluded because it is \
                incomplete.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var methodSection:
        some View {

        Section("Reference used") {
            LabeledContent(
                "Aerobic · last 7 days",
                value:
                    """
                    \(formatted(
                        input.targets
                            .aerobicMinimumMinutes
                    )) min
                    """
            )

            LabeledContent(
                "Strength · last 7 days",
                value:
                    """
                    \(input.targets
                        .strengthMinimumDays) days
                    """
            )
            if input.usesCustomActivityTargets {
                Label(
                    "These are your personal targets.",
                    systemImage:
                        "slider.horizontal.3"
                )

                LabeledContent(
                    "General adult reference",
                    value: "150 min · 2 days"
                )
            }

            Text(
                """
                Steps and Stand Hours provide movement \
                context. Active energy and distance are \
                informational and do not increase the \
                Activity Health status.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func baselineRow(
        _ title: String,
        comparison:
            PersonalMetricComparison?,
        unit: String
    ) -> some View {
        if let comparison {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                HStack {
                    Text(title)

                    Spacer()

                    Text(
                        changeText(
                            comparison
                                .percentChange
                        )
                    )
                    .fontWeight(.semibold)
                }

                Text(
                    """
                    \(formatted(
                        comparison.currentValue
                    )) vs usual \(formatted(
                        comparison.usualValue
                    )) \(unit)
                    """
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        } else {
            LabeledContent(
                title,
                value:
                    "Not enough history"
            )
        }
    }

    private func formatted(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0...1)
            )
        )
    }
    
    private func shortDate(
        _ date: Date
    ) -> String {
        date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
        )
    }

    private func recencyText(
        _ days: Int
    ) -> String {
        switch days {
        case 0:
            return "Today"

        case 1:
            return "Yesterday"

        default:
            return "\(days) days ago"
        }
    }
    
    private func changeText(
        _ percentage: Double?
    ) -> String {
        guard let percentage else {
            return "No usual value"
        }

        if abs(percentage) < 0.5 {
            return "About usual"
        }

        let arrow =
            percentage > 0 ? "↑" : "↓"

        let amount =
            abs(percentage).formatted(
                .number.precision(
                    .fractionLength(0)
                )
            )

        return "\(arrow) \(amount)%"
    }
}
