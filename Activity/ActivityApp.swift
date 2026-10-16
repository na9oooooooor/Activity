import SwiftUI
import SwiftData

@main
struct ActivityHealthApp: App {
    @AppStorage(
        AppAppearance.storageKey
    )
    private var appearanceRawValue =
        AppAppearance.system.rawValue
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
    
    private var resolvedColorScheme:
        ColorScheme? {

        if AppRuntime.isScreenshotMode {
            return AppRuntime
                .screenshotUsesDarkMode
                ? .dark
                : .light
        }

        return AppAppearance(
            rawValue: appearanceRawValue
        )?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(
                    resolvedColorScheme
                )
        }
        .modelContainer(modelContainer)
    }
}
