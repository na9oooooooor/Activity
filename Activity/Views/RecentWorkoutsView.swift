import SwiftUI
import SwiftData

struct RecentWorkoutsView: View {
    @Query(
        sort: \StoredWorkout.startDate,
        order: .reverse
    )
    private var workouts:
        [StoredWorkout]

    let healthKit: HealthKitService
    let onWorkoutsChanged: () -> Void

    var body: some View {
        Group {
            if workouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts",
                    systemImage:
                        "figure.walk",
                    description: Text(
                        """
                        Workouts imported from Apple Health \
                        and workouts you add will appear here.
                        """
                    )
                )
            } else {
                List {
                    ForEach(
                        workouts,
                        id: \.healthKitUUID
                    ) { workout in
                        NavigationLink {
                            WorkoutDetailView(
                                workout: workout,
                                healthKit: healthKit,
                                onDeleted:
                                    onWorkoutsChanged
                            )
                        } label: {
                            workoutRow(workout)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(
                placement: .topBarTrailing
            ) {
                NavigationLink {
                    ManualWorkoutEntryView(
                        healthKit: healthKit
                    ) {
                        onWorkoutsChanged()
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(
                    "Add workout"
                )
            }
        }
    }

    private func workoutRow(
        _ workout: StoredWorkout
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            HStack {
                Text(workoutTitle(workout))
                    .font(.headline)

                Spacer()

                Text(
                    "\(formattedDuration(workout)) min"
                )
                .font(.headline)
                .fontWidth(.condensed)
            }

            Text(
                workout.startDate.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(workout.workoutRole.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(
                        .horizontal,
                        9
                    )
                    .padding(
                        .vertical,
                        5
                    )
                    .background(
                        roleTint(
                            workout.workoutRole
                        )
                        .opacity(0.12),
                        in: Capsule()
                    )
                    .foregroundStyle(
                        roleTint(
                            workout.workoutRole
                        )
                    )

                Spacer()

                Text(sourceText(workout))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(
            children: .combine
        )
    }

    private func workoutTitle(
        _ workout: StoredWorkout
    ) -> String {
        WorkoutTypeCatalog.definition(
            forRawValue:
                workout.activityTypeRawValue
        )?.title
        ?? "Workout"
    }

    private func formattedDuration(
        _ workout: StoredWorkout
    ) -> Int {
        max(
            0,
            Int(
                workout.durationMinutes
                    .rounded()
            )
        )
    }

    private func sourceText(
        _ workout: StoredWorkout
    ) -> String {
        if isCreatedByThisApp(workout) {
            return "Added here"
        }

        return workout.sourceName
    }

    private func isCreatedByThisApp(
        _ workout: StoredWorkout
    ) -> Bool {
        let appBundleIdentifier =
            Bundle.main.bundleIdentifier

        return workout
            .sourceBundleIdentifier
            == appBundleIdentifier
            || workout
                .sourceBundleIdentifier
                == "activity.manual"
    }

    private func roleTint(
        _ role: WorkoutRole
    ) -> Color {
        switch role {
        case .aerobic:
            return .blue

        case .strength:
            return .orange

        case .both:
            return .green

        case .neither:
            return .secondary

        case .unknown:
            return .secondary
        }
    }
}
