import SwiftUI
import SwiftData

struct ActivityTargetSettingsView: View {
    @Environment(\.modelContext)
    private var modelContext

    @State private var aerobicMinutes:
        Double = 150

    @State private var strengthDays:
        Int = 2

    @State private var usesCustomTargets =
        false

    @State private var hasLoaded =
        false

    @State private var errorMessage:
        String?

    let onTargetsChanged: () -> Void

    init(
        onTargetsChanged:
            @escaping () -> Void = {}
    ) {
        self.onTargetsChanged =
            onTargetsChanged
    }

    var body: some View {
        Form {
            statusSection
            targetSection
            defaultReferenceSection
            resetSection

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Activity Targets")
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbar {
            ToolbarItem(
                placement:
                    .confirmationAction
            ) {
                Button("Save") {
                    saveTargets()
                }
                .disabled(!hasLoaded)
            }
        }
        .task {
            loadSettings()
        }
    }

    @ViewBuilder
    private var statusSection:
        some View {

        if usesCustomTargets {
            Section {
                Label(
                    "Personal targets active",
                    systemImage:
                        "slider.horizontal.3"
                )
            }
        }
    }

    private var targetSection:
        some View {

        Section {
            Stepper(
                value: $aerobicMinutes,
                in: 30...600,
                step: 10
            ) {
                LabeledContent(
                    "Aerobic",
                    value:
                        "\(Int(aerobicMinutes)) min"
                )
            }

            Stepper(
                value: $strengthDays,
                in: 1...7,
                step: 1
            ) {
                LabeledContent(
                    "Strength",
                    value:
                        "\(strengthDays) days"
                )
            }
        } header: {
            Text("Your targets")
        } footer: {
            Text(
                """
                Targets apply to your rolling seven \
                activity days and the Today recommendation.
                """
            )
        }
    }

    private var defaultReferenceSection:
        some View {

        Section("General adult reference") {
            LabeledContent(
                "Aerobic minimum",
                value: "150 min"
            )

            LabeledContent(
                "Strength minimum",
                value: "2 days"
            )

            Text(
                """
                The general reference remains visible when \
                you use personal targets.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var resetSection:
        some View {

        Section {
            Button(
                "Reset to research defaults"
            ) {
                resetTargets()
            }
            .disabled(
                !usesCustomTargets
                && aerobicMinutes == 150
                && strengthDays == 2
            )
        }
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

            aerobicMinutes =
                settings.aerobicTargetMinutes

            strengthDays =
                settings.strengthTargetDays

            usesCustomTargets =
                settings
                    .usesCustomActivityTargets

            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    @MainActor
    private func saveTargets() {
        do {
            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            try repository.updateActivityTargets(
                aerobicMinutes:
                    aerobicMinutes,
                strengthDays:
                    strengthDays
            )

            usesCustomTargets = true
            errorMessage = nil

            /*
             Reloads DashboardInput and recalculates the
             recommendation without another HealthKit query.
             */
            onTargetsChanged()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    @MainActor
    private func resetTargets() {
        do {
            let repository =
                ActivityRepository(
                    modelContext: modelContext
                )

            try repository
                .resetActivityTargets()

            let defaults =
                ActivityTargets
                    .generalAdultGuidance

            aerobicMinutes =
                defaults
                    .aerobicMinimumMinutes

            strengthDays =
                defaults
                    .strengthMinimumDays

            usesCustomTargets = false
            errorMessage = nil

            onTargetsChanged()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }
}
