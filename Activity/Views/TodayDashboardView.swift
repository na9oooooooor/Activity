import SwiftUI

private enum TodayDashboardSheet:
    String,
    Identifiable {

    case today
    case comparison

    var id: String {
        rawValue
    }
}

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

    @State private var presentedSheet:
        TodayDashboardSheet?

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 0
            ) {
                hero

                ActivityDivider()

                todayRow
                    .padding(.vertical, 22)

                ActivityDivider()

                targetSection
                    .padding(.vertical, 24)

                ActivityDivider()

                comparisonRow
                    .padding(.vertical, 22)

                ActivityDivider()

                updateFooter
                    .padding(.top, 18)
            }
            .padding(
                .horizontal,
                ActivityTheme.pagePadding
            )
            .padding(.top, 22)
            .padding(.bottom, 36)
        }
        .background(
            ActivityTheme.background
                .ignoresSafeArea()
        )
        .refreshable {
            await onRefresh()
        }
        .sheet(
            item: $presentedSheet
        ) { sheet in
            switch sheet {
            case .today:
                TodayDecisionSheet(
                    assessment: assessment,
                    recommendationReason:
                        recommendationReason,
                    todayContext:
                        todayContext,
                    onContextChange:
                        onContextChange
                )

            case .comparison:
                PersonalComparisonSheet(
                    input: input
                )
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            HStack(spacing: 8) {
                ActivitySectionLabel(
                    title: "Activity health"
                )

                Button(
                    action: onShowExplanation
                ) {
                    Image(
                        systemName: "info.circle"
                    )
                    .font(.body)
                    .foregroundStyle(
                        ActivityTheme.accent
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "How Activity Health is calculated"
                )
            }

            SevenDayActivityStrip(
                days: input.activityStripDays,
                aerobicTargetMinutes:
                    input.targets
                        .aerobicMinimumMinutes,
                status: assessment.status,
                recordState:
                    input.snapshot.recordState,
                onTap: onShowExplanation
            )
            .padding(.top, 2)
            .padding(.bottom, 8)
            
            
            Text(statusTitle)
                .font(
                    ActivityTheme.heroFont
                )
                .fontWidth(.condensed)
                .tracking(-0.8)

            Text(healthSummary)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .padding(.bottom, 28)
    }

    // MARK: - Today

    private var todayRow: some View {
        Button {
            presentedSheet = .today
        } label: {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                ActivitySectionLabel(
                    title: "Today"
                )

                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            recommendationTint
                        )
                        .frame(
                            width: 9,
                            height: 9
                        )

                    Text(recommendationTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(
                        systemName: "chevron.right"
                    )
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(
            "Opens the recommendation explanation and today context"
        )
    }

    // MARK: - Targets

    private var targetSection: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            HStack {
                ActivitySectionLabel(
                    title:
                        input
                            .usesCustomActivityTargets
                        ? "Your 7-day targets"
                        : "7-day targets"
                )

                Spacer()

                Text(activityWindowLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(
                alignment: .top,
                spacing: 22
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
                    .frame(
                        width: 0.75,
                        height: 98
                    )

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
        }
    }

    private func targetMetric(
        title: String,
        value: Double,
        target: Double,
        unit: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            HStack(
                alignment: .firstTextBaseline,
                spacing: 5
            ) {
                Text(
                    formatted(
                        value,
                        digits: 0
                    )
                )
                .font(
                    ActivityTheme.largeMetricFont
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

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .accessibilityElement(
            children: .combine
        )
        .accessibilityLabel(
            """
            \(title), \(formatted(
                value,
                digits: 0
            )) of \(formatted(
                target,
                digits: 0
            )) \(unit), rolling seven-day target
            """
        )
    }

    // MARK: - Personal comparison

    private var comparisonRow: some View {
        Button {
            presentedSheet = .comparison
        } label: {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                ActivitySectionLabel(
                    title: "Compared with you"
                )

                HStack {
                    Text(comparisonSummary)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(
                        systemName: "chevron.right"
                    )
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(
            "Opens your personal baseline details"
        )
    }

    // MARK: - Footer

    private var updateFooter: some View {
        HStack {
            Text(
                """
                Updated \(input.windowEnd.formatted(
                    date: .omitted,
                    time: .shortened
                ))
                """
            )

            Spacer()

            if input.usesCustomActivityTargets {
                Label(
                    "Personal targets",
                    systemImage:
                        "slider.horizontal.3"
                )
                .foregroundStyle(
                    ActivityTheme.accent
                )
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Display values

    private var recommendationTitle: String {
        assessment
            .recommendation
            .outcome?
            .rawValue
        ?? "Recommendation unavailable"
    }

    private var statusTitle: String {
        switch assessment.status {
        case .meetingTargets:
            return "On track"

        case .belowTargets:
            return "Room to build"

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
            Your aerobic and strength targets are reached.
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

    private var comparisonSummary: String {
        guard let aerobic =
            input.comparison.aerobic
        else {
            return "Building your baseline"
        }

        return """
        \(changeText(
            aerobic.percentChange
        )) aerobic activity
        """
    }

    private var activityWindowLabel: String {
        let calendar = Calendar.current

        let startComponents =
            calendar.dateComponents(
                [.year, .month],
                from: input.windowStart
            )

        let endComponents =
            calendar.dateComponents(
                [.year, .month],
                from: input.windowEnd
            )

        let start =
            input.windowStart.formatted(
                .dateTime
                    .month(.abbreviated)
                    .day()
            )

        if startComponents == endComponents {
            let endDay =
                input.windowEnd.formatted(
                    .dateTime.day()
                )

            return "\(start)–\(endDay)"
        }

        let end =
            input.windowEnd.formatted(
                .dateTime
                    .month(.abbreviated)
                    .day()
            )

        return "\(start)–\(end)"
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
            return "Usual"
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

// MARK: - Today details

private struct TodayDecisionSheet: View {
    let assessment: ActivityAssessment
    let recommendationReason: String

    let todayContext:
        TodayContextSelection

    let onContextChange:
        (TodayContextSelection) -> Void

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 22
                ) {
                    ActivitySectionLabel(
                        title: "Today"
                    )

                    Text(recommendationTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .fontWidth(.condensed)

                    Text(recommendationReason)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                    ActivityDivider()

                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {
                        Text("How today feels")
                            .font(.headline)

                        Text(
                            """
                            Choose a different context when \
                            you need recovery or have moved \
                            very little today.
                            """
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

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
                    }

                    Text(
                        """
                        This changes today’s recommendation. \
                        It does not change your imported \
                        workouts or activity targets.
                        """
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(
                    ActivityTheme.pagePadding
                )
            }
            .background(
                ActivityTheme.background
                    .ignoresSafeArea()
            )
            .navigationTitle(
                "Today"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents(
            [.medium, .large]
        )
    }

    private var recommendationTitle: String {
        assessment
            .recommendation
            .outcome?
            .rawValue
        ?? "Recommendation unavailable"
    }
}

// MARK: - Comparison details

private struct PersonalComparisonSheet: View {
    let input: DashboardInput

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 22
                ) {
                    ActivitySectionLabel(
                        title: "Compared with you"
                    )

                    Text("Your recent pattern")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .fontWidth(.condensed)

                    Text(
                        """
                        Your last 7 completed days are \
                        compared with the previous 90 \
                        completed days. Today is excluded.
                        """
                    )
                    .foregroundStyle(.secondary)

                    ActivityDivider()

                    comparisonMetric(
                        title: "Aerobic",
                        comparison:
                            input.comparison.aerobic,
                        unit: "min/week",
                        digits: 0
                    )

                    ActivityDivider()

                    comparisonMetric(
                        title: "Steps",
                        comparison:
                            input.comparison.steps,
                        unit: "steps/day",
                        digits: 0
                    )

                    ActivityDivider()

                    comparisonMetric(
                        title: "Stand hours",
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

                        HStack {
                            Text("Today’s movement")

                            Spacer()

                            Text(
                                "\(todaySteps.formatted()) steps"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(
                    ActivityTheme.pagePadding
                )
            }
            .background(
                ActivityTheme.background
                    .ignoresSafeArea()
            )
            .navigationTitle(
                "Your baseline"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents(
            [.medium, .large]
        )
    }

    @ViewBuilder
    private func comparisonMetric(
        title: String,
        comparison:
            PersonalMetricComparison?,
        unit: String,
        digits: Int
    ) -> some View {
        if let comparison {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                HStack {
                    Text(title)
                        .font(.headline)

                    Spacer()

                    Text(
                        changeText(
                            comparison.percentChange
                        )
                    )
                    .font(.headline)
                }

                Text(
                    """
                    \(formatted(
                        comparison.currentValue,
                        digits: digits
                    )) vs usual \(formatted(
                        comparison.usualValue,
                        digits: digits
                    )) \(unit)
                    """
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } else {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Text("Not enough history")
                    .foregroundStyle(.secondary)
            }
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
            return "Usual"
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
