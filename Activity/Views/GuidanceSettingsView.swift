import SwiftUI
import SwiftData

struct GuidanceSettingsView: View {
    @Environment(\.modelContext)
    private var modelContext

    let onChange: () -> Void

    @State private var selectedAgeBand:
        ActivityAgeBand = .adult18To64

    @State private var usesCustomTargets =
        false

    @State private var errorMessage:
        String?

    private let supportedAgeBands:
        [ActivityAgeBand] = [
            .adult18To64,
            .adult65Plus
        ]

    var body: some View {
        Form {
            Section {
                Picker(
                    "Age group",
                    selection:
                        $selectedAgeBand
                ) {
                    ForEach(
                        supportedAgeBands
                    ) { ageBand in
                        Text(ageBand.title)
                            .tag(ageBand)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Age group")
            } footer: {
                Text(
                    """
                    Your exact age is not stored. The app only \
                    saves the selected guidance group.
                    """
                )
            }

            Section("Core guidance") {
                if let targets =
                    selectedAgeBand
                        .defaultTargets {

                    LabeledContent {
                        Text("\(formatted(targets.aerobicMinimumMinutes)) min")
                    } label: {
                        Text("Aerobic")
                    }

                    LabeledContent {
                        Text("\(targets.strengthMinimumDays) days")
                    } label: {
                        Text("Strength")
                    }
                }

                if usesCustomTargets {
                    Label(
                        """
                        Your custom Activity Targets remain active.
                        """,
                        systemImage:
                            "slider.horizontal.3"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if selectedAgeBand
                .showsBalanceGuidance {

                Section("Additional guidance") {
                    Label {
                        Text(
                            """
                            Include activity that emphasizes \
                            functional balance and strength on \
                            three or more days each week.
                            """
                        )
                    } icon: {
                        Image(
                            systemName:
                                "figure.mind.and.body"
                        )
                    }

                    Text(
                        """
                        Balance activity is currently explained \
                        here but is not included in the Activity \
                        Health result because HealthKit does not \
                        provide a reliable universal balance category.
                        """
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Guidance")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadSettings()
        }
        .onChange(
            of: selectedAgeBand
        ) { _, newValue in
            saveAgeBand(newValue)
        }
    }

    private func loadSettings() {
        do {
            let repository =
                ActivityRepository(
                    modelContext:
                        modelContext
                )

            let settings =
                try repository
                    .loadOrCreateSettings()

            selectedAgeBand =
                settings.ageBand

            usesCustomTargets =
                settings
                    .usesCustomActivityTargets
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    private func saveAgeBand(
        _ ageBand: ActivityAgeBand
    ) {
        do {
            let repository =
                ActivityRepository(
                    modelContext:
                        modelContext
                )

            try repository.updateAgeBand(
                ageBand
            )

            let settings =
                try repository
                    .loadOrCreateSettings()

            usesCustomTargets =
                settings
                    .usesCustomActivityTargets

            errorMessage = nil
            onChange()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    private func formatted(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(0)
            )
        )
    }
}
