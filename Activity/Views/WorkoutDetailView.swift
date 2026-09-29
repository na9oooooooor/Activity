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

    @State private var showingDeleteConfirmation =
        false

    @State private var isDeleting = false

    @State private var errorMessage = ""

    @State private var showingError = false

    private var title: String {
        WorkoutTypeCatalog.definition(
            forRawValue:
                workout.activityTypeRawValue
        )?.title
        ?? "Workout"
    }

    private var wasCreatedByThisApp: Bool {
        let bundleIdentifier =
            Bundle.main.bundleIdentifier

        return workout.sourceBundleIdentifier
            == bundleIdentifier
            || workout.sourceBundleIdentifier
                == "activity.manual"
    }

    private var moderateEquivalentMinutes:
        Double {

        (workout.moderateMinutes ?? 0)
            + (2 * (
                workout.vigorousMinutes
                    ?? 0
            ))
    }

    var body: some View {
        Form {
            Section("Workout") {
                LabeledContent(
                    "Type",
                    value: title
                )

                LabeledContent(
                    "Date",
                    value:
                        workout.startDate.formatted(
                            date: .long,
                            time: .omitted
                        )
                )

                LabeledContent(
                    "Started",
                    value:
                        workout.startDate.formatted(
                            date: .omitted,
                            time: .shortened
                        )
                )

                LabeledContent(
                    "Duration",
                    value:
                        "\(formatted(workout.durationMinutes)) min"
                )
            }

            Section("Activity Health") {
                LabeledContent(
                    "Classification",
                    value:
                        workout.workoutRole.title
                )

                if workout.workoutRole
                    .includesAerobic {

                    LabeledContent(
                        "Moderate",
                        value:
                            "\(formatted(workout.moderateMinutes ?? 0)) min"
                    )

                    LabeledContent(
                        "Vigorous",
                        value:
                            "\(formatted(workout.vigorousMinutes ?? 0)) min"
                    )

                    LabeledContent(
                        "Moderate-equivalent",
                        value:
                            "\(formatted(moderateEquivalentMinutes)) min"
                    )
                }

                LabeledContent(
                    "Strength day",
                    value:
                        workout.countsTowardStrength
                        ? "Yes"
                        : "No"
                )
            }

            Section("Source") {
                LabeledContent(
                    "Recorded by",
                    value:
                        wasCreatedByThisApp
                        ? "Enough"
                        : workout.sourceName
                )

                if wasCreatedByThisApp {
                    Text(
                        """
                        This workout was added through Enough \
                        and is also stored in Apple Health.
                        """
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Text(
                        """
                        This workout is managed by \
                        \(workout.sourceName). You can remove \
                        it from that app or from Apple Health.
                        """
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if wasCreatedByThisApp {
                Section {
                    Button(
                        role: .destructive
                    ) {
                        showingDeleteConfirmation =
                            true
                    } label: {
                        if isDeleting {
                            HStack {
                                ProgressView()

                                Text(
                                    "Deleting Workout…"
                                )
                            }
                        } else {
                            Text("Delete Workout")
                        }
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text(
                        """
                        This removes the workout from Enough \
                        and Apple Health.
                        """
                    )
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this workout?",
            isPresented:
                $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                "Delete from Enough and Health",
                role: .destructive
            ) {
                Task {
                    await deleteWorkout()
                }
            }

            Button(
                "Cancel",
                role: .cancel
            ) {}
        } message: {
            Text(
                """
                The workout will no longer count toward your \
                activity results.
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
        guard !isDeleting else {
            return
        }

        isDeleting = true

        defer {
            isDeleting = false
        }

        do {
            try await healthKit
                .deleteManualWorkout(
                    healthKitUUID:
                        workout.healthKitUUID
                )

            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            try repository
                .deleteStoredWorkout(workout)

            onDeleted()
            dismiss()
        } catch {
            errorMessage =
                error.localizedDescription

            showingError = true
        }
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
