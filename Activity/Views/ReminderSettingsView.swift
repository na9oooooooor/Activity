import SwiftUI
import UIKit

@MainActor
struct ReminderSettingsView: View {
    let snapshot: ActivitySnapshot?
    let assessment: ActivityAssessment?

    @Environment(\.openURL)
    private var openURL

    @State private var reminders =
        ReminderService()

    @AppStorage(
        "enough.reminders.enabled"
    )
    private var remindersEnabled = false

    @AppStorage(
        "enough.reminders.hour"
    )
    private var reminderHour = 18

    @AppStorage(
        "enough.reminders.minute"
    )
    private var reminderMinute = 0

    @AppStorage(
        "enough.reminders.nextDate"
    )
    private var nextReminderTimestamp:
        Double = 0

    @State private var isUpdating = false

    var body: some View {
        Form {
            Section {
                Toggle(
                    isOn:
                        reminderEnabledBinding
                ) {
                    Label(
                        "Smart reminders",
                        systemImage:
                            "bell.badge.fill"
                    )
                }
                .disabled(isUpdating)

                if isUpdating {
                    HStack(spacing: 12) {
                        ProgressView()

                        Text(
                            "Updating reminder…"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
            } footer: {
                Text(
                    """
                    Enough chooses the day from your rolling \
                    activity. You choose when it may notify you.
                    """
                )
            }

            if remindersEnabled {
                scheduleSection
            }

            if reminders.permissionState
                == .denied {

                Section {
                    Button {
                        openNotificationSettings()
                    } label: {
                        Label(
                            "Open System Settings",
                            systemImage: "gear"
                        )
                    }
                } footer: {
                    Text(
                        """
                        Notifications are disabled for Enough \
                        in system settings.
                        """
                    )
                }
            }

            if let error =
                reminders.errorMessage {

                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section {
                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {
                    reminderRule(
                        icon: "clock",
                        text:
                            """
                            Coverage is about to leave your \
                            rolling week.
                            """
                    )

                    reminderRule(
                        icon:
                            "figure.walk.motion",
                        text:
                            """
                            A real activity gap remains after \
                            a few quieter days.
                            """
                    )

                    reminderRule(
                        icon:
                            "moon.zzz.fill",
                        text:
                            """
                            Recovery and safely covered weeks \
                            stay quiet.
                            """
                    )
                }
            } header: {
                Text("When Enough Reminds You")
            }

            Section {
                Label(
                    "Lock Screen privacy",
                    systemImage: "lock.fill"
                )
            } footer: {
                Text(
                    """
                    Notifications use general wording and never show \
                    your steps, workout totals or detailed health status.
                    """
                )
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(
            .inline
        )
        .task {
            await prepareReminders()
        }
    }

    private var scheduleSection:
        some View {

        Section("Preferred Time") {
            DatePicker(
                "Reminder time",
                selection:
                    reminderTimeBinding,
                displayedComponents:
                    .hourAndMinute
            )
            .disabled(isUpdating)

            if let nextReminderDate {
                LabeledContent {
                    Text(
                        nextReminderDate.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                } label: {
                    Text("Next reminder")
                }
            } else {
                Label(
                    "Nothing needs a reminder right now",
                    systemImage:
                        "checkmark.circle.fill"
                )
                .foregroundStyle(
                    ActivityTheme.success
                )
            }
        }
    }

    private func reminderRule(
        icon: String,
        text: String
    ) -> some View {

        Label {
            Text(text)
                .foregroundStyle(
                    .secondary
                )
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(
                    ActivityTheme.accent
                )
        }
    }

    private var nextReminderDate:
        Date? {

        guard nextReminderTimestamp > 0
        else {
            return nil
        }

        let date =
            Date(
                timeIntervalSince1970:
                    nextReminderTimestamp
            )

        guard date > .now
        else {
            return nil
        }

        return date
    }

    private var reminderEnabledBinding:
        Binding<Bool> {

        Binding(
            get: {
                remindersEnabled
            },
            set: { newValue in
                Task {
                    await changeEnabledState(
                        to: newValue
                    )
                }
            }
        )
    }

    private var reminderTimeBinding:
        Binding<Date> {

        Binding(
            get: {
                var components =
                    DateComponents()

                components.hour =
                    reminderHour

                components.minute =
                    reminderMinute

                return Calendar.current.date(
                    from: components
                ) ?? .now
            },
            set: { newDate in
                let components =
                    Calendar.current
                        .dateComponents(
                            [
                                .hour,
                                .minute
                            ],
                            from: newDate
                        )

                reminderHour =
                    components.hour ?? 18

                reminderMinute =
                    components.minute ?? 0

                Task {
                    await updateReminder()
                }
            }
        )
    }

    private func prepareReminders() async {
        await reminders.refreshPermission()

        guard remindersEnabled else {
            reminders
                .cancelScheduledReminder()

            return
        }

        guard reminders.permissionState
            == .allowed
        else {
            remindersEnabled = false
            return
        }

        await updateReminder()
    }

    private func changeEnabledState(
        to newValue: Bool
    ) async {
        isUpdating = true

        defer {
            isUpdating = false
        }

        guard newValue else {
            remindersEnabled = false

            reminders
                .cancelScheduledReminder()

            return
        }

        await reminders.refreshPermission()

        let permissionGranted: Bool

        switch reminders.permissionState {
        case .allowed:
            permissionGranted = true

        case .notRequested:
            permissionGranted =
                await reminders
                    .requestPermission()

        case .denied,
             .checking:
            permissionGranted = false
        }

        guard permissionGranted else {
            remindersEnabled = false
            return
        }

        remindersEnabled = true

        await updateReminder()
    }

    private func updateReminder() async {
        guard remindersEnabled else {
            reminders
                .cancelScheduledReminder()

            return
        }

        isUpdating = true

        _ = await reminders
            .updateSmartReminder(
                enabled:
                    remindersEnabled,
                preferredHour:
                    reminderHour,
                preferredMinute:
                    reminderMinute,
                snapshot:
                    snapshot,
                assessment:
                    assessment
            )

        isUpdating = false
    }

    private func openNotificationSettings() {
        guard let url = URL(
            string:
                UIApplication
                    .openSettingsURLString
        ) else {
            return
        }

        openURL(url)
    }
}
