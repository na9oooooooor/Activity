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
            return "7 days"

        case .thirtyDays:
            return "30 days"

        case .ninetyDays:
            return "90 days"
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

    @State private var period:
        TrendPeriod = .thirtyDays

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

        let total = records.reduce(0) {
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

    private var averageSteps: Double? {
        let values =
            records.compactMap { record in
                record.recordedSteps.map(
                    Double.init
                )
            }

        return average(values)
    }

    private var averageStandHours: Double? {
        let values =
            records.compactMap { record in
                record.standHours.map(
                    Double.init
                )
            }

        return average(values)
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
                spacing: 16
            ) {
                periodPicker

                if records.isEmpty {
                    ContentUnavailableView(
                        "No Activity History",
                        systemImage:
                            "chart.xyaxis.line",
                        description: Text(
                            """
                            Refresh Apple Health to build \
                            your trends.
                            """
                        )
                    )
                } else {
                    summaryGrid
                    aerobicChart
                    stepsChart
                    standHoursChart
                }
            }
            .padding()
        }
        .background(
            Color(
                uiColor:
                    .systemGroupedBackground
            )
        )
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(
            .inline
        )
    }

    private var periodPicker:
        some View {

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

    private var summaryGrid:
        some View {

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
            summaryCard(
                title: "Aerobic pace",
                value:
                    "\(formatted(aerobicWeeklyPace, digits: 0)) min",
                detail: "Per 7 days"
            )

            summaryCard(
                title: "Steps",
                value:
                    formattedOptional(
                        averageSteps,
                        digits: 0
                    ),
                detail: "Daily average"
            )

            summaryCard(
                title: "Stand Hours",
                value:
                    formattedOptional(
                        averageStandHours,
                        digits: 1
                    ),
                detail: "Daily average"
            )

            summaryCard(
                title: "Active energy",
                value:
                    formattedOptional(
                        averageActiveEnergy,
                        digits: 0,
                        suffix: " kcal"
                    ),
                detail: "Daily average"
            )

            summaryCard(
                title: "Distance",
                value:
                    formattedOptional(
                        averageDistanceKilometers,
                        digits: 1,
                        suffix: " km"
                    ),
                detail: "Daily average"
            )
        }
    }

    private var aerobicChart:
        some View {

        trendCard(
            title: "Aerobic activity",
            detail:
                "Moderate-equivalent minutes"
        ) {
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
                    Color.blue.gradient
                )
                .cornerRadius(3)
            }
            .frame(height: 190)
        }
    }

    @ViewBuilder
    private var stepsChart:
        some View {

        let availableRecords =
            records.filter {
                $0.recordedSteps != nil
            }

        trendCard(
            title: "Steps",
            detail: "Recorded daily steps"
        ) {
            if availableRecords.isEmpty {
                unavailableChartMessage
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
                            Color.cyan
                        )

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
                            Color.cyan
                        )
                    }
                }
                .frame(height: 190)
            }
        }
    }

    @ViewBuilder
    private var standHoursChart:
        some View {

        let availableRecords =
            records.filter {
                $0.standHours != nil
            }

        trendCard(
            title: "Stand Hours",
            detail:
                "Hours with recorded standing movement"
        ) {
            if availableRecords.isEmpty {
                unavailableChartMessage
            } else {
                Chart(availableRecords) {
                    record in

                    if let hours =
                        record.standHours {

                        BarMark(
                            x: .value(
                                "Day",
                                record.dayStart,
                                unit: .day
                            ),
                            y: .value(
                                "Hours",
                                hours
                            )
                        )
                        .foregroundStyle(
                            Color.indigo.gradient
                        )
                        .cornerRadius(3)
                    }
                }
                .frame(height: 190)
            }
        }
    }

    private var unavailableChartMessage:
        some View {

        Text("No accessible data")
            .foregroundStyle(.secondary)
            .frame(
                maxWidth: .infinity,
                minHeight: 120
            )
    }

    private func summaryCard(
        title: String,
        value: String,
        detail: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            Color(
                uiColor:
                    .secondarySystemGroupedBackground
            ),
            in: RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }

    private func trendCard<
        Content: View
    >(
        title: String,
        detail: String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding()
        .background(
            Color(
                uiColor:
                    .secondarySystemGroupedBackground
            ),
            in: RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
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
