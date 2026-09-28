import Foundation
import SwiftData
import Observation

enum WorkoutImportState: Equatable {
    case idle
    case importing
    case finished(WorkoutImportResult)
    case failed(String)

    var isImporting: Bool {
        self == .importing
    }

    var message: String? {
        switch self {
        case .idle:
            return nil

        case .importing:
            return "Reading accessible workout history…"

        case .finished(let result):
            if result.totalImportedCount == 0 {
                return """
                No accessible workouts were found. This does not \
                necessarily mean that no workouts exist.
                """
            }

            var parts = [
                "\(result.totalImportedCount) workouts imported"
            ]

            if result.roleReviewCount > 0 {
                parts.append(
                    "\(result.roleReviewCount) need classification"
                )
            }

            if result.intensityReviewCount > 0 {
                parts.append(
                    "\(result.intensityReviewCount) need intensity review"
                )
            }

            return parts.joined(
                separator: " · "
            )

        case .failed(let message):
            return "Import failed: \(message)"
        }
    }
}

@MainActor
@Observable
final class WorkoutImportController {
    private(set) var state:
        WorkoutImportState = .idle

    func importHistory(
        healthKit: HealthKitService,
        modelContext: ModelContext,
        now: Date = .now
    ) async {
        guard !state.isImporting else {
            return
        }

        state = .importing

        do {
            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            let result = try await healthKit.importHealthData(
                using: repository
            )

            state = .finished(result)
        } catch {
            state = .failed(
                error.localizedDescription
            )
        }
    }
}
