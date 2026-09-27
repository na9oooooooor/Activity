import SwiftUI
import SwiftData

struct WorkoutClassificationSettingsView: View {
    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort:
            \WorkoutRolePreference
                .activityTypeRawValue
    )
    private var preferences:
        [WorkoutRolePreference]

    @Query
    private var storedWorkouts:
        [StoredWorkout]

    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var isShowingError = false

    private var recordedTypeValues: Set<Int> {
        Set(
            storedWorkouts.map(
                \.activityTypeRawValue
            )
        )
    }

    private var matchingDefinitions:
        [WorkoutTypeDefinition] {
        guard !searchText.isEmpty else {
            return WorkoutTypeCatalog.all
        }

        return WorkoutTypeCatalog.all.filter {
            definition in

            definition.title
                .localizedCaseInsensitiveContains(
                    searchText
                )
        }
    }

    private var recordedDefinitions:
        [WorkoutTypeDefinition] {
        matchingDefinitions.filter {
            recordedTypeValues.contains(
                $0.activityTypeRawValue
            )
        }
    }

    private var remainingDefinitions:
        [WorkoutTypeDefinition] {
        matchingDefinitions.filter {
            !recordedTypeValues.contains(
                $0.activityTypeRawValue
            )
        }
    }

    var body: some View {
        List {
            if !unrecognizedRecordedTypeValues.isEmpty {
                Section("New or Unrecognized Types") {
                    ForEach(
                        unrecognizedRecordedTypeValues,
                        id: \.self
                    ) { rawValue in
                        unrecognizedClassificationRow(
                            rawValue: rawValue
                        )
                    }
                }
            }
            if !recordedDefinitions.isEmpty {
                Section("In Your History") {
                    ForEach(recordedDefinitions) {
                        definition in

                        classificationRow(
                            for: definition
                        )
                    }
                }
            }

            Section("All Workout Types") {
                ForEach(remainingDefinitions) {
                    definition in

                    classificationRow(
                        for: definition
                    )
                }
            }

            Section {
                Text(
                    """
                    A workout classification decides whether an \
                    activity can contribute aerobic minutes, a \
                    strength day, both, or neither. Aerobic minutes \
                    still require intensity evidence.
                    """
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Workout Types")
        .searchable(
            text: $searchText,
            prompt: "Search workouts"
        )
        .alert(
            "Couldn’t Save",
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
    private func classificationRow(
        for definition: WorkoutTypeDefinition
    ) -> some View {
        let preference = preference(
            for: definition.activityTypeRawValue
        )

        let effectiveRole =
            preference?.workoutRole
            ?? definition.defaultRole

        Menu {
            Button {
                updatePreference(
                    for: definition,
                    role: nil
                )
            } label: {
                menuLabel(
                    title:
                        "Use Default (\(definition.defaultRole.title))",
                    selected: preference == nil
                )
            }

            Divider()

            ForEach(
                WorkoutRole.userChoices,
                id: \.self
            ) { role in
                Button {
                    updatePreference(
                        for: definition,
                        role: role
                    )
                } label: {
                    menuLabel(
                        title: role.title,
                        selected:
                            preference?.workoutRole
                                == role
                    )
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(definition.title)
                        .foregroundStyle(.primary)

                    Text(
                        preference == nil
                            ? "Default"
                            : "Your setting"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(effectiveRole.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Image(
                    systemName:
                        "chevron.up.chevron.down"
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(definition.title)
        .accessibilityValue(effectiveRole.title)
    }
    @ViewBuilder
    private func unrecognizedClassificationRow(
        rawValue: Int
    ) -> some View {
        let preference = preference(
            for: rawValue
        )

        let effectiveRole =
            preference?.workoutRole ?? .unknown

        Menu {
            Button {
                updatePreference(
                    activityTypeRawValue: rawValue,
                    role: nil
                )
            } label: {
                menuLabel(
                    title: "Keep for Review",
                    selected: preference == nil
                )
            }

            Divider()

            ForEach(
                WorkoutRole.userChoices,
                id: \.self
            ) { role in
                Button {
                    updatePreference(
                        activityTypeRawValue:
                            rawValue,
                        role: role
                    )
                } label: {
                    menuLabel(
                        title: role.title,
                        selected:
                            preference?.workoutRole
                                == role
                    )
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text("New Workout Type")

                    Text("HealthKit code \(rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(effectiveRole.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Image(
                    systemName:
                        "chevron.up.chevron.down"
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
    }
    
    @ViewBuilder
    private func menuLabel(
        title: String,
        selected: Bool
    ) -> some View {
        if selected {
            Label(
                title,
                systemImage: "checkmark"
            )
        } else {
            Text(title)
        }
    }

    private func preference(
        for activityTypeRawValue: Int
    ) -> WorkoutRolePreference? {
        preferences.first {
            $0.activityTypeRawValue
                == activityTypeRawValue
        }
    }

    private func updatePreference(
        for definition: WorkoutTypeDefinition,
        role: WorkoutRole?
    ) {
        updatePreference(
            activityTypeRawValue:
                definition.activityTypeRawValue,
            role: role
        )
    }

    private func updatePreference(
        activityTypeRawValue: Int,
        role: WorkoutRole?
    ) {
        do {
            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            try repository
                .setWorkoutRolePreference(
                    activityTypeRawValue:
                        activityTypeRawValue,
                    role: role
                )
        } catch {
            errorMessage =
                error.localizedDescription

            isShowingError = true
        }
    }
    
    private var unrecognizedRecordedTypeValues:
        [Int] {
        recordedTypeValues
            .subtracting(
                WorkoutTypeCatalog.knownRawValues
            )
            .sorted()
    }
}

#Preview {
    NavigationStack {
        WorkoutClassificationSettingsView()
    }
    .modelContainer(
        for: [
            StoredWorkout.self,
            WorkoutRolePreference.self,
            DailyActivityRecord.self,
            StoredDailyCheckIn.self,
            AppSettings.self
        ],
        inMemory: true
    )
}
