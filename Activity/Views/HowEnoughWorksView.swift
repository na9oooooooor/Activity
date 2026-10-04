import SwiftUI

struct HowEnoughWorksView: View {
    var body: some View {
        List {
            Section {
                Text(
                    """
                    Enough helps you meet a sensible activity \
                    minimum, then lets you rest without chasing \
                    scores or streaks.
                    """
                )
            }

            Section("Your rolling week") {
                explanationRow(
                    systemImage: "calendar",
                    title: "Seven activity days",
                    text:
                        """
                        Today and the previous six activity days \
                        form your current window. It moves forward \
                        every day.
                        """
                )

                explanationRow(
                    systemImage: "arrow.forward",
                    title: "Activity leaves naturally",
                    text:
                        """
                        When an older day leaves the window, its \
                        minutes and strength credit leave too. \
                        Enough may suggest replacing activity that \
                        will leave soon.
                        """
                )
            }

            Section("Aerobic activity") {
                explanationRow(
                    systemImage: "figure.walk",
                    title: "Moderate activity",
                    text:
                        """
                        Each recorded moderate minute adds one \
                        minute toward your aerobic target.
                        """
                )

                explanationRow(
                    systemImage: "figure.run",
                    title: "Vigorous activity",
                    text:
                        """
                        Each vigorous minute counts as two \
                        moderate-equivalent minutes.
                        """
                )

                explanationRow(
                    systemImage: "apple.logo",
                    title: "Apple Exercise",
                    text:
                        """
                        Accessible Apple Exercise minutes can fill \
                        gaps not already represented by classified \
                        workouts.
                        """
                )
            }

            Section("Strength") {
                explanationRow(
                    systemImage: "dumbbell",
                    title: "Distinct strength days",
                    text:
                        """
                        A day counts when it contains at least one \
                        workout classified as Strength or Both. \
                        Multiple strength workouts on one day still \
                        count as one strength day.
                        """
                )

                explanationRow(
                    systemImage: "slider.horizontal.3",
                    title: "You control classification",
                    text:
                        """
                        Workout types have app defaults, but you can \
                        change an individual workout or the default \
                        classification for that workout type.
                        """
                )
            }

            Section("Everyday movement") {
                explanationRow(
                    systemImage: "shoeprints.fill",
                    title: "Steps provide context",
                    text:
                        """
                        Steps, distance, Stand Hours, and active \
                        energy help describe everyday movement. \
                        They do not automatically become aerobic \
                        target minutes.
                        """
                )
            }

            Section("Today’s suggestion") {
                explanationRow(
                    systemImage: "sparkles",
                    title: "One calm next step",
                    text:
                        """
                        Enough considers your remaining aerobic and \
                        strength gaps, recent counted activity, \
                        activity leaving the window, available data, \
                        and the context you select for today.
                        """
                )

                explanationRow(
                    systemImage: "bed.double",
                    title: "Recovery stays available",
                    text:
                        """
                        Choosing Recovery changes today’s suggestion. \
                        Enough does not estimate illness, injury, \
                        fatigue, or medical readiness.
                        """
                )
            }

            Section("Targets") {
                Text(
                    """
                    General adult guidance starts at 150 \
                    moderate-equivalent aerobic minutes and two \
                    strength days. If you use personal targets, \
                    your selected values are used instead.
                    """
                )

                Link(
                    "Read the WHO activity guidance",
                    destination: URL(
                        string:
                            "https://www.who.int/publications/i/item/9789240015128"
                    )!
                )
            }
        }
        .navigationTitle("How Enough Works")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func explanationRow(
        systemImage: String,
        title: String,
        text: String
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 12
        ) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(
                    ActivityTheme.accent
                )
                .frame(
                    width: 24,
                    alignment: .center
                )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(title)
                    .fontWeight(.semibold)

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
