import SwiftUI
import SwiftData
import Charts

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

struct TrendsView: View {
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
        TrendPeriod = .thirtyDays

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

    private var dailyAerobicPace: Double {
        targets.aerobicMinimumMinutes / 7
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
                    primaryMetrics

                    ActivityDivider()
                        .padding(.vertical, 26)

                    aerobicSection

                    ActivityDivider()
                        .padding(.vertical, 26)

                    strengthSection

                    ActivityDivider()
                        .padding(.vertical, 26)

                    stepsSection

                    ActivityDivider()
                        .padding(.vertical, 26)

                    movementSummary
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
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            ActivitySectionLabel(
                title: "Activity trends"
            )

            Text(period.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontWidth(.condensed)
        }
    }

    private var periodPicker: some View {
        Picker(
            "Period",
            selection: $period
        ) {
            ForEach(
                TrendPeriod.allCases
            ) { period in
                Text(period.rawValue)
                    .tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(
            "Trend period"
        )
    }

    private var primaryMetrics: some View {
        let aerobicTargetText =
            formatted(
                targets.aerobicMinimumMinutes,
                digits: 0
            ) + " min"

        let strengthTargetText =
            "\(targets.strengthMinimumDays) days"

        return HStack(
            alignment: .top,
            spacing: 22
        ) {
            primaryMetric(
                title: "Aerobic pace",
                value:
                    formatted(
                        aerobicWeeklyPace,
                        digits: 0
                    ),
                target: aerobicTargetText,
                targetMet:
                    aerobicWeeklyPace
                    >= targets
                        .aerobicMinimumMinutes
            )

            Rectangle()
                .fill(ActivityTheme.divider)
                .frame(
                    width: 0.75,
                    height: 98
                )

            primaryMetric(
                title: "Strength pace",
                value:
                    formatted(
                        strengthWeeklyPace,
                        digits: 1
                    ),
                target: strengthTargetText,
                targetMet:
                    strengthWeeklyPace
                    >= Double(
                        targets.strengthMinimumDays
                    )
            )
        }
    }

    private func primaryMetric(
        title: String,
        value: String,
        target: String,
        targetMet: Bool
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 9
        ) {
            Text(value)
                .font(
                    ActivityTheme.largeMetricFont
                )
                .fontWidth(.condensed)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 5) {
                Circle()
                    .fill(
                        targetMet
                            ? ActivityTheme.success
                            : ActivityTheme.accent
                    )
                    .frame(
                        width: 6,
                        height: 6
                    )

                Text("Target \(target) / 7 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private var aerobicSection: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            chartHeading(
                title: "Aerobic activity",
                detail: "Moderate-equivalent minutes"
            )

            Chart(records) { record in
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
                    )
                )
                .foregroundStyle(
                    ActivityTheme.accent
                )
                .cornerRadius(3)

                RuleMark(
                    y: .value(
                        "Target pace",
                        dailyAerobicPace
                    )
                )
                .foregroundStyle(
                    Color.secondary.opacity(0.55)
                )
                .lineStyle(
                    StrokeStyle(
                        lineWidth: 1,
                        dash: [4, 4]
                    )
                )
            }
            .chartXAxis {
                trendXAxis
            }
            .chartYAxis {
                AxisMarks(
                    position: .leading
                ) {
                    AxisGridLine()
                        .foregroundStyle(
                            ActivityTheme.divider
                        )

                    AxisValueLabel()
                }
            }
            .frame(height: 190)

            Text(
                """
                The dashed line is the weekly target divided \
                by seven. It is a pace reference, not a daily \
                requirement.
                """
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var strengthSection: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            chartHeading(
                title: "Strength",
                detail: "Recorded strength days"
            )

            Chart(records) { record in
                BarMark(
                    x: .value(
                        "Day",
                        record.dayStart,
                        unit: .day
                    ),
                    y: .value(
                        "Strength day",
                        record.isStrengthDay
                            ? 1
                            : 0.06
                    )
                )
                .foregroundStyle(
                    record.isStrengthDay
                        ? ActivityTheme.success
                        : ActivityTheme
                            .elevatedSurface
                )
                .cornerRadius(3)
            }
            .chartYScale(domain: 0...1)
            .chartYAxis(.hidden)
            .chartXAxis {
                trendXAxis
            }
            .frame(height: 82)
        }
    }

    @ViewBuilder
    private var stepsSection: some View {
        let availableRecords =
            records.filter {
                $0.recordedSteps != nil
            }

        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            chartHeading(
                title: "Movement",
                detail: "Recorded daily steps"
            )

            if availableRecords.isEmpty {
                Text("No accessible step data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 100
                    )
            } else {
                Chart(availableRecords) {
                    record in

                    if let steps =
                        record.recordedSteps {

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

                        if period
                            == .sevenDays {

                            PointMark(
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
                        }
                    }
                }
                .chartXAxis {
                    trendXAxis
                }
                .chartYAxis {
                    AxisMarks(
                        position: .leading
                    ) {
                        AxisGridLine()
                            .foregroundStyle(
                                ActivityTheme.divider
                            )

                        AxisValueLabel()
                    }
                }
                .frame(height: 170)
            }
        }
    }

    private var movementSummary: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            ActivitySectionLabel(
                title: "Daily averages"
            )

            LazyVGrid(
                columns: [
                    GridItem(
                        .flexible(),
                        alignment: .leading
                    ),
                    GridItem(
                        .flexible(),
                        alignment: .leading
                    )
                ],
                spacing: 22
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
                    title: "Active energy",
                    value:
                        formattedOptional(
                            averageActiveEnergy,
                            digits: 0,
                            suffix: " kcal"
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
            }
        }
    }

    private func movementMetric(
        title: String,
        value: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
