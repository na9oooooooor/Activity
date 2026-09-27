import Foundation
import HealthKit
import Observation

enum HealthKitAccessState: Equatable {
    case unavailable
    case readyToRequest
    case requesting
    case requestFinished
    case failed(String)

    var message: String {
        switch self {
        case .unavailable:
            return "Apple Health is unavailable on this device."

        case .readyToRequest:
            return "Apple Health access has not been requested yet."

        case .requesting:
            return "Waiting for the Apple Health permission sheet."

        case .requestFinished:
            return """
            The permission request finished. Accessible data will \
            be checked during import.
            """

        case .failed(let message):
            return "Apple Health request failed: \(message)"
        }
    }

    var isRequesting: Bool {
        self == .requesting
    }

    var canRequest: Bool {
        switch self {
        case .unavailable, .requesting:
            return false

        case .readyToRequest,
             .requestFinished,
             .failed:
            return true
        }
    }
}

@MainActor
@Observable
final class HealthKitService {
    private let healthStore: HKHealthStore

    private(set) var accessState: HealthKitAccessState

    init(
        healthStore: HKHealthStore = HKHealthStore()
    ) {
        self.healthStore = healthStore

        if HKHealthStore.isHealthDataAvailable() {
            self.accessState = .readyToRequest
        } else {
            self.accessState = .unavailable
        }
    }

    func requestReadAccess() async {
        guard HKHealthStore.isHealthDataAvailable()
        else {
            accessState = .unavailable
            return
        }

        accessState = .requesting

        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: readTypes
            )

            accessState = .requestFinished
        } catch {
            accessState = .failed(
                error.localizedDescription
            )
        }
    }
    
    func importWorkouts(
        using repository: ActivityRepository,
        now: Date = .now
    ) async throws -> WorkoutImportResult {
        let range = try repository.workoutImportRange(
            now: now
        )

        let workouts = try await fetchWorkouts(
            from: range.start,
            to: range.end
        )

        return try repository.importWorkouts(
            workouts,
            importedAt: now
        )
    }
    
    func fetchWorkouts(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthKitWorkoutValue] {
        let datePredicate =
            HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: [.strictStartDate]
            )

        let query =
            HKSampleQueryDescriptor<HKWorkout>(
                predicates: [
                    .workout(datePredicate)
                ],
                sortDescriptors: [
                    SortDescriptor(
                        \HKWorkout.startDate,
                        order: .forward
                    )
                ]
            )

        let workouts = try await query.result(
            for: healthStore
        )

        return workouts.map { workout in
            HealthKitWorkoutValue(
                healthKitUUID:
                    workout.uuid.uuidString,
                startDate:
                    workout.startDate,
                endDate:
                    workout.endDate,
                activityTypeRawValue:
                    Int(
                        workout
                            .workoutActivityType
                            .rawValue
                    ),
                sourceName:
                    workout
                        .sourceRevision
                        .source
                        .name,
                sourceBundleIdentifier:
                    workout
                        .sourceRevision
                        .source
                        .bundleIdentifier
            )
        }
    }
    
    private var readTypes: Set<HKObjectType> {
        [
            HKObjectType.workoutType(),

            HKQuantityType(.physicalEffort),
            HKQuantityType(.stepCount),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),

            HKCategoryType(.appleStandHour)
        ]
    }
}
