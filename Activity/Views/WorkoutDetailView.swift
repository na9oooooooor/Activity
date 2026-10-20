import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    let workout: StoredWorkout
    let healthKit: HealthKitService
    let onDeleted: () -> Void

    @State private var showingDeleteConfirmation = false
    @State private var showingIntensityEditor = false
    @State private var isDeleting = false

    @State private var errorMessage = ""
    @State private var showingError = false

    private var title: String {
        WorkoutTypeCatalog.definition(
            forRawValue: workout.activityTypeRawValue
        )?.title ?? "Workout"
    }

    private var wasCreatedByThisApp: Bool {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        return workout.sourceBundleIdentifier == bundleIdentifier || workout.sourceBundleIdentifier == "activity.manual"
    }

    private var currentIntensity: WorkoutIntensityChoice {
        let moderate = workout.moderateMinutes ?? 0
        let vigorous = workout.vigorousMinutes ?? 0

        if moderate > 0 && vigorous > 0 { return .mixed }
        if vigorous > 0 { return .vigorous }
        if moderate > 0 { return .moderate }
        return .light
    }

    private var intensitySourceText: String {
        switch workout.intensitySourceRawValue {
        case "userReviewed":
            return "Adjusted by you"
        case "physicalEffort":
            return "Detected from Apple Watch effort"
        case "averageMETs":
            return "Detected from workout intensity"
        case "workoutDurationConservative":
            return "Moderate fallback"
        case "manualEntry":
            return "Selected when added"
        default:
            return "Estimated automatically"
        }
    }

    private var moderateEquivalentMinutes: Double {
        (workout.moderateMinutes ?? 0) + (2 * (workout.vigorousMinutes ?? 0))
    }

    var body: some View {
        Form {
            Section("Workout") {
                LabeledContent("Type", value: title)

                LabeledContent(
                    "Date",
                    value: workout.startDate.formatted(date: .long, time: .omitted)
                )

                LabeledContent(
                    "Started",
                    value: workout.startDate.formatted(date: .omitted, time: .shortened)
                )

                LabeledContent(
                    "Duration",
                    value: "\(formatted(workout.durationMinutes)) min"
                )
            }

            Section {
                LabeledContent("Classification", value: workout.workoutRole.title)

                if workout.workoutRole.includesAerobic {
                    Button {
                        showingIntensityEditor = true
                    } label: {
                        HStack {
                            Text("Intensity")
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(currentIntensity.title)
                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    LabeledContent(
                        "Moderate",
                        value: "\(formatted(workout.moderateMinutes ?? 0)) min"
                    )

                    LabeledContent(
                        "Vigorous",
                        value: "\(formatted(workout.vigorousMinutes ?? 0)) min"
                    )

                    LabeledContent(
                        "Moderate-equivalent",
                        value: "\(formatted(moderateEquivalentMinutes)) min"
                    )
                }

                LabeledContent(
                    "Strength day",
                    value: workout.countsTowardStrength ? "Yes" : "No"
                )
            } header: {
                Text("Activity Health")
            } footer: {
                if workout.workoutRole.includesAerobic {
                    Text(intensitySourceText + ". Vigorous minutes count twice toward your aerobic target.")
                }
            }

            Section("Source") {
                LabeledContent(
                    "Recorded by",
                    value: wasCreatedByThisApp ? "Enough" : workout.sourceName
                )

                if wasCreatedByThisApp {
                    Text(
                        """
                        This workout was added through Enough and is also stored in Apple Health.
                        """
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Text(
                        """
                        This workout is managed by \(workout.sourceName). You can remove it from that app or from Apple Health.
                        """
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if wasCreatedByThisApp {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        if isDeleting {
                            HStack {
                                ProgressView()
                                Text("Deleting Workout…")
                            }
                        } else {
                            Text("Delete Workout")
                        }
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text(
                        """
                        This removes the workout from Enough and Apple Health.
                        """
                    )
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingIntensityEditor) {
            WorkoutIntensityEditor(
                durationMinutes: workout.durationMinutes,
                initialIntensity: currentIntensity,
                initialVigorousMinutes: workout.vigorousMinutes ?? workout.durationMinutes / 2
            ) { intensity, vigorousMinutes in
                saveIntensity(intensity, vigorousMinutes: vigorousMinutes)
            }
        }
        .confirmationDialog(
            "Delete this workout?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                "Delete from Enough and Health",
                role: .destructive
            ) {
                Task { await deleteWorkout() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                """
                The workout will no longer count toward your activity results.
                """
            )
        }
        .alert(
            "Couldn’t Delete Workout",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    @MainActor
    private func deleteWorkout() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await healthKit.deleteManualWorkout(healthKitUUID: workout.healthKitUUID)

            let repository = ActivityRepository(modelContext: modelContext)
            try repository.deleteStoredWorkout(workout)

            onDeleted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func saveIntensity(
        _ intensity: WorkoutIntensityChoice,
        vigorousMinutes: Double
    ) {
        do {
            let repository = ActivityRepository(modelContext: modelContext)
            try repository.setWorkoutIntensityOverride(
                workout,
                intensity: intensity,
                mixedVigorousMinutes: vigorousMinutes
            )
            onDeleted()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private struct WorkoutIntensityEditor: View {
        @Environment(\.dismiss) private var dismiss

        let durationMinutes: Double
        let onSave: (WorkoutIntensityChoice, Double) -> Void

        @State private var intensity: WorkoutIntensityChoice
        @State private var vigorousMinutes: Double

        init(
            durationMinutes: Double,
            initialIntensity: WorkoutIntensityChoice,
            initialVigorousMinutes: Double,
            onSave: @escaping (WorkoutIntensityChoice, Double) -> Void
        ) {
            self.durationMinutes = max(0, durationMinutes)
            self.onSave = onSave
            _intensity = State(initialValue: initialIntensity)
            _vigorousMinutes = State(initialValue: min(max(0, initialVigorousMinutes), max(0, durationMinutes)))
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        Picker("Intensity", selection: $intensity) {
                            ForEach(WorkoutIntensityChoice.allCases) { choice in
                                Text(choice.title).tag(choice)
                            }
                        }

                        Text(intensity.guidance)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if intensity == .mixed {
                        Section("Mixed workout") {
                            Slider(
                                value: $vigorousMinutes,
                                in: 0...max(1, durationMinutes),
                                step: 1
                            )

                            LabeledContent(
                                "Vigorous",
                                value: "\(formatted(vigorousMinutes)) min"
                            )

                            // Use a single-line string to avoid multiline interpolation issues
                            let moderate = max(0, durationMinutes - vigorousMinutes)
                            LabeledContent(
                                "Moderate",
                                value: "\(formatted(moderate)) min"
                            )
                        }
                    }

                    Section {
                        Text(
                            """
                            Vigorous minutes count twice toward your aerobic target. This adjustment affects only this workout.
                            """
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Adjust Intensity")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(intensity, vigorousMinutes)
                            dismiss()
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }

        private func formatted(_ value: Double) -> String {
            value.formatted(.number.precision(.fractionLength(0)))
        }
    }
}
