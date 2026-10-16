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


@MainActor
@Observable
final class DashboardController {
    private(set) var state:
        DashboardLoadState = .idle

    private(set) var input:
        DashboardInput?

    private(set) var assessment:
        ActivityAssessment?


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
    }
}
