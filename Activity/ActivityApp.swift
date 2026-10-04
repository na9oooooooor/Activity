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
                isStoredInMemoryOnly:
                    AppRuntime.isScreenshotMode,
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
            if AppRuntime.isScreenshotMode {
                try ScreenshotDataSeeder.seed(
                    modelContext:
                        modelContainer.mainContext
                )
            }
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
                .preferredColorScheme(
                    AppRuntime.isScreenshotMode
                    ? (
                        AppRuntime.screenshotUsesDarkMode
                        ? .dark
                        : .light
                    )
                    : nil
                )
        }
        .modelContainer(modelContainer)
    }
}
