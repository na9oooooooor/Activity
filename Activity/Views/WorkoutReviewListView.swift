import SwiftUI
import SwiftData

struct WorkoutReviewListView: View {
    @Query(
        sort: \StoredWorkout.startDate,
        order: .reverse
    )
    private var workouts: [StoredWorkout]

    private var workoutsNeedingReview:
        [StoredWorkout] {
        workouts.filter { workout in
            workout.needsRoleReview
                || workout.needsIntensityReview
        }
    }

    var body: some View {
        Group {
            if workoutsNeedingReview.isEmpty {
                ContentUnavailableView(
                    "Nothing to Review",
                    systemImage: "checkmark.circle",
                    description: Text(
                        """
                        Imported workouts have enough \
                        classification information.
                        """
                    )
                )
            } else {
                List(workoutsNeedingReview) {
                    workout in

                    NavigationLink {
                        WorkoutReviewDetailView(
                            workout: workout
                        )
                    } label: {
                        workoutRow(workout)
                    }
                }
            }
        }
        .navigationTitle("Workout Review")
    }

    private func workoutRow(
        _ workout: StoredWorkout
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text(workoutTitle(workout))
                .font(.headline)

            Text(
                workout.startDate.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text(
                    "\(Int(workout.durationMinutes)) min"
                )

                Text("·")

                Text(reviewReason(workout))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private func workoutTitle(
        _ workout: StoredWorkout
    ) -> String {
        WorkoutTypeCatalog.definition(
            forRawValue:
                workout.activityTypeRawValue
        )?.title
        ?? "New Workout Type"
    }

    private func reviewReason(
        _ workout: StoredWorkout
    ) -> String {
        if workout.needsRoleReview {
            return "Classification needed"
        }

        return "Intensity needed"
    }
}

#Preview {
    NavigationStack {
        WorkoutReviewListView()
    }
    .modelContainer(
        for: StoredWorkout.self,
        inMemory: true
    )
}
