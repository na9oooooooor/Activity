import SwiftUI
import SwiftData
import Charts
import HealthKit

enum TrendPeriod:
    String,
    CaseIterable,
    Identifiable {

    case sevenDays = "7D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"

    var id: String {
        rawValue
    }
    
    var strengthGridColumnCount: Int {
        switch self {
        case .sevenDays:
            return 7

        case .thirtyDays:
            return 10

        case .ninetyDays:
            return 13
        }
    }
    
    var completeWeekCount: Int {
        switch self {
        case .sevenDays:
            return 1

        case .thirtyDays:
            return 4

        case .ninetyDays:
            return 12
        }
    }
    
    var dayCount: Int {
        switch self {
        case .sevenDays:
            return 7

        case .thirtyDays:
            return 30

        case .ninetyDays:
            return 90
        }
    }

    var title: String {
        switch self {
        case .sevenDays:
            return "Last 7 days"

        case .thirtyDays:
            return "Last 30 days"

        case .ninetyDays:
            return "Last 90 days"
        }
    }

    var axisStride: Int {
        switch self {
        case .sevenDays:
            return 1

        case .thirtyDays:
            return 5

        case .ninetyDays:
            return 14
        }
    }
}

private struct TrendWeekCoverage:
    Identifiable {

    let id: Date
    let metTargets: Bool
}

struct TrendsView: View {
    @Bindable var purchases:
        PurchaseManager

    let healthKit: HealthKitService
    let onWorkoutsChanged: () -> Void
    let onShowSettings: () -> Void

    @Query(
        sort: \StoredWorkout.startDate,
        order: .reverse
    )
    private var allWorkouts:
        [StoredWorkout]
    @Query(
        sort:
            \DailyActivityRecord.dayStart,
        order: .reverse
    )
    private var allRecords:
        [DailyActivityRecord]

    @Query
    private var savedSettings:
        [AppSettings]

    @State private var period:
        TrendPeriod = .sevenDays

    @State private var showingPaywall = false

    @State private var pendingPeriod:
        TrendPeriod?
    
    private var recentWorkouts:
        [StoredWorkout] {

        Array(allWorkouts.prefix(3))
    }
    
    private var periodSelection:
        Binding<TrendPeriod> {

        Binding(
            get: {
                period
            },
            set: { selectedPeriod in
                if selectedPeriod == .sevenDays
                    || purchases.hasPlusAccess {

                    period = selectedPeriod
                } else {
                    pendingPeriod =
                        selectedPeriod

                    showingPaywall = true
                }
            }
        )
    }
    
    private var settings: AppSettings? {
        savedSettings.first
    }

    private var targets: ActivityTargets {
        settings?.activityTargets
            ?? .generalAdultGuidance
    }

    private var records:
        [DailyActivityRecord] {

        Array(
            allRecords
                .prefix(period.dayCount)
                .reversed()
        )
    }
    
    private var weekCoverage:
        [TrendWeekCoverage] {

        let requiredDayCount =
            period.completeWeekCount * 7

        let coveredRecords =
            Array(
                records.suffix(
                    requiredDayCount
                )
            )

        return stride(
            from: 0,
            to: coveredRecords.count,
            by: 7
        )
        .compactMap { startIndex in
            let endIndex = min(
                startIndex + 7,
                coveredRecords.count
            )

            let weekRecords =
                Array(
                    coveredRecords[
                        startIndex..<endIndex
                    ]
                )

            guard weekRecords.count == 7,
                  let firstDay =
                    weekRecords.first?.dayStart
            else {
                return nil
            }

            let aerobicMinutes =
                weekRecords.reduce(0) {
                    result,
                    record in

                    result
                        + record
                            .guidelineModerateEquivalentMinutes
                }

            let strengthDays =
                weekRecords.filter(
                    \.isStrengthDay
                ).count

            let metTargets =
                aerobicMinutes
                    >= targets
                        .aerobicMinimumMinutes
                && strengthDays
                    >= targets
                        .strengthMinimumDays

            return TrendWeekCoverage(
                id: firstDay,
                metTargets: metTargets
            )
        }
    }

    private var coveredWeekCount: Int {
        weekCoverage.filter(
            \.metTargets
        ).count
    }
    
    private var displayedDateRange: String {
        guard let startDate =
                records.first?.dayStart,
              let endDate =
                records.last?.dayStart
        else {
            return period.title
        }

        let start =
            startDate.formatted(
                .dateTime
                    .day()
                    .month(.abbreviated)
            )

        let end =
            endDate.formatted(
                .dateTime
                    .day()
                    .month(.abbreviated)
            )

        return "\(start) – \(end)"
    }

    private var aerobicWeeklyPace: Double {
        guard !records.isEmpty else {
            return 0
        }

        let total =
            records.reduce(0) {
                result,
                record in

                result
                    + record
                        .guidelineModerateEquivalentMinutes
            }

        return total
            / Double(records.count)
            * 7
    }

    private var strengthWeeklyPace: Double {
        guard !records.isEmpty else {
            return 0
        }

        let strengthDays =
            records.filter(\.isStrengthDay).count

        return Double(strengthDays)
            / Double(records.count)
            * 7
    }
    
    private var strengthDayCount: Int {
        records.filter(
            \.isStrengthDay
        ).count
    }
    
    private var recentWorkoutsSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            HStack {
                ActivitySectionLabel(
                    title: "Recent workouts"
                )

                Spacer()

                NavigationLink {
                    RecentWorkoutsView(
                        healthKit: healthKit,
                        onWorkoutsChanged:
                            onWorkoutsChanged
                    )
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if recentWorkouts.isEmpty {
                Text(
                    """
                    Workouts imported from Apple Health and workouts you add will appear here.
                    """
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(20)
                .background(
                    ActivityTheme.surface,
                    in: RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .stroke(
                        ActivityTheme.divider,
                        lineWidth: 0.75
                    )
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(
                        recentWorkouts,
                        id: \.healthKitUUID
                    ) { workout in
                        NavigationLink {
                            WorkoutDetailView(
                                workout: workout,
                                healthKit: healthKit,
                                onDeleted:
                                    onWorkoutsChanged
                            )
                        } label: {
                            compactWorkoutRow(
                                workout
                            )
                        }
                        .buttonStyle(.plain)

                        if workout.healthKitUUID
                            != recentWorkouts.last?
                                .healthKitUUID {

                            ActivityDivider()
                                .padding(
                                    .leading,
                                    64
                                )
                        }
                    }
                }
                .padding(
                    .horizontal,
                    18
                )
                .background(
                    ActivityTheme.surface,
                    in: RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .stroke(
                        ActivityTheme.divider,
                        lineWidth: 0.75
                    )
                }
            }
        }
    }

    private var dailyAerobicPace: Double {
        targets.aerobicMinimumMinutes / 7
    }
    
    private var aerobicBarWidth: CGFloat {
        switch period {
        case .sevenDays:
            return 22

        case .thirtyDays:
            return 8

        case .ninetyDays:
            return 3
        }
    }

    private var averageSteps: Double? {
        average(
            records.compactMap {
                $0.recordedSteps.map(Double.init)
            }
        )
    }

    private var averageStandHours: Double? {
        average(
            records.compactMap {
                $0.standHours.map(Double.init)
            }
        )
    }

    private var averageActiveEnergy: Double? {
        average(
            records.compactMap(
                \.activeEnergyKilocalories
            )
        )
    }
    
    private var coverageCard: some View {
        HStack(
            alignment: .bottom,
            spacing: 16
        ) {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                Text(
                    "Covered \(coveredWeekCount) of \(weekCoverage.count) \(weekCoverage.count == 1 ? "week" : "weeks")"
                )
                .font(
                    .system(
                        size: 30,
                        weight: .bold
                    )
                )
                .fontWidth(.condensed)
                .tracking(-0.3)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

                HStack(spacing: 7) {
                    ForEach(weekCoverage) {
                        week in

                        Capsule()
                            .fill(
                                week.metTargets
                                    ? ActivityTheme.success
                                    : ActivityTheme.surface
                            )
                            .overlay {
                                Capsule()
                                    .stroke(
                                        week.metTargets
                                            ? ActivityTheme.success
                                            : ActivityTheme.divider,
                                        lineWidth: 1
                                    )
                            }
                            .frame(
                                maxWidth: 48
                            )
                            .frame(height: 12)
                    }
                }
                .accessibilityHidden(true)

                Text(
                    """
                    A week counts when both aerobic and strength targets were met. Missing a week is fine; the next one starts fresh.
                    """
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }

            Spacer(minLength: 0)

            Image("pebble_recovery")
                .resizable()
                .scaledToFit()
                .frame(
                    width: 112,
                    height: 112
                )
                .accessibilityHidden(true)
        }
        .padding(22)
        .background(
            ActivityTheme.success.opacity(
                0.09
            ),
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
                ActivityTheme.success.opacity(
                    0.28
                ),
                lineWidth: 0.75
            )
        }
        .accessibilityElement(
            children: .combine
        )
        .accessibilityLabel(
            """
            Covered \(coveredWeekCount) of \(weekCoverage.count) weeks. A week counts when both aerobic and strength targets were met.
            """
        )
    }

    private var averageDistanceKilometers:
        Double? {

        let values =
            records.compactMap { record
                -> Double? in

                let walking =
                    record
                        .walkingRunningDistanceMeters

                let cycling =
                    record
                        .cyclingDistanceMeters

                guard walking != nil
                    || cycling != nil
                else {
                    return nil
                }

                return (
                    (walking ?? 0)
                    + (cycling ?? 0)
                ) / 1_000
            }

        return average(values)
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 0
            ) {
                header

                periodPicker
                    .padding(.top, 18)
                    .padding(.bottom, 26)

                if records.isEmpty {
                    emptyState
                } else {
                    coverageCard
                        .padding(.bottom, 26)

                    primaryMetrics
                        .padding(.bottom, 26)

                    aerobicSection
                        .activityCard()
                        .padding(.bottom, 24)

                    strengthSection
                        .activityCard()
                        .padding(.bottom, 24)

                    stepsSection
                        .activityCard()
                        .padding(.bottom, 26)

                    movementSummary
                        .padding(.bottom, 28)

                    recentWorkoutsSection
                }
                
            }
            .padding(
                .horizontal,
                ActivityTheme.pagePadding
            )
            .padding(.top, 22)
            .padding(.bottom, 40)
        }
        .background(
            ActivityTheme.background
                .ignoresSafeArea()
        )
        .onChange(
            of: purchases.hasPlusAccess
        ) { _, hasPlusAccess in
            guard !hasPlusAccess else {
                return
            }

            period = .sevenDays
            pendingPeriod = nil
        }
        .sheet(
            isPresented: $showingPaywall,
            onDismiss: {
                applyPendingPeriod()
            }
        ) {
            EnoughPlusView(
                purchases: purchases
            )
            .presentationDetents([
                .large
            ])
            .presentationDragIndicator(
                .visible
            )
        }

    }
    

    private var header: some View {
        HStack(
            alignment: .center,
            spacing: 16
        ) {
            VStack(
                alignment: .leading,
                spacing: 1
            ) {
                Text(displayedDateRange)
                    .font(
                        .subheadline.weight(
                            .semibold
                        )
                    )
                    .foregroundStyle(.secondary)

                Text("Trends")
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
                    systemName: "gearshape"
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

    private var periodPicker: some View {
        Picker(
            "Period",
            selection: periodSelection
        ) {
            ForEach(
                TrendPeriod.allCases
            ) { option in
                HStack(spacing: 4) {
                    Text(option.rawValue)

                    if option != .sevenDays
                        && !purchases
                            .hasPlusAccess {

                        Image(
                            systemName:
                                "lock.fill"
                        )
                        .font(.caption2)
                    }
                }
                .tag(option)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(
            "Trend period"
        )
    }

    private var primaryMetrics: some View {
        let aerobicTarget =
            formatted(
                targets
                    .aerobicMinimumMinutes,
                digits: 0
            )

        let strengthTarget =
            String(
                targets
                    .strengthMinimumDays
            )

        return HStack(
            alignment: .top,
            spacing: 22
        ) {
            primaryMetric(
                title: "Aerobic per week",
                value:
                    formatted(
                        aerobicWeeklyPace,
                        digits: 0
                    ),
                unit: "min",
                target:
                    aerobicTarget + " min",
                targetMet:
                    aerobicWeeklyPace
                    >= targets
                        .aerobicMinimumMinutes
            )

            Rectangle()
                .fill(
                    ActivityTheme.divider
                )
                .frame(
                    width: 0.75,
                    height: 112
                )

            primaryMetric(
                title: "Strength per week",
                value:
                    formatted(
                        strengthWeeklyPace,
                        digits: 1
                    ),
                unit: "days",
                target:
                    strengthTarget + " days",
                targetMet:
                    strengthWeeklyPace
                    >= Double(
                        targets
                            .strengthMinimumDays
                    )
            )
        }
    }

    private func primaryMetric(
        title: String,
        value: String,
        unit: String,
        target: String,
        targetMet: Bool
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
                spacing: 5
            ) {
                Text(value)
                    .font(
                        ActivityTheme
                            .largeMetricFont
                    )
                    .fontWidth(.condensed)

                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(
                        targetMet
                            ? ActivityTheme.success
                            : ActivityTheme.accent
                    )
                    .frame(
                        width: 7,
                        height: 7
                    )

                Text(
                    "Target " + target
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .accessibilityElement(
            children: .combine
        )
        .accessibilityLabel(
            title
                + ", "
                + value
                + " "
                + unit
                + ", target "
                + target
        )
    }
    private var aerobicSection: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text("Aerobic activity")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(
                    """
                    Daily · moderate-equivalent minutes
                    """
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(
                    records,
                    id: \.dayStart
                ) { record in
                    BarMark(
                        x: .value(
                            "Day",
                            record.dayStart,
                            unit: .day
                        ),
                        y: .value(
                            "Minutes",
                            record
                                .guidelineModerateEquivalentMinutes
                        ),
                        width: .fixed(
                            aerobicBarWidth
                        )
                    )
                    .foregroundStyle(
                        ActivityTheme
                            .accent
                            .opacity(0.52)
                    )
                    .cornerRadius(4)
                }

                RuleMark(
                    y: .value(
                        "Target pace",
                        dailyAerobicPace
                    )
                )
                .foregroundStyle(
                    Color.secondary
                        .opacity(0.55)
                )
                .lineStyle(
                    StrokeStyle(
                        lineWidth: 1,
                        dash: [3, 3]
                    )
                )
                .annotation(
                    position: .top,
                    alignment: .trailing
                ) {
                    Text(
                        formatted(
                            dailyAerobicPace,
                            digits: 0
                        )
                        + " min/day pace"
                    )
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                trendXAxis
            }
            .chartYAxis(.hidden)
            .frame(height: 190)
            .accessibilityLabel(
                """
                Daily moderate-equivalent aerobic minutes for \(period.title)
                """
            )

            Text(
                """
                The dashed line is the weekly target divided by seven. A pace reference, not a daily requirement.
                """
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }

    private var strengthSection: some View {
        let gridSpacing:
            CGFloat =
                period == .ninetyDays
                    ? 5
                    : 8

        let columns = Array(
            repeating:
                GridItem(
                    .flexible(),
                    spacing: gridSpacing
                ),
            count:
                period
                    .strengthGridColumnCount
        )

        return VStack(
            alignment: .leading,
            spacing: 18
        ) {
            HStack(
                alignment: .top,
                spacing: 12
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text("Strength days")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(
                        "Each square is one day · "
                        + formatted(
                            strengthWeeklyPace,
                            digits: 1
                        )
                        + " per week on average"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }

                Spacer(minLength: 8)

                VStack(spacing: 0) {
                    Text(
                        String(strengthDayCount)
                    )
                    .font(.headline)

                    Text(
                        strengthDayCount == 1
                            ? "day"
                            : "days"
                    )
                    .font(.caption)
                }
                .padding(
                    .horizontal,
                    14
                )
                .padding(
                    .vertical,
                    7
                )
                .background(
                    ActivityTheme
                        .elevatedSurface,
                    in: Capsule()
                )
                .accessibilityElement(
                    children: .combine
                )
            }

            LazyVGrid(
                columns: columns,
                spacing: gridSpacing
            ) {
                ForEach(
                    records,
                    id: \.dayStart
                ) { record in
                    let isToday =
                        Calendar.current
                            .isDateInToday(
                                record.dayStart
                            )

                    RoundedRectangle(
                        cornerRadius:
                            period == .ninetyDays
                                ? 5
                                : 7,
                        style: .continuous
                    )
                    .fill(
                        record.isStrengthDay
                            ? ActivityTheme.success
                            : ActivityTheme
                                .elevatedSurface
                    )
                    .aspectRatio(
                        1,
                        contentMode: .fit
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius:
                                period == .ninetyDays
                                    ? 5
                                    : 7,
                            style: .continuous
                        )
                        .stroke(
                            isToday
                                ? ActivityTheme.accent
                                : Color.clear,
                            lineWidth: 1.5
                        )
                    }
                    .accessibilityLabel(
                        strengthDayAccessibilityLabel(
                            record
                        )
                    )
                }
            }

            strengthGridLegend
        }
    }
    
    private var strengthGridLegend:
        some View {

        HStack(spacing: 16) {
            Label {
                Text("Strength day")
            } icon: {
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .fill(
                    ActivityTheme.success
                )
                .frame(
                    width: 12,
                    height: 12
                )
            }

            Label {
                Text("None recorded")
            } icon: {
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .fill(
                    ActivityTheme
                        .elevatedSurface
                )
                .frame(
                    width: 12,
                    height: 12
                )
            }

            Label {
                Text("Today")
            } icon: {
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .fill(Color.clear)
                .frame(
                    width: 12,
                    height: 12
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 3,
                        style: .continuous
                    )
                    .stroke(
                        ActivityTheme.accent,
                        lineWidth: 1.5
                    )
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    private func strengthDayAccessibilityLabel(
        _ record: DailyActivityRecord
    ) -> String {
        let date =
            record.dayStart.formatted(
                date: .abbreviated,
                time: .omitted
            )

        if record.isStrengthDay {
            return date
                + ", strength day recorded"
        }

        return date
            + ", no strength workout recorded"
    }

    @ViewBuilder
    private var stepsSection: some View {
        let availableRecords =
            records.filter {
                $0.recordedSteps != nil
            }

        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            HStack(
                alignment: .top,
                spacing: 12
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text("Movement")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(
                        """
                        Recorded daily steps · context, not a target
                        """
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }

                Spacer(minLength: 8)

                if let averageSteps {
                    VStack(spacing: 0) {
                        Text(
                            formatted(
                                averageSteps,
                                digits: 0
                            )
                        )
                        .font(.headline)

                        Text("avg")
                            .font(.caption)
                    }
                    .padding(
                        .horizontal,
                        14
                    )
                    .padding(
                        .vertical,
                        7
                    )
                    .background(
                        ActivityTheme
                            .elevatedSurface,
                        in: Capsule()
                    )
                    .accessibilityElement(
                        children: .combine
                    )
                    .accessibilityLabel(
                        """
                        Average \(formatted(
                            averageSteps,
                            digits: 0
                        )) steps
                        """
                    )
                }
            }

            if availableRecords.isEmpty {
                Text("No accessible step data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 150
                    )
            } else {
                Chart {
                    ForEach(
                        availableRecords,
                        id: \.dayStart
                    ) { record in
                        if let steps =
                            record.recordedSteps {

                            AreaMark(
                                x: .value(
                                    "Day",
                                    record.dayStart,
                                    unit: .day
                                ),
                                y: .value(
                                    "Steps",
                                    steps
                                )
                            )
                            .foregroundStyle(
                                ActivityTheme
                                    .accent
                                    .opacity(0.10)
                            )

                            LineMark(
                                x: .value(
                                    "Day",
                                    record.dayStart,
                                    unit: .day
                                ),
                                y: .value(
                                    "Steps",
                                    steps
                                )
                            )
                            .foregroundStyle(
                                ActivityTheme.accent
                            )
                            .lineStyle(
                                StrokeStyle(
                                    lineWidth: 2
                                )
                            )
                            .interpolationMethod(
                                .linear
                            )
                        }
                    }

                    if let averageSteps {
                        RuleMark(
                            y: .value(
                                "Average",
                                averageSteps
                            )
                        )
                        .foregroundStyle(
                            Color.secondary
                                .opacity(0.55)
                        )
                        .lineStyle(
                            StrokeStyle(
                                lineWidth: 1,
                                dash: [3, 3]
                            )
                        )
                    }
                }
                .chartXAxis {
                    trendXAxis
                }
                .chartYAxis(.hidden)
                .frame(height: 170)
                .accessibilityLabel(
                    """
                    Daily movement chart for \(period.title)
                    """
                )
            }
        }
    }

    private var movementSummary: some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            ActivitySectionLabel(
                title: "Daily averages"
            )

            LazyVGrid(
                columns: [
                    GridItem(
                        .flexible(),
                        spacing: 12
                    ),
                    GridItem(
                        .flexible(),
                        spacing: 12
                    )
                ],
                spacing: 12
            ) {
                movementMetric(
                    title: "Steps",
                    value:
                        formattedOptional(
                            averageSteps,
                            digits: 0
                        )
                )

                movementMetric(
                    title: "Stand hours",
                    value:
                        formattedOptional(
                            averageStandHours,
                            digits: 1
                        )
                )

                movementMetric(
                    title: "Distance",
                    value:
                        formattedOptional(
                            averageDistanceKilometers,
                            digits: 1,
                            suffix: " km"
                        )
                )

                movementMetric(
                    title: "Active energy",
                    value:
                        formattedOptional(
                            averageActiveEnergy,
                            digits: 0,
                            suffix: " kcal"
                        )
                )
            }
        }
    }
    
    private func applyPendingPeriod() {
        defer {
            pendingPeriod = nil
        }

        guard purchases.hasPlusAccess,
              let pendingPeriod
        else {
            return
        }

        period = pendingPeriod
    }
    
    private func movementMetric(
        title: String,
        value: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .fontWidth(.condensed)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 72,
            alignment: .leading
        )
        .padding(18)
        .background(
            ActivityTheme.surface,
            in: RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                ActivityTheme.divider,
                lineWidth: 0.75
            )
        }
        .accessibilityElement(
            children: .combine
        )
        .accessibilityLabel(
            title + ", " + value
        )
    }

    private func chartHeading(
        title: String,
        detail: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 3
        ) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var trendXAxis:
        some AxisContent {

        AxisMarks(
            values: .stride(
                by: .day,
                count: period.axisStride
            )
        ) { value in
            AxisGridLine()
                .foregroundStyle(
                    ActivityTheme.divider
                )

            AxisTick()
                .foregroundStyle(
                    ActivityTheme.divider
                )

            AxisValueLabel {
                if let date =
                    value.as(Date.self) {

                    Text(axisLabel(for: date))
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No activity history",
            systemImage: "chart.xyaxis.line",
            description: Text(
                """
                Refresh Apple Health to build your trends.
                """
            )
        )
        .frame(
            maxWidth: .infinity,
            minHeight: 320
        )
    }

    private func axisLabel(
        for date: Date
    ) -> String {
        switch period {
        case .sevenDays:
            return date.formatted(
                .dateTime.weekday(.narrow)
            )

        case .thirtyDays,
             .ninetyDays:
            return date.formatted(
                .dateTime
                    .month(.abbreviated)
                    .day()
            )
        }
    }

    private func average(
        _ values: [Double]
    ) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +)
            / Double(values.count)
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
    
    private func compactWorkoutRow(
        _ workout: StoredWorkout
    ) -> some View {
        HStack(spacing: 14) {
            Image(
                systemName:
                    workoutSymbol(workout)
            )
            .font(.body)
            .foregroundStyle(
                ActivityTheme.accent
            )
            .frame(
                width: 44,
                height: 44
            )
            .background(
                ActivityTheme
                    .accent
                    .opacity(0.10),
                in: RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    workoutTitle(workout)
                )
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(2)

                Text(
                    workoutDateText(workout)
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(
                String(
                    max(
                        0,
                        Int(
                            workout
                                .durationMinutes
                                .rounded()
                        )
                    )
                )
                + " min"
            )
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
        }
        .padding(
            .vertical,
            13
        )
        .contentShape(Rectangle())
        .accessibilityElement(
            children: .combine
        )
    }
    
    private func workoutDateText(
        _ workout: StoredWorkout
    ) -> String {
        if Calendar.current.isDate(
            workout.startDate,
            inSameDayAs: AppRuntime.now
        ) {
            return "Today · "
                + workout.startDate.formatted(
                    date: .omitted,
                    time: .shortened
                )
        }

        return workout.startDate.formatted(
            .dateTime
                .weekday(.abbreviated)
                .day()
                .month(.abbreviated)
        )
    }

    
    private func workoutSymbol(
        _ workout: StoredWorkout
    ) -> String {
        guard let activityType =
            WorkoutTypeCatalog.definition(
                forRawValue:
                    workout
                        .activityTypeRawValue
            )?.activityType
        else {
            return workout
                .workoutRole
                .includesStrength
                ? "dumbbell"
                : "figure.run"
        }

        switch activityType {
        case .walking:
            return "figure.walk"

        case .running:
            return "figure.run"

        case .cycling:
            return "bicycle"

        case .traditionalStrengthTraining,
             .functionalStrengthTraining,
             .coreTraining:
            return "dumbbell"

        default:
            return workout
                .workoutRole
                .includesStrength
                ? "dumbbell"
                : "figure.run"
        }
    }
    
    private func workoutTitle(
        _ workout: StoredWorkout
    ) -> String {
        WorkoutTypeCatalog.definition(
            forRawValue:
                workout.activityTypeRawValue
        )?.title
        ?? "Workout"
    }
    private func formattedOptional(
        _ value: Double?,
        digits: Int,
        suffix: String = ""
    ) -> String {
        guard let value else {
            return "—"
        }

        return formatted(
            value,
            digits: digits
        ) + suffix
    }
}
