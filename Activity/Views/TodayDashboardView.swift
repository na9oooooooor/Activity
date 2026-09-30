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
    let onShowExplanation: () -> Void
    let onShowSettings: () -> Void
    let onRefresh: () async -> Void
    let onContextChange:
        (TodayContextSelection) -> Void
    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize:
        DynamicTypeSize
    
    @State private var presentedSheet:
        TodayDashboardSheet?
    
    private var pebbleAssetName:
        String? {

        switch assessment
            .recommendation
            .reason {

        case .strengthGap:
            return "pebble_strength"

        case .aerobicGap,
             .recentStrengthSession:
            return "pebble_aerobic"

        case .smallRemainingGap,
             .lowMovement:
            return "pebble_movement"

        case .targetsMet,
             .aerobicSessionAlreadyCompleted:
            return "pebble_enough"

        case .recoveryChoice:
            return "pebble_recovery"

        case .unavailableRecords,
             .outsideGuidedScope:
            return "pebble_no_data"

        case .staleRecords,
             .importing:
            return "pebble_updating"
        }
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 20
            ) {
                pageHeader

                recommendationCard

                activityHealthHeader

                activitySummaryCard

                targetSection
                    .activityCard()

                comparisonRow
                    .activityCard()

                updateFooter
                    .padding(
                        .horizontal,
                        2
                    )
            }
            .padding(
                .horizontal,
                ActivityTheme.pagePadding
            )
            .padding(.top, 4)
            .padding(.bottom, 24)
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
    // MARK: - Page header

    private var pageHeader: some View {
        HStack(
            alignment: .center,
            spacing: 16
        ) {
            VStack(
                alignment: .leading,
                spacing: 1
            ) {
                Text(
                    input.windowEnd.formatted(
                        .dateTime
                            .weekday(.wide)
                            .day()
                            .month(.wide)
                    )
                )
                .font(
                    .subheadline.weight(
                        .semibold
                    )
                )
                .foregroundStyle(.secondary)

                Text("Today")
                    .font(
                        .system(
                            size: 40,
                            weight: .bold
                        )
                    )
                    .fontWidth(.condensed)
                    .tracking(-0.5)
            }
            .accessibilityElement(
                children: .combine
            )

            Spacer(minLength: 12)

            Button(
                action: onShowSettings
            ) {
                Image(
                    systemName:
                        "gearshape"
                )
                .font(.subheadline.bold())
                .foregroundStyle(
                    ActivityTheme.accent
                )
                .frame(
                    width: 44,
                    height: 44
                )
                .background(
                    ActivityTheme.surface,
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(
                            ActivityTheme.divider,
                            lineWidth: 0.75
                        )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
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

            Text(activityProgressSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .padding(.bottom, 28)
    }
    
    // MARK: - Recommendation hero

    private var recommendationCard: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            Button {
                presentedSheet = .today
            } label: {
                HStack(spacing: 12) {
                    recommendationSymbol

                    Text(recommendationTitle)
                        .font(.headline)
                        .foregroundStyle(
                            recommendationTint
                        )

                    Spacer()

                    Image(
                        systemName:
                            "chevron.right"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            recommendationContent

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
                    TodayContextSelection.allCases
                ) { selection in
                    Text(selection.title)
                        .tag(selection)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint(
                """
                Changes today’s suggestion without changing \
                your targets or workout history.
                """
            )
        }
        .padding(18)
        .background(
            recommendationTint.opacity(0.10),
            in: RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                recommendationTint.opacity(0.32),
                lineWidth: 0.75
            )
        }
    }

    private var recommendationSymbol:
        some View {

        ZStack {
            Circle()
                .fill(recommendationTint)
                .frame(
                    width: 32,
                    height: 32
                )

            Circle()
                .fill(
                    ActivityTheme.background
                )
                .frame(
                    width: 10,
                    height: 10
                )
        }
        .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private var recommendationContent:
        some View {

        if dynamicTypeSize
            .isAccessibilitySize {

            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                recommendationCopy

                if let assetName =
                    pebbleAssetName {

                    pebbleImage(assetName)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .trailing
                        )
                }
            }
        } else {
            HStack(
                alignment: .bottom,
                spacing: 12
            ) {
                recommendationCopy
                    .layoutPriority(1)

                Spacer(minLength: 0)

                if let assetName =
                    pebbleAssetName {

                    pebbleImage(assetName)
                }
            }
        }
    }

    private var recommendationCopy: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(recommendationAction)
                .font(
                    .system(
                        size: 26,
                        weight: .bold
                    )
                )
                .tracking(-0.3)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            Text(recommendationReason)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
    }

    private func pebbleImage(
        _ assetName: String
    ) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(
                width: 92,
                height: 104
            )
            .accessibilityHidden(true)
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
    
    private var recommendationAction: String {
        switch assessment
            .recommendation
            .reason {

        case .targetsMet:
            return """
            You’ve done enough for your current targets.
            """

        case .aerobicGap:
            return """
            A 20–30 min brisk walk or aerobic session.
            """

        case .strengthGap:
            return "20–30 min strength session"

        case .smallRemainingGap:
            return """
            A short, comfortable activity session can \
            close the gap.
            """

        case .recentStrengthSession:
            return """
            Choose aerobic activity if you want to do \
            more today.
            """

        case .aerobicSessionAlreadyCompleted:
            return """
            You’ve already completed aerobic activity today.
            """

        case .lowMovement:
            return """
            A short walk or light movement would help today.
            """

        case .recoveryChoice:
            return """
            Recovery today. Light movement is enough.
            """

        case .unavailableRecords:
            return """
            Connect Apple Health to get today’s suggestion.
            """

        case .staleRecords:
            return """
            Refresh your activity before using today’s \
            suggestion.
            """

        case .importing:
            return """
            Your activity is being updated.
            """

        case .outsideGuidedScope:
            return """
            Today’s suggestion is unavailable for this profile.
            """
        }
    }

    // MARK: - Targets

    private var targetSection: some View {
        VStack(
            alignment: .leading,
            spacing: 16
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
                        height: 82
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
    
    private var activitySummaryCard: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
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

            chartLegend
        }
        .activityCard()
    }

    private var chartLegend: some View {
        HStack(spacing: 18) {
            Label {
                Text("Target pace")
            } icon: {
                Capsule()
                    .fill(
                        ActivityTheme.accent.opacity(0.22)
                    )
                    .frame(
                        width: 22,
                        height: 7
                    )
            }

            Label {
                Text("Strength day")
            } icon: {
                Circle()
                    .fill(.primary.opacity(0.75))
                    .frame(
                        width: 8,
                        height: 8
                    )
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(
            children: .combine
        )
    }
    
    // MARK: - Activity Health

    private var activityHealthHeader:
        some View {

        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            HStack(
                alignment: .firstTextBaseline
            ) {
                HStack(spacing: 8) {
                    Text(statusTitle)
                        .font(
                            .system(
                                size: 32,
                                weight: .bold
                            )
                        )
                        .fontWidth(.condensed)
                        .tracking(-0.4)

                    Button(
                        action:
                            onShowExplanation
                    ) {
                        Image(
                            systemName:
                                "info.circle"
                        )
                        .font(.body)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "How Activity Health works"
                    )
                }

                Spacer()

                Text("Last 7 days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(healthSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
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

                HStack(
                    alignment: .center,
                    spacing: 12
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text(comparisonSummary)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                        if let detail = comparisonDetail {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 12)

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
        HStack(spacing: 12) {
            Label {
                Text(
                    """
                    Updated \(input.windowEnd.formatted(
                        date: .omitted,
                        time: .shortened
                    ))
                    """
                )
            } icon: {
                Image(systemName: "arrow.clockwise")
            }

            Spacer()

            if input.usesCustomActivityTargets {
                Label(
                    "Personal targets",
                    systemImage: "slider.horizontal.3"
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
    
    private var activityProgressSummary: String {
        switch assessment.status {
        case .meetingTargets, .belowTargets:
            let aerobicMinutes = Int(
                input.snapshot
                    .moderateEquivalentMinutes
                    .rounded()
            )

            let aerobicTarget = Int(
                input.targets
                    .aerobicMinimumMinutes
                    .rounded()
            )

            let strengthDays =
                input.snapshot.strengthDays

            let strengthTarget =
                input.targets.strengthMinimumDays

            return """
            \(aerobicMinutes) of \(aerobicTarget) aerobic min • \
            \(strengthDays) of \(strengthTarget) strength days
            """

        case .updating, .unavailable:
            return healthSummary
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

        guard let percentChange =
            aerobic.percentChange
        else {
            return "Around your usual aerobic activity"
        }

        let amount = abs(percentChange)
            .formatted(
                .number.precision(
                    .fractionLength(0)
                )
            )

        if abs(percentChange) < 0.5 {
            return "Around your usual aerobic activity"
        }

        if percentChange > 0 {
            return """
            Aerobic activity is \(amount)% above your usual
            """
        }

        return """
        Aerobic activity is \(amount)% below your usual
        """
    }

    private var comparisonDetail: String? {
        guard let aerobic =
            input.comparison.aerobic
        else {
            return nil
        }

        let current = formatted(
            aerobic.currentValue,
            digits: 0
        )

        let usual = formatted(
            aerobic.usualValue,
            digits: 0
        )

        return "\(current) vs usual \(usual) min/week"
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

