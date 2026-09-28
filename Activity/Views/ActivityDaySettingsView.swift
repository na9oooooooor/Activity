import SwiftUI
import SwiftData

struct ActivityDaySettingsView: View {
    let healthKit: HealthKitService
    let dashboard: DashboardController

    @Environment(\.modelContext)
    private var modelContext

    @State private var selectedHour = 0
    @State private var timeZoneIdentifier = ""

    @State private var hasLoaded = false
    @State private var isSaving = false

    @State private var errorMessage:
        String?

    var body: some View {
        Form {
            Section {
                Picker(
                    "Activity day starts",
                    selection: $selectedHour
                ) {
                    ForEach(
                        0...8,
                        id: \.self
                    ) { hour in
                        Text(
                            hourLabel(hour)
                        )
                        .tag(hour)
                    }
                }
            } header: {
                Text("Day boundary")
            } footer: {
                Text(
                    """
                    Activity before this time belongs to \
                    the previous activity day. For example, \
                    with a 4:00 AM start, a workout at \
                    2:00 AM belongs to the previous day.
                    """
                )
            }

            Section("Time zone") {
                LabeledContent(
                    "Analysis time zone",
                    value:
                        timeZoneDisplayName
                )

                Text(timeZoneIdentifier)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(
                    """
                    Calendar calculations automatically \
                    handle daylight-saving changes when \
                    they apply to this time zone.
                    """
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if isSaving {
                Section {
                    HStack {
                        ProgressView()

                        Text(
                            "Rebuilding activity days…"
                        )
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Activity Day")
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbar {
            ToolbarItem(
                placement:
                    .confirmationAction
            ) {
                Button("Save") {
                    Task {
                        await save()
                    }
                }
                .disabled(
                    !hasLoaded || isSaving
                )
            }
        }
        .task {
            loadSettings()
        }
    }

    private var timeZoneDisplayName: String {
        guard
            let timeZone = TimeZone(
                identifier:
                    timeZoneIdentifier
            )
        else {
            return timeZoneIdentifier
        }

        return timeZone.localizedName(
            for: .standard,
            locale: .current
        ) ?? timeZoneIdentifier
    }

    private func hourLabel(
        _ hour: Int
    ) -> String {
        if hour == 0 {
            return "12:00 AM · Midnight"
        }

        return "\(hour):00 AM"
    }

    @MainActor
    private func loadSettings() {
        do {
            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            let settings =
                try repository
                    .loadOrCreateSettings()

            selectedHour =
                settings.activityDayStartHour

            timeZoneIdentifier =
                settings
                    .analysisTimeZoneIdentifier

            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    @MainActor
    private func save() async {
        guard !isSaving else {
            return
        }

        isSaving = true
        defer {
            isSaving = false
        }

        do {
            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            let changed =
                try repository
                    .updateActivityDayStartHour(
                        selectedHour
                    )

            guard changed else {
                errorMessage = nil
                return
            }

            if healthKit.accessState
                == .requestFinished {

                /*
                 Reimports movement data and rebuilds daily
                 records using the new boundary.
                 */
                await dashboard.refresh(
                    healthKit: healthKit,
                    modelContext: modelContext
                )
            } else {
                dashboard.loadStoredData(
                    modelContext: modelContext
                )
            }

            errorMessage =
                dashboard.state.errorMessage
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }
}
