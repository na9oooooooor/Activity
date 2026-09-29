import Foundation
import HealthKit
import Observation

private enum ManualWorkoutMetadataKey {
    static let role =
        "com.nas.Activity.manualWorkout.role"

    static let intensity =
        "com.nas.Activity.manualWorkout.intensity"

    static let moderateMinutes =
        "com.nas.Activity.manualWorkout.moderateMinutes"

    static let vigorousMinutes =
        "com.nas.Activity.manualWorkout.vigorousMinutes"
}

enum HealthKitWriteError: LocalizedError {
    case invalidActivityType
    case workoutWriteDenied
    case workoutUnavailableAfterSaving
    case workoutDeleteFailed

    var errorDescription: String? {
        switch self {
        case .invalidActivityType:
            return "This workout type cannot be saved."

        case .workoutWriteDenied:
            return """
            Activity Health does not have permission to save \
            workouts to Apple Health. You can change this in \
            the Health app.
            """

        case .workoutUnavailableAfterSaving:
            return """
            Apple Health saved the workout, but it could not \
            return the saved record.
            """
            
        case .workoutDeleteFailed:
            return """
            The workout could not be deleted from Apple Health.
            """
        }
    }
}

enum HealthKitAccessState: Equatable {
    case unavailable
    case checking
    case readyToRequest
    case requesting
    case requestFinished
    case failed(String)

    var message: String {
        switch self {
        case .unavailable:
            return "Apple Health is unavailable on this device."

        case .checking:
            return "Checking Apple Health access."

        case .readyToRequest:
            return "Connect Apple Health to import your activity."

        case .requesting:
            return "Waiting for the Apple Health permission sheet."

        case .requestFinished:
            return "Apple Health is connected."

        case .failed(let message):
            return "Apple Health request failed: \(message)"
        }
    }

    var isRequesting: Bool {
        self == .requesting
    }

    var canRequest: Bool {
        switch self {
        case .readyToRequest, .failed:
            return true

        case .unavailable,
             .checking,
             .requesting,
             .requestFinished:
            return false
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
            self.accessState = .checking
        } else {
            self.accessState = .unavailable
        }
    }
    
    func refreshAccessState() async {
        guard HKHealthStore.isHealthDataAvailable()
        else {
            accessState = .unavailable
            return
        }

        accessState = .checking

        do {
            let requestStatus =
                try await authorizationRequestStatus()

            switch requestStatus {
            case .shouldRequest:
                accessState = .readyToRequest

            case .unnecessary:
                accessState = .requestFinished

            case .unknown:
                accessState = .failed(
                    """
                    Apple Health access status could not be \
                    determined.
                    """
                )

            @unknown default:
                accessState = .failed(
                    """
                    Apple Health returned an unsupported \
                    authorization state.
                    """
                )
            }
        } catch {
            accessState = .failed(
                error.localizedDescription
            )
        }
    }
    
    func requestReadAccess() async {
        guard HKHealthStore.isHealthDataAvailable()
        else {
            accessState = .unavailable
            return
        }

        do {
            let requestStatus =
                try await authorizationRequestStatus()

            switch requestStatus {
            case .shouldRequest:
                accessState = .requesting

                try await healthStore.requestAuthorization(
                    toShare: shareTypes,
                    read: readTypes
                )

                accessState = .requestFinished

            case .unnecessary:
         
                accessState = .requestFinished

            case .unknown:
                accessState = .failed(
                    """
                    The app could not determine whether Apple \
                    Health access is needed.
                    """
                )

            @unknown default:
                accessState = .failed(
                    """
                    Apple Health returned an unsupported \
                    authorization state.
                    """
                )
            }
        } catch {
            accessState = .failed(
                error.localizedDescription
            )
        }
    }
    

    
    private func fetchDailyMovement(
        using plan: HealthKitImportPlan
    ) async throws -> [HealthKitDailyMovementValue] {
        /*
         Optional movement metrics must fail independently.
         A missing stand-hours or distance permission should
         not prevent workouts and other readable activity
         from importing.
         */

        let steps: [Date: Double] =
            (
                try? await fetchDailyCumulativeTotals(
                    for: .stepCount,
                    unit: .count(),
                    using: plan
                )
            ) ?? [:]

        let exerciseMinutes: [Date: Double] =
            (
                try? await fetchDailyCumulativeTotals(
                    for: .appleExerciseTime,
                    unit: .minute(),
                    using: plan
                )
            ) ?? [:]

        let activeEnergy: [Date: Double] =
            (
                try? await fetchDailyCumulativeTotals(
                    for: .activeEnergyBurned,
                    unit: .kilocalorie(),
                    using: plan
                )
            ) ?? [:]

        let walkingRunningDistance:
            [Date: Double] =
            (
                try? await fetchDailyCumulativeTotals(
                    for: .distanceWalkingRunning,
                    unit: .meter(),
                    using: plan
                )
            ) ?? [:]

        let cyclingDistance: [Date: Double] =
            (
                try? await fetchDailyCumulativeTotals(
                    for: .distanceCycling,
                    unit: .meter(),
                    using: plan
                )
            ) ?? [:]

        let standHours: [Date: Int] =
            (
                try? await fetchDailyStandHours(
                    using: plan
                )
            ) ?? [:]

        var calendar =
            Calendar(identifier: .gregorian)

        calendar.timeZone =
            TimeZone(
                identifier:
                    plan.timeZoneIdentifier
            ) ?? .current

        var results:
            [HealthKitDailyMovementValue] = []

        var dayStart = plan.startDate

        while dayStart < plan.endDate {
            let recordedSteps =
                steps[dayStart].map {
                    max(
                        0,
                        Int($0.rounded())
                    )
                }

            results.append(
                HealthKitDailyMovementValue(
                    dayStart: dayStart,
                    steps: recordedSteps,
                    appleExerciseMinutes:
                        exerciseMinutes[dayStart],
                    standHours:
                        standHours[dayStart],
                    activeEnergyKilocalories:
                        activeEnergy[dayStart],
                    walkingRunningDistanceMeters:
                        walkingRunningDistance[
                            dayStart
                        ],
                    cyclingDistanceMeters:
                        cyclingDistance[dayStart]
                )
            )

            guard
                let nextDay = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: dayStart
                ),
                nextDay > dayStart
            else {
                break
            }

            dayStart = nextDay
        }

        return results
    }

    private func fetchDailyCumulativeTotals(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        using plan: HealthKitImportPlan
    ) async throws -> [Date: Double] {
        guard let quantityType =
            HKObjectType.quantityType(
                forIdentifier: identifier
            )
        else {
            return [:]
        }

        var calendar =
            Calendar(identifier: .gregorian)

        calendar.timeZone =
            TimeZone(
                identifier:
                    plan.timeZoneIdentifier
            ) ?? .current

        let predicate =
            HKQuery.predicateForSamples(
                withStart: plan.startDate,
                end: plan.endDate,
                options: []
            )

        var interval = DateComponents()
        interval.calendar = calendar
        interval.timeZone = calendar.timeZone
        interval.day = 1

        return try await withCheckedThrowingContinuation {
            (
                continuation:
                    CheckedContinuation<
                        [Date: Double],
                        Error
                    >
            ) in

            let query =
                HKStatisticsCollectionQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate:
                        predicate,
                    options: .cumulativeSum,
                    anchorDate: plan.startDate,
                    intervalComponents: interval
                )

            query.initialResultsHandler = {
                _,
                collection,
                error in

                if let error {
                    continuation.resume(
                        throwing: error
                    )

                    return
                }

                guard let collection else {
                    continuation.resume(
                        returning: [:]
                    )

                    return
                }

                var dailyTotals:
                    [Date: Double] = [:]

                collection.enumerateStatistics(
                    from: plan.startDate,
                    to: plan.endDate
                ) { statistics, _ in
                    guard let quantity =
                        statistics.sumQuantity()
                    else {
                        return
                    }

                    let value =
                        quantity.doubleValue(
                            for: unit
                        )

                    guard value.isFinite else {
                        return
                    }

                    dailyTotals[
                        statistics.startDate
                    ] = max(0, value)
                }

                continuation.resume(
                    returning: dailyTotals
                )
            }

            healthStore.execute(query)
        }
    }
    
    private func fetchDailyStandHours(
        using plan: HealthKitImportPlan
    ) async throws -> [Date: Int] {
        let standType =
            HKCategoryType(.appleStandHour)

        let datePredicate =
            HKQuery.predicateForSamples(
                withStart: plan.startDate,
                end: plan.endDate,
                options: []
            )

        let query =
            HKSampleQueryDescriptor<
                HKCategorySample
            >(
                predicates: [
                    .categorySample(
                        type: standType,
                        predicate: datePredicate
                    )
                ],
                sortDescriptors: [
                    SortDescriptor(
                        \HKCategorySample.startDate,
                        order: .forward
                    )
                ]
            )

        let samples = try await query.result(
            for: healthStore
        )

        var calendar =
            Calendar(identifier: .gregorian)

        calendar.timeZone =
            TimeZone(
                identifier:
                    plan.timeZoneIdentifier
            ) ?? .current

        /*
         A set prevents duplicate samples from counting the
         same standing hour more than once.
         */
        var recordedDays = Set<Date>()

        var stoodHourStartsByDay:
            [Date: Set<Date>] = [:]

        for sample in samples {
            let dayStart =
                movementDayStart(
                    containing: sample.startDate,
                    calendar: calendar,
                    startHour:
                        plan.activityDayStartHour
                )

            recordedDays.insert(dayStart)

            guard sample.value ==
                HKCategoryValueAppleStandHour
                    .stood
                    .rawValue
            else {
                /*
                 Idle samples show that stand-hour data exists
                 for this day, but they do not add a stood hour.
                 */
                continue
            }

            let hourStart =
                calendar.dateInterval(
                    of: .hour,
                    for: sample.startDate
                )?.start ?? sample.startDate

            stoodHourStartsByDay[
                dayStart,
                default: []
            ].insert(hourStart)
        }

        var totals: [Date: Int] = [:]

        for dayStart in recordedDays {
            totals[dayStart] =
                stoodHourStartsByDay[
                    dayStart
                ]?.count ?? 0
        }

        return totals
    }

    private func movementDayStart(
        containing date: Date,
        calendar: Calendar,
        startHour: Int
    ) -> Date {
        let safeStartHour = min(
            8,
            max(0, startHour)
        )

        let calendarMidnight =
            calendar.startOfDay(for: date)

        let currentBoundary =
            calendar.date(
                byAdding: .hour,
                value: safeStartHour,
                to: calendarMidnight
            ) ?? calendarMidnight

        if date >= currentBoundary {
            return currentBoundary
        }

        let previousMidnight =
            calendar.date(
                byAdding: .day,
                value: -1,
                to: calendarMidnight
            ) ?? calendarMidnight

        return calendar.date(
            byAdding: .hour,
            value: safeStartHour,
            to: previousMidnight
        ) ?? previousMidnight
    }
    
    private func authorizationRequestStatus()
        async throws -> HKAuthorizationRequestStatus {

        try await withCheckedThrowingContinuation {
            continuation in

            healthStore.getRequestStatusForAuthorization(
                toShare: shareTypes,
                read: readTypes
            ) { status, error in
                if let error {
                    continuation.resume(
                        throwing: error
                    )

                    return
                }

                continuation.resume(
                    returning: status
                )
            }
        }
    }
    
    func saveManualWorkout(
        activityTypeRawValue: Int,
        startDate: Date,
        durationMinutes: Double,
        role: WorkoutRole,
        intensity: WorkoutIntensityChoice?,
        moderateMinutes: Double,
        vigorousMinutes: Double
    ) async throws -> HKWorkout {
        guard
            let rawValue = UInt(
                exactly: activityTypeRawValue
            ),
            let activityType =
                HKWorkoutActivityType(
                    rawValue: rawValue
                )
        else {
            throw HealthKitWriteError
                .invalidActivityType
        }

        try await ensureWorkoutWriteAccess()

        let endDate =
            startDate.addingTimeInterval(
                durationMinutes * 60
            )

        let configuration =
            HKWorkoutConfiguration()

        configuration.activityType =
            activityType

        configuration.locationType =
            .unknown

        let builder =
            HKWorkoutBuilder(
                healthStore: healthStore,
                configuration: configuration,
                device: .local()
            )

        try await builder.beginCollection(
            at: startDate
        )

        var metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: true,
            HKMetadataKeyTimeZone:
                TimeZone.current.identifier,
            HKMetadataKeyExternalUUID:
                UUID().uuidString,
            ManualWorkoutMetadataKey.role:
                role.rawValue,
            ManualWorkoutMetadataKey
                .moderateMinutes:
                moderateMinutes,
            ManualWorkoutMetadataKey
                .vigorousMinutes:
                vigorousMinutes
        ]

        if let intensity {
            metadata[
                ManualWorkoutMetadataKey.intensity
            ] = intensity.rawValue
        }

        try await builder.addMetadata(metadata)

        try await builder.endCollection(
            at: endDate
        )

        guard let workout =
            try await builder.finishWorkout()
        else {
            throw HealthKitWriteError
                .workoutUnavailableAfterSaving
        }

        return workout
    }

    private func ensureWorkoutWriteAccess()
        async throws {

        let workoutType =
            HKObjectType.workoutType()

        switch healthStore.authorizationStatus(
            for: workoutType
        ) {
        case .sharingAuthorized:
            return

        case .notDetermined:
            try await healthStore
                .requestAuthorization(
                    toShare: shareTypes,
                    read: readTypes
                )

            guard healthStore.authorizationStatus(
                for: workoutType
            ) == .sharingAuthorized
            else {
                throw HealthKitWriteError
                    .workoutWriteDenied
            }

        case .sharingDenied:
            throw HealthKitWriteError
                .workoutWriteDenied

        @unknown default:
            throw HealthKitWriteError
                .workoutWriteDenied
        }
    }
    
    func importHealthData(
        using repository: ActivityRepository,
        now: Date = .now
    ) async throws -> WorkoutImportResult {

        let plan = try repository
            .healthKitImportPlan(now: now)

        let workouts = try await fetchWorkouts(
            from: plan.startDate,
            to: plan.endDate
        )


        let workoutResult =
            try repository.importWorkouts(
                workouts,
                importedAt: now
            )

        try repository.rebuildDailyActivityRecords(
            from: plan.startDate,
            through: now,
            calculatedAt: now
        )

        let dailyMovement =
            try await fetchDailyMovement(
                using: plan
            )
        

        try repository.applyDailyMovement(
            dailyMovement,
            calculatedAt: now
        )
        return workoutResult
    }
    
    func deleteManualWorkout(
        healthKitUUID: String
    ) async throws {

        guard let uuid =
            UUID(uuidString: healthKitUUID)
        else {
            return
        }

        try await ensureWorkoutWriteAccess()

        let predicate =
            HKQuery.predicateForObject(
                with: uuid
            )

        try await withCheckedThrowingContinuation {
            (
                continuation:
                    CheckedContinuation<Void, Error>
            ) in

            healthStore.deleteObjects(
                of: HKObjectType.workoutType(),
                predicate: predicate
            ) {
                success,
                _,
                error in

                if let error {
                    continuation.resume(
                        throwing: error
                    )

                    return
                }

                guard success else {
                    continuation.resume(
                        throwing:
                            HealthKitWriteError
                                .workoutDeleteFailed
                    )

                    return
                }

                continuation.resume()
            }
        }
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

        var values: [HealthKitWorkoutValue] = []
        values.reserveCapacity(workouts.count)

        for workout in workouts {
            let effortSamples =
                await fetchPhysicalEffort(
                    for: workout
                )

            let averageMETs =
                averageMETs(for: workout)

            values.append(
                HealthKitWorkoutValue(
                    healthKitUUID:
                        workout.uuid.uuidString,
                    startDate:
                        workout.startDate,
                    endDate:
                        workout.endDate,
                    recordedDurationMinutes:
                        max(
                            0,
                            workout.duration / 60
                        ),
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
                            .bundleIdentifier,
                    physicalEffortSamples:
                        effortSamples,
                    averageMETs:
                        averageMETs,
                    manualRole:
                        manualRole(from: workout),
                    manualModerateMinutes:
                        manualMinutes(
                            ManualWorkoutMetadataKey
                                .moderateMinutes,
                            from: workout
                        ),
                    manualVigorousMinutes:
                        manualMinutes(
                            ManualWorkoutMetadataKey
                                .vigorousMinutes,
                            from: workout
                        )
                )
            )
        }

        return values
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
    
    private var shareTypes: Set<HKSampleType> {
        [
            HKObjectType.workoutType()
        ]
    }
    
    private func fetchPhysicalEffort(
        for workout: HKWorkout
    ) async -> [PhysicalEffortValue] {
 
        let associatedPredicate =
            HKQuery.predicateForObjects(
                from: workout
            )

        if let associated =
            try? await queryPhysicalEffort(
                matching: associatedPredicate
            ),
           !associated.isEmpty {
            return associated
        }


        let timePredicate =
            HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: [
                    .strictStartDate,
                    .strictEndDate
                ]
            )

        return (
            try? await queryPhysicalEffort(
                matching: timePredicate
            )
        ) ?? []
    }

    private func queryPhysicalEffort(
        matching predicate: NSPredicate
    ) async throws -> [PhysicalEffortValue] {
        let effortType =
            HKQuantityType(.physicalEffort)

        let query =
            HKSampleQueryDescriptor<
                HKQuantitySample
            >(
                predicates: [
                    .quantitySample(
                        type: effortType,
                        predicate: predicate
                    )
                ],
                sortDescriptors: [
                    SortDescriptor(
                        \HKQuantitySample.startDate,
                        order: .forward
                    )
                ]
            )

        let samples = try await query.result(
            for: healthStore
        )

        let metUnit = HKUnit(
            from: "kcal/(kg*hr)"
        )

        return samples.map { sample in
            PhysicalEffortValue(
                startDate: sample.startDate,
                endDate: sample.endDate,
                metabolicEquivalent:
                    sample.quantity.doubleValue(
                        for: metUnit
                    )
            )
        }
    }
    
    private func manualRole(
        from workout: HKWorkout
    ) -> WorkoutRole? {
        guard
            let rawValue =
                workout.metadata?[
                    ManualWorkoutMetadataKey.role
                ] as? String,
            let role =
                WorkoutRole(rawValue: rawValue),
            role != .unknown
        else {
            return nil
        }

        return role
    }

    private func manualMinutes(
        _ key: String,
        from workout: HKWorkout
    ) -> Double? {
        guard
            let number =
                workout.metadata?[key]
                    as? NSNumber
        else {
            return nil
        }

        let value = number.doubleValue

        guard value.isFinite else {
            return nil
        }

        return max(0, value)
    }

    private func averageMETs(
        for workout: HKWorkout
    ) -> Double? {
        guard let quantity =
            workout.metadata?[
                HKMetadataKeyAverageMETs
            ] as? HKQuantity
        else {
            return nil
        }

        let metUnit = HKUnit(
            from: "kcal/(kg*hr)"
        )

        let value = quantity.doubleValue(
            for: metUnit
        )

        return value.isFinite
            ? max(0, value)
            : nil
    }
}
