import Foundation
import Observation
import SwiftData

enum DashboardLoadState: Equatable {
    case idle
    case loading
    case ready
    case failed(String)

    var isLoading: Bool {
        self == .loading
    }

    var errorMessage: String? {
        guard case .failed(let message) = self
        else {
            return nil
        }

        return message
    }
}

enum TodayContextSelection:
    String,
    CaseIterable,
    Identifiable {

    case normal
    case recovery
    case lowMovement

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .normal:
            return "Normal day"

        case .recovery:
            return "Recovery"

        case .lowMovement:
            return "Low movement"
        }
    }
}

@MainActor
@Observable
final class DashboardController {
    private(set) var state:
        DashboardLoadState = .idle

    private(set) var input:
        DashboardInput?

    private(set) var assessment:
        ActivityAssessment?

    private(set) var todayContext:
        TodayContextSelection = .normal

    /*
     Imports the latest HealthKit data and then rebuilds
     the dashboard from the local SwiftData records.
     */
    func refresh(
        healthKit: HealthKitService,
        modelContext: ModelContext,
        now: Date = .now
    ) async {
        state = .loading

        do {
            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            _ = try await healthKit
                .importHealthData(
                    using: repository,
                    now: now
                )

            let loadedInput =
                try repository.loadDashboardInput(
                    now: now
                )

            apply(loadedInput)
            state = .ready
        } catch {
            state = .failed(
                error.localizedDescription
            )
        }
    }

    /*
     Loads data already stored by the app without running
     another HealthKit query.
     */
    func loadStoredData(
        modelContext: ModelContext,
        now: Date = .now
    ) {
        do {
            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            let loadedInput =
                try repository.loadDashboardInput(
                    now: now
                )

            apply(loadedInput)
            state = .ready
        } catch {
            state = .failed(
                error.localizedDescription
            )
        }
    }

    func updateTodayContext(
        _ selection: TodayContextSelection,
        modelContext: ModelContext,
        now: Date = .now
    ) {
        let wantsRecovery =
            selection == .recovery

        let reportsLowMovement =
            selection == .lowMovement

        do {
            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            try repository.saveTodayCheckIn(
                wantsRecovery:
                    wantsRecovery,
                reportsLowMovement:
                    reportsLowMovement,
                now: now
            )

            /*
             Reloading is inexpensive because it reads the
             local daily summaries. It does not query
             HealthKit again.
             */
            let loadedInput =
                try repository.loadDashboardInput(
                    now: now
                )

            apply(loadedInput)
            state = .ready
        } catch {
            state = .failed(
                error.localizedDescription
            )
        }
    }

    private func apply(
        _ loadedInput: DashboardInput
    ) {
        input = loadedInput

        let configuration =
            ActivityRuleConfiguration.using(
                loadedInput.targets
            )

        assessment =
            ActivityRules.assess(
                snapshot:
                    loadedInput.snapshot,
                checkIn:
                    loadedInput.checkIn,
                configuration:
                    configuration
            )

        if loadedInput.checkIn.wantsRecovery {
            todayContext = .recovery
        } else if loadedInput
            .checkIn
            .reportsLowMovement {
            todayContext = .lowMovement
        } else {
            todayContext = .normal
        }
    }
}
