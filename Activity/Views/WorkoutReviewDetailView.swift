import SwiftUI
import SwiftData

struct WorkoutReviewDetailView: View {
    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.dismiss)
    private var dismiss

    let workout: StoredWorkout

    @State private var selectedRole:
        WorkoutRole

    @State private var selectedIntensity:
        WorkoutIntensityChoice?

    @State private var aerobicMinutes:
        Double

    @State private var moderateMinutes:
        Double = 0

    @State private var vigorousMinutes:
        Double = 0

    @State private var errorMessage: String?
    @State private var isShowingError = false

    init(workout: StoredWorkout) {
        self.workout = workout

        _selectedRole = State(
            initialValue: workout.workoutRole
        )

        _selectedIntensity = State(
            initialValue: nil
        )

        _aerobicMinutes = State(
            initialValue:
                floor(workout.durationMinutes)
        )
    }

    var body: some View {
        Form {
            Section("Workout") {
                LabeledContent(
                    "Type",
                    value: workoutTitle
                )

                LabeledContent(
                    "Date",
                    value:
                        workout.startDate.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                )

                LabeledContent(
                    "Duration",
                    value:
                        "\(Int(workout.durationMinutes)) min"
                )

                LabeledContent(
                    "Source",
                    value: workout.sourceName
                )
            }

            Section("What did it include?") {
                Picker(
                    "Classification",
                    selection: $selectedRole
                ) {
                    Text("Choose…")
                        .tag(WorkoutRole.unknown)

                    ForEach(
                        WorkoutRole.userChoices,
                        id: \.self
                    ) { role in
                        Text(role.title)
                            .tag(role)
                    }
                }
            }

            if selectedRole.includesAerobic {
                aerobicReviewSection
            }

            Section {
                Button("Save Review") {
                    saveReview()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(workoutTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Couldn’t Save Review",
            isPresented: $isShowingError
        ) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(
                errorMessage
                    ?? "An unknown error occurred."
            )
        }
    }

    @ViewBuilder
    private var aerobicReviewSection:
        some View {
        Section("Aerobic Intensity") {
            Picker(
                "Intensity",
                selection: $selectedIntensity
            ) {
                Text("Choose…")
                    .tag(
                        Optional<
                            WorkoutIntensityChoice
                        >.none
                    )

                ForEach(
                    WorkoutIntensityChoice.allCases
                ) { intensity in
                    Text(intensity.title)
                        .tag(
                            Optional(intensity)
                        )
                }
            }

            if let selectedIntensity {
                Text(selectedIntensity.guidance)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                minuteFields(
                    for: selectedIntensity
                )
            }
        }
    }

    @ViewBuilder
    private func minuteFields(
        for intensity: WorkoutIntensityChoice
    ) -> some View {
        switch intensity {
        case .light:
            Text(
                """
                This workout will add no moderate or \
                vigorous minutes.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

        case .moderate, .vigorous:
            TextField(
                "Aerobic minutes",
                value: $aerobicMinutes,
                format:
                    .number.precision(
                        .fractionLength(0...1)
                    )
            )
            .keyboardType(.decimalPad)

        case .mixed:
            TextField(
                "Moderate minutes",
                value: $moderateMinutes,
                format:
                    .number.precision(
                        .fractionLength(0...1)
                    )
            )
            .keyboardType(.decimalPad)

            TextField(
                "Vigorous minutes",
                value: $vigorousMinutes,
                format:
                    .number.precision(
                        .fractionLength(0...1)
                    )
            )
            .keyboardType(.decimalPad)
        }
    }

    private var workoutTitle: String {
        WorkoutTypeCatalog.definition(
            forRawValue:
                workout.activityTypeRawValue
        )?.title
        ?? "New Workout Type"
    }

    private func saveReview() {
        do {
            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            try repository.reviewWorkout(
                workout,
                role: selectedRole,
                intensity: selectedIntensity,
                aerobicMinutes: aerobicMinutes,
                moderateMinutes: moderateMinutes,
                vigorousMinutes: vigorousMinutes
            )

            dismiss()
        } catch {
            errorMessage =
                error.localizedDescription

            isShowingError = true
        }
    }
}
