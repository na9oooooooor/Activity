import SwiftUI

struct TodayDashboardView: View {
    let input: DashboardInput
    let assessment: ActivityAssessment
    let todayContext:
        TodayContextSelection

    let recommendationReason: String

    let onContextChange:
        (TodayContextSelection) -> Void

    let onShowExplanation: () -> Void
    let onRefresh: () async -> Void

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing:
                    ActivityTheme
                        .sectionSpacing
            ) {
                hero
                targetCard
                todayCard
                comparisonCard
                updateFooter
            }
            .padding(
                .horizontal,
                ActivityTheme.pagePadding
            )
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(
            ActivityTheme.background
                .ignoresSafeArea()
        )
        .refreshable {
            await onRefresh()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                ActivitySectionLabel(
                    title:
                        input
                            .usesCustomActivityTargets
                        ? "Your activity targets"
                        : "Activity health"
                )

                Spacer()

                Button(
                    action:
                        onShowExplanation
                ) {
                    Image(
                        systemName:
                            "info.circle"
                    )
                    .font(.body)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "How Activity Health is calculated"
                )
            }

            Text(statusTitle)
                .font(
                    ActivityTheme.heroFont
                )
                .fontWidth(.condensed)
                .tracking(-0.8)

            Text(healthSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            if input.usesCustomActivityTargets {
                Label(
                    "Personal targets active",
                    systemImage:
                        "slider.horizontal.3"
                )
                .font(.caption)
                .foregroundStyle(
                    ActivityTheme.accent
                )
            }
        }
    }

    // MARK: - Targets

    private var targetCard: some View {
        HStack(
            alignment: .top,
            spacing: 18
        ) {
            targetMetric(
                title: "Aerobic",
                value:
                    input.snapshot
                        .moderateEquivalentMinutes,
                target:
                    input.targets
                        .aerobicMinimumMinutes,
                unit: "min"
            )

            Rectangle()
                .fill(
                    ActivityTheme.divider
                )
                .frame(width: 0.75)
                .frame(maxHeight: .infinity)

            targetMetric(
                title: "Strength",
                value:
                    Double(
                        input.snapshot
                            .strengthDays
                    ),
                target:
                    Double(
                        input.targets
                            .strengthMinimumDays
                    ),
                unit: "days"
            )
        }
        .activityCard()
    }

    private func targetMetric(
        title: String,
        value: Double,
        target: Double,
        unit: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 9
        ) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(
                alignment: .firstTextBaseline,
                spacing: 4
            ) {
                Text(
                    formatted(
                        value,
                        digits: 0
                    )
                )
                .font(
                    ActivityTheme
                        .largeMetricFont
                )
                .fontWidth(.condensed)

                Text(
                    """
                    / \(formatted(
                        target,
                        digits: 0
                    )) \(unit)
                    """
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            ActivityProgressTrack(
                value: value,
                target: target,
                tint:
                    value >= target
                    ? ActivityTheme.success
                    : ActivityTheme.accent
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    // MARK: - Today

    private var todayCard: some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            HStack(
                alignment: .firstTextBaseline
            ) {
                ActivitySectionLabel(
                    title: "Today"
                )

                Spacer()

                HStack(spacing: 7) {
                    Circle()
                        .fill(
                            recommendationTint
                        )
                        .frame(
                            width: 8,
                            height: 8
                        )

                    Text(
                        assessment
                            .recommendation
                            .outcome?
                            .rawValue
                        ?? "Unavailable"
                    )
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        recommendationTint
                    )
                }
            }

            Text(
                assessment
                    .recommendation
                    .outcome?
                    .rawValue
                ?? "Recommendation unavailable"
            )
            .font(.title2)
            .fontWeight(.semibold)

            Text(recommendationReason)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            Picker(
                "Today’s context",
                selection: Binding(
                    get: {
                        todayContext
                    },
                    set: {
                        onContextChange($0)
                    }
                )
            ) {
                ForEach(
                    TodayContextSelection
                        .allCases
                ) { selection in
                    Text(selection.title)
                        .tag(selection)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(
                "Today’s context"
            )
        }
        .activityCard()
    }

    // MARK: - Comparison

    private var comparisonCard:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                ActivitySectionLabel(
                    title:
                        "Compared with you"
                )

                Text(
                    """
                    Last 7 completed days versus usual
                    """
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            comparisonRow(
                title: "Aerobic",
                comparison:
                    input.comparison.aerobic,
                unit: "min/week",
                digits: 0
            )

            ActivityDivider()

            comparisonRow(
                title: "Steps",
                comparison:
                    input.comparison.steps,
                unit: "steps/day",
                digits: 0
            )

            ActivityDivider()

            comparisonRow(
                title: "Stand Hours",
                comparison:
                    input.comparison
                        .standHours,
                unit: "hours/day",
                digits: 1
            )

            if let todaySteps =
                input.snapshot
                    .recordedStepsToday {

                ActivityDivider()

                LabeledContent(
                    "Today’s movement",
                    value:
                        "\(todaySteps.formatted()) steps"
                )
            }
        }
        .activityCard()
    }

    @ViewBuilder
    private func comparisonRow(
        title: String,
        comparison:
            PersonalMetricComparison?,
        unit: String,
        digits: Int
    ) -> some View {
        if let comparison {
            HStack(
                alignment: .firstTextBaseline
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(title)
                        .font(.body)

                    Text(
                        """
                        \(formatted(
                            comparison.currentValue,
                            digits: digits
                        )) vs \(formatted(
                            comparison.usualValue,
                            digits: digits
                        )) \(unit)
                        """
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(
                    changeText(
                        comparison
                            .percentChange
                    )
                )
                .font(.headline)
            }
        } else {
            LabeledContent(
                title,
                value: "Not enough history"
            )
            .foregroundStyle(.secondary)
        }
    }

    private var updateFooter: some View {
        Text(
            """
            Updated \(input.windowEnd.formatted(
                date: .omitted,
                time: .shortened
            ))
            """
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    // MARK: - Display values

    private var statusTitle: String {
        switch assessment.status {
        case .meetingTargets:
            return "On track"

        case .belowTargets:
            return "Room to build"

        case .needsReview:
            return "Needs review"

        case .updating:
            return "Updating"

        case .unavailable:
            return "No activity data"
        }
    }

    private var healthSummary: String {
        if assessment.aerobicTargetMet
            && assessment.strengthTargetMet {

            return """
            Your aerobic and strength targets are reached \
            in the current seven-day window.
            """
        }

        if assessment.aerobicTargetMet {
            return """
            Aerobic target reached. Strength remains below \
            your current target.
            """
        }

        if assessment.strengthTargetMet {
            return """
            Strength target reached. Aerobic activity \
            remains below your current target.
            """
        }

        return """
        Aerobic activity and strength frequency remain \
        below your current targets.
        """
    }

    private var recommendationTint: Color {
        switch assessment
            .recommendation
            .outcome {

        case .workoutRecommended:
            return ActivityTheme.caution

        case .activityRecommended:
            return ActivityTheme.accent

        case .workoutOptional:
            return ActivityTheme.success

        case .recovery:
            return ActivityTheme.accent

        case nil:
            return .secondary
        }
    }

    private func formatted(
        _ value: Double,
        digits: Int
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(digits)
            )
        )
    }

    private func changeText(
        _ percentage: Double?
    ) -> String {
        guard let percentage else {
            return "—"
        }

        if abs(percentage) < 0.5 {
            return "Usual"
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
