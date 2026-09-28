import Foundation

struct AutomaticIntensityResult: Sendable {
    let moderateMinutes: Double?
    let vigorousMinutes: Double?
    let sourceRawValue: String

    static let unavailable =
        AutomaticIntensityResult(
            moderateMinutes: nil,
            vigorousMinutes: nil,
            sourceRawValue: "unknown"
        )
}

enum AutomaticIntensityClassifier {
    static func classify(
        workoutStart: Date,
        workoutEnd: Date,
        recordedDurationMinutes: Double,
        physicalEffort:
            [PhysicalEffortValue],
        averageMETs: Double?
    ) -> AutomaticIntensityResult {
        let effortResult =
            classifyPhysicalEffort(
                workoutStart: workoutStart,
                workoutEnd: workoutEnd,
                samples: physicalEffort
            )

        if let effortResult {
            return effortResult
        }

        return classifyAverageMETs(
            averageMETs,
            durationMinutes:
                recordedDurationMinutes
        )
    }

    private static func classifyPhysicalEffort(
        workoutStart: Date,
        workoutEnd: Date,
        samples: [PhysicalEffortValue]
    ) -> AutomaticIntensityResult? {
        let sortedSamples = samples.sorted {
            $0.startDate < $1.startDate
        }

        var moderateSeconds = 0.0
        var vigorousSeconds = 0.0
        var knownSeconds = 0.0


        var cursor = workoutStart

        for sample in sortedSamples {
            guard sample.metabolicEquivalent
                .isFinite
            else {
                continue
            }

            let clippedStart = max(
                workoutStart,
                sample.startDate,
                cursor
            )

            let clippedEnd = min(
                workoutEnd,
                sample.endDate
            )

            guard clippedEnd > clippedStart
            else {
                continue
            }

            let seconds =
                clippedEnd.timeIntervalSince(
                    clippedStart
                )

            knownSeconds += seconds

            if sample.metabolicEquivalent >= 6 {
                vigorousSeconds += seconds
            } else if sample
                .metabolicEquivalent >= 3 {
                moderateSeconds += seconds
            }

            cursor = clippedEnd
        }

        guard knownSeconds > 0 else {
            return nil
        }

        return AutomaticIntensityResult(
            moderateMinutes:
                moderateSeconds / 60,
            vigorousMinutes:
                vigorousSeconds / 60,
            sourceRawValue: "physicalEffort"
        )
    }

    private static func classifyAverageMETs(
        _ averageMETs: Double?,
        durationMinutes: Double
    ) -> AutomaticIntensityResult {
        guard let averageMETs,
              averageMETs.isFinite,
              averageMETs >= 0,
              durationMinutes > 0
        else {
            return .unavailable
        }

        if averageMETs < 3 {
            return AutomaticIntensityResult(
                moderateMinutes: 0,
                vigorousMinutes: 0,
                sourceRawValue: "averageMETs"
            )
        }


        return AutomaticIntensityResult(
            moderateMinutes: durationMinutes,
            vigorousMinutes: 0,
            sourceRawValue:
                "averageMETsConservative"
        )
    }
}
