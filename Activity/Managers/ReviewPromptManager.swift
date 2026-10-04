import Foundation

enum ReviewPromptManager {
    private static let useDaysKey =
        "enough.review.useDays"

    private static let promptedVersionKey =
        "enough.review.promptedVersion"

    private static let minimumUseDays = 4

    static func recordUseDay(
        now: Date = .now
    ) {
        let defaults =
            UserDefaults.standard

        let calendar =
            Calendar.autoupdatingCurrent

        let today =
            calendar.startOfDay(
                for: now
            )

        var recordedDays =
            storedUseDays()

        let alreadyRecorded =
            recordedDays.contains {
                calendar.isDate(
                    $0,
                    inSameDayAs: today
                )
            }

        guard !alreadyRecorded else {
            return
        }

        recordedDays.append(today)

        /*
         Only eligibility matters. Keeping the most recent
         30 days avoids indefinitely growing preferences.
         */
        recordedDays =
            recordedDays
                .sorted()
                .suffix(30)
                .map { $0 }

        defaults.set(
            recordedDays.map(
                \.timeIntervalSince1970
            ),
            forKey: useDaysKey
        )
    }

    static var isEligible:
        Bool {

        guard storedUseDays().count
                >= minimumUseDays
        else {
            return false
        }

        return promptedVersion
            != currentAppVersion
    }

    static func markPromptRequested() {
        UserDefaults.standard.set(
            currentAppVersion,
            forKey:
                promptedVersionKey
        )
    }

    private static var promptedVersion:
        String? {

        UserDefaults.standard.string(
            forKey:
                promptedVersionKey
        )
    }

    private static var currentAppVersion:
        String {

        Bundle.main.object(
            forInfoDictionaryKey:
                "CFBundleShortVersionString"
        ) as? String ?? "unknown"
    }

    private static func storedUseDays()
        -> [Date] {

        let values =
            UserDefaults.standard.array(
                forKey: useDaysKey
            ) ?? []

        return values.compactMap {
            guard let number =
                    $0 as? NSNumber
            else {
                return nil
            }

            return Date(
                timeIntervalSince1970:
                    number.doubleValue
            )
        }
    }
}
