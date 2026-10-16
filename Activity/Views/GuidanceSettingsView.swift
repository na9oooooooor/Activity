import SwiftUI
import SwiftData

struct GuidanceSettingsView: View {
    @Query
    private var savedSettings:
        [AppSettings]

    private var settings: AppSettings? {
        savedSettings.first
    }

    private var currentTargets:
        ActivityTargets {

        settings?.activityTargets
            ?? .generalAdultGuidance
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(
                    "Aerobic",
                    value: "150 min"
                )

                LabeledContent(
                    "Strength",
                    value: "2 days"
                )
            } header: {
                Text("Starting guidance")
            } footer: {
                Text(
                    """
                    Enough applies these starting targets across \
                    your latest seven days.
                    """
                )
            }

            if settings?
                .usesCustomActivityTargets
                == true {

                Section("Your custom targets") {
                    LabeledContent(
                        "Aerobic",
                        value:
                            formatted(
                                currentTargets
                                    .aerobicMinimumMinutes
                            ) + " min"
                    )

                    LabeledContent(
                        "Strength",
                        value:
                            String(
                                currentTargets
                                    .strengthMinimumDays
                            ) + " days"
                    )
                }
            }

            Section {
                Link(
                    "World Health Organization guidance",
                    destination: URL(
                        string:
                            "https://www.who.int/publications-detail-redirect/9789240015128"
                    )!
                )
            } footer: {
                Text(
                    """
                    These are general public-health references. \
                    Both targets can be customized with Enough Plus.
                    """
                )
            }
        }
        .navigationTitle("Activity Guidance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatted(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0)
            )
        )
    }
}
