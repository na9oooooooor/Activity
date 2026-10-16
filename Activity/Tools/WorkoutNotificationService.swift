import Foundation
import UIKit
import UserNotifications

@MainActor
struct WorkoutNotificationService {
    static let enabledKey =
        "enough.workout-notifications.enabled"

    private let center =
        UNUserNotificationCenter.current()

    func notifyAboutNewWorkouts(
        count: Int
    ) async {
        guard count > 0,
              UserDefaults.standard.bool(
                forKey: Self.enabledKey
              ),
              UIApplication.shared
                .applicationState != .active
        else {
            return
        }

        let settings =
            await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized,
             .provisional,
             .ephemeral:
            break

        case .notDetermined,
             .denied:
            return

        @unknown default:
            return
        }

        let content =
            UNMutableNotificationContent()

        content.title = "Workout added"

        content.body =
            """
            Nice work. Your workout is now part of \
            your rolling 7 days.
            """

        content.sound = .default

        content.threadIdentifier =
            "enough.workout-updates"

        let request =
            UNNotificationRequest(
                identifier:
                    "enough.workout-update.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )

        try? await center.add(request)
    }
}
