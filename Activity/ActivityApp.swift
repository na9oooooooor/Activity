import SwiftUI
import SwiftData

@main
struct ActivityHealthApp: App {
    private let modelContainer:
        ModelContainer

    init() {
        let schema = Schema([
            StoredWorkout.self,
            WorkoutRolePreference.self,
            DailyActivityRecord.self,
            StoredDailyCheckIn.self,
            AppSettings.self
        ])

        let configuration =
            ModelConfiguration(
                "ActivityLocal",
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )

        do {
            modelContainer =
                try ModelContainer(
                    for: schema,
                    configurations: [
                        configuration
                    ]
                )
        } catch {
            fatalError(
                """
                Could not create the local activity database: \
                \(error.localizedDescription)
                """
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
