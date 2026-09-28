import SwiftUI

struct SevenDayActivityStrip: View {
    let days: [ActivityStripDay]
    let aerobicTargetMinutes: Double
    let status: ActivityHealthStatus
    let recordState: RecordState

    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private let plotHeight: CGFloat = 76
    private let barWidth: CGFloat = 34

    private var dailyPaceMinutes: Double {
        guard aerobicTargetMinutes > 0 else {
            return 0
        }

        return aerobicTargetMinutes / 7
    }

    /*
     The chart uses the largest recorded day or slightly
     more than the daily target pace as its vertical scale.
     */
    private var chartMaximumMinutes: Double {
        let largestDay =
            days
                .map(\.moderateEquivalentMinutes)
                .max() ?? 0

        return max(
            1,
            largestDay,
            dailyPaceMinutes * 1.25
        )
    }

    private var paceLineHeight: CGFloat {
        guard chartMaximumMinutes > 0 else {
            return 0
        }

        return min(
            plotHeight,
            plotHeight
                * CGFloat(
                    dailyPaceMinutes
                    / chartMaximumMinutes
                )
        )
    }

    private var tint: Color {
        switch status {
        case .meetingTargets:
            return ActivityTheme.success

        case .belowTargets,
             .updating,
             .unavailable:
            return ActivityTheme.accent
        }
    }

    private var contentOpacity: Double {
        switch recordState {
        case .importing, .stale:
            return 0.5

        case .current, .unavailable:
            return 1
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                chart

                strengthMarkers

                weekdayLabels
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(contentOpacity)
        .animation(
            reduceMotion
                ? nil
                : .easeOut(duration: 0.45),
            value:
                days.map(
                    \.moderateEquivalentMinutes
                )
        )
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            "Seven-day activity"
        )
        .accessibilityValue(
            accessibilitySummary
        )
        .accessibilityHint(
            "Opens how Activity Health is calculated"
        )
    }

    private var chart: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(
                    Color.secondary.opacity(0.35)
                )
                .frame(height: 0.75)
                .offset(
                    y: -paceLineHeight
                )
                .accessibilityHidden(true)

            HStack(
                alignment: .bottom,
                spacing: 8
            ) {
                ForEach(days) { day in
                    bar(for: day)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .bottom
                        )
                }
            }
        }
        .frame(height: plotHeight)
    }

    private var strengthMarkers: some View {
        HStack(spacing: 8) {
            ForEach(days) { day in
                Circle()
                    .fill(
                        day.isStrengthDay
                            ? tint
                            : Color.clear
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                day.isStrengthDay
                                    ? tint
                                    : ActivityTheme
                                        .divider,
                                lineWidth: 0.8
                            )
                    }
                    .frame(
                        width: 6,
                        height: 6
                    )
                    .frame(
                        maxWidth: .infinity
                    )
            }
        }
        .accessibilityHidden(true)
    }

    private var weekdayLabels: some View {
        HStack(spacing: 8) {
            ForEach(days) { day in
                Text(
                    day.dayStart.formatted(
                        .dateTime
                            .weekday(.narrow)
                    )
                )
                .font(.caption)
                .fontWeight(
                    day.isToday
                        ? .bold
                        : .regular
                )
                .foregroundStyle(
                    day.isToday
                        ? .primary
                        : .secondary
                )
                .frame(
                    maxWidth: .infinity
                )
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func bar(
        for day: ActivityStripDay
    ) -> some View {
        let height = barHeight(for: day)

        if !day.hasData {
            RoundedRectangle(
                cornerRadius: 3,
                style: .continuous
            )
            .stroke(
                Color.secondary.opacity(0.45),
                style: StrokeStyle(
                    lineWidth: 1,
                    dash: [4, 3]
                )
            )
            .frame(
                width: barWidth,
                height: 9
            )
        } else if day.isToday {
            RoundedRectangle(
                cornerRadius: 3,
                style: .continuous
            )
            .fill(
                day.moderateEquivalentMinutes > 0
                    ? tint.opacity(0.14)
                    : Color.clear
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .stroke(
                    tint,
                    style: StrokeStyle(
                        lineWidth: 1.25,
                        dash: [5, 3]
                    )
                )
            }
            .frame(
                width: barWidth,
                height: height
            )
        } else if day
            .moderateEquivalentMinutes > 0 {

            RoundedRectangle(
                cornerRadius: 3,
                style: .continuous
            )
            .fill(tint)
            .frame(
                width: barWidth,
                height: height
            )
        } else {
            RoundedRectangle(
                cornerRadius: 3,
                style: .continuous
            )
            .fill(
                ActivityTheme.elevatedSurface
            )
            .frame(
                width: barWidth,
                height: 5
            )
        }
    }

    private func barHeight(
        for day: ActivityStripDay
    ) -> CGFloat {
        guard day.hasData else {
            return 9
        }

        guard day.moderateEquivalentMinutes > 0
        else {
            return 5
        }

        let proportion =
            day.moderateEquivalentMinutes
            / chartMaximumMinutes

        return max(
            7,
            min(
                plotHeight,
                plotHeight
                    * CGFloat(proportion)
            )
        )
    }

    private var accessibilitySummary: String {
        let activeDays =
            days.filter {
                $0.moderateEquivalentMinutes > 0
            }.count

        let strengthDays =
            days.filter(\.isStrengthDay).count

        guard days.contains(where: \.hasData)
        else {
            return """
            No readable activity data in the last seven days.
            """
        }

        let strengthUnit =
            strengthDays == 1
            ? "strength day"
            : "strength days"

        return """
        \(activeDays) of \(days.count) days include aerobic \
        activity, \(strengthDays) \(strengthUnit).
        """
    }
}
