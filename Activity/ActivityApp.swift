import SwiftUI
import SwiftData

@main
struct ActivityHealthApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(
            for: [
                StoredWorkout.self,
                DailyActivityRecord.self,
                StoredDailyCheckIn.self,
                AppSettings.self
            ]
        )
    }
}
