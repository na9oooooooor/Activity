import SwiftUI
import SwiftData

struct ManualWorkoutEntryView: View {
    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query
    private var rolePreferences:
        [WorkoutRolePreference]

    let onSaved: () -> Void

    @State private var selectedActivityTypeRawValue:
        Int?

    @State private var startDate =
        Date.now.addingTimeInterval(-30 * 60)

    @State private var durationMinutes = 30

    @State private var role:
        WorkoutRole = .aerobic

    @State private var intensity:
        WorkoutIntensityChoice = .moderate

    @State private var vigorousMinutes = 10

    @State private var errorMessage = ""

    @State private var showingError = false

    private var selectedDefinition:
        WorkoutTypeDefinition? {

        guard let selectedActivityTypeRawValue
        else {
            return nil
        }

        return WorkoutTypeCatalog.definition(
            forRawValue:
                selectedActivityTypeRawValue
        )
    }

    private var workoutEndDate: Date {
        startDate.addingTimeInterval(
            Double(durationMinutes) * 60
        )
    }

    private var canSave: Bool {
        selectedDefinition != nil
            && durationMinutes > 0
            && workoutEndDate
                <= Date.now.addingTimeInterval(60)
    }

    var body: some View {
        Form {
            workoutSection
            classificationSection
            saveSection
        }
        .navigationTitle("Add Workout")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(
            of: selectedActivityTypeRawValue
        ) { _, newValue in
            guard let newValue else {
                return
            }

            applyDefaultRole(
                for: newValue
            )
        }
        .onChange(of: durationMinutes) {
            _, newDuration in

            vigorousMinutes = min(
                vigorousMinutes,
                newDuration
            )
        }
        .alert(
            "Couldn’t Add Workout",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var workoutSection: some View {
        Section("Workout") {
            NavigationLink {
                ManualWorkoutTypePicker(
                    selectedRawValue:
                        $selectedActivityTypeRawValue
                )
            } label: {
                LabeledContent(
                    "Type",
                    value:
                        selectedDefinition?
                            .title
                        ?? "Choose"
                )
            }

            DatePicker(
                "Started",
                selection: $startDate,
                in: ...Date.now,
                displayedComponents: [
                    .date,
                    .hourAndMinute
                ]
            )

            Stepper(
                value: $durationMinutes,
                in: 5...300,
                step: 5
            ) {
                LabeledContent(
                    "Duration",
                    value:
                        "\(durationMinutes) min"
                )
            }
        }
    }

    @ViewBuilder
    private var classificationSection:
        some View {

        Section {
            Picker(
                "Counts as",
                selection: $role
            ) {
                ForEach(
                    WorkoutRole.userChoices,
                    id: \.self
                ) { choice in
                    Text(choice.title)
                        .tag(choice)
                }
            }

            if role.includesAerobic {
                Picker(
                    "Intensity",
                    selection: $intensity
                ) {
                    ForEach(
                        WorkoutIntensityChoice.allCases
                    ) { choice in
                        Text(choice.title)
                            .tag(choice)
                    }
                }

                Text(intensity.guidance)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if intensity == .mixed {
                    Stepper(
                        value: $vigorousMinutes,
                        in: 0...durationMinutes,
                        step: 5
                    ) {
                        LabeledContent(
                            "Vigorous portion",
                            value:
                                "\(vigorousMinutes) min"
                        )
                    }

                    LabeledContent(
                        "Moderate portion",
                        value:
                            "\(durationMinutes - vigorousMinutes) min"
                    )
                }
            }
        } header: {
            Text("Classification")
        } footer: {
            Text(
                """
                The initial classification comes from your \
                Workout Classifications settings. Changing it \
                here affects only this workout.
                """
            )
        }
    }

    @ViewBuilder
    private var saveSection: some View {
        Section {
            Button {
                saveWorkout()
            } label: {
                Text("Add Workout")
                    .frame(
                        maxWidth: .infinity
                    )
            }
            .disabled(!canSave)
        } footer: {
            if workoutEndDate > Date.now {
                Text(
                    """
                    The workout’s duration extends beyond \
                    the current time.
                    """
                )
                .foregroundStyle(.orange)
            } else {
                Text(
                    """
                    Manual workouts are stored in this app. \
                    They are not written to Apple Health.
                    """
                )
            }
        }
    }

    private func applyDefaultRole(
        for activityTypeRawValue: Int
    ) {
        if let preference =
            rolePreferences.first(
                where: {
                    $0.activityTypeRawValue
                        == activityTypeRawValue
                }
            ),
           preference.workoutRole
                != .unknown {

            role = preference.workoutRole
            return
        }

        role =
            WorkoutTypeCatalog.definition(
                forRawValue:
                    activityTypeRawValue
            )?.defaultRole
            ?? .neither
    }

    private func saveWorkout() {
        guard let selectedDefinition else {
            return
        }

        let values = aerobicValues()

        do {
            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            try repository.addManualWorkout(
                activityTypeRawValue:
                    selectedDefinition
                        .activityTypeRawValue,
                startDate: startDate,
                durationMinutes:
                    Double(durationMinutes),
                role: role,
                intensity:
                    role.includesAerobic
                        ? intensity
                        : nil,
                aerobicMinutes:
                    values.aerobic,
                moderateMinutes:
                    values.moderate,
                vigorousMinutes:
                    values.vigorous
            )

            onSaved()
            dismiss()
        } catch {
            errorMessage =
                error.localizedDescription

            showingError = true
        }
    }

    private func aerobicValues() -> (
        aerobic: Double,
        moderate: Double,
        vigorous: Double
    ) {
        guard role.includesAerobic else {
            return (0, 0, 0)
        }

        let total =
            Double(durationMinutes)

        switch intensity {
        case .light:
            return (0, 0, 0)

        case .moderate:
            return (total, 0, 0)

        case .vigorous:
            return (total, 0, 0)

        case .mixed:
            let vigorous = Double(
                min(
                    vigorousMinutes,
                    durationMinutes
                )
            )

            let moderate =
                max(0, total - vigorous)

            return (
                total,
                moderate,
                vigorous
            )
        }
    }
}

private struct ManualWorkoutTypePicker:
    View {

    @Environment(\.dismiss)
    private var dismiss

    @Binding var selectedRawValue: Int?

    @State private var searchText = ""

    private var filteredDefinitions:
        [WorkoutTypeDefinition] {

        guard !searchText.isEmpty else {
            return WorkoutTypeCatalog.all
        }

        return WorkoutTypeCatalog.all.filter {
            $0.title.localizedCaseInsensitiveContains(
                searchText
            )
        }
    }

    var body: some View {
        List(filteredDefinitions) {
            definition in

            Button {
                selectedRawValue =
                    definition
                        .activityTypeRawValue

                dismiss()
            } label: {
                HStack {
                    Text(definition.title)
                        .foregroundStyle(.primary)

                    Spacer()

                    if selectedRawValue
                        == definition
                            .activityTypeRawValue {

                        Image(
                            systemName: "checkmark"
                        )
                    }
                }
            }
        }
        .navigationTitle("Workout Type")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            prompt: "Search workouts"
        )
    }
}
