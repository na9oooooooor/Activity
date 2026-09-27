import SwiftUI

struct ContentView: View {
    @State private var selectedScenario = DemoScenario.targetsMet
    @State private var wantsRecovery = false
    @State private var reportsLowMovement = false
    @State private var healthKit =
        HealthKitService()
    
    private var assessment: ActivityAssessment {
        ActivityRules.assess(
            snapshot: selectedScenario.snapshot,
            checkIn: TodayCheckIn(
                wantsRecovery: wantsRecovery,
                reportsLowMovement: reportsLowMovement
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Apple Health") {
                    Text(healthKit.accessState.message)
                        .foregroundStyle(.secondary)

                    Button {
                        Task {
                            await healthKit.requestReadAccess()
                        }
                    } label: {
                        if healthKit.accessState.isRequesting {
                            HStack {
                                ProgressView()
                                Text("Requesting access…")
                            }
                        } else {
                            Text("Request Apple Health access")
                        }
                    }
                    .disabled(
                        !healthKit.accessState.canRequest
                    )
                }
                
                Section("Test scenario") {
                    Picker("Scenario", selection: $selectedScenario) {
                        ForEach(DemoScenario.allCases) { scenario in
                            Text(scenario.title).tag(scenario)
                        }
                    }

                    Toggle(
                        "Choosing a recovery day",
                        isOn: $wantsRecovery
                    )

                    Toggle(
                        "Little movement today",
                        isOn: $reportsLowMovement
                    )
                }

                Section("Activity Health") {
                    Text(assessment.status.rawValue)

                    LabeledContent(
                        "Aerobic",
                        value:
                            "\(Int(selectedScenario.snapshot.moderateEquivalentMinutes)) / 150 min"
                    )

                    LabeledContent(
                        "Strength",
                        value:
                            "\(selectedScenario.snapshot.strengthDays) / 2 days"
                    )
                }

                Section("Today") {
                    Text(
                        assessment.recommendation.outcome?.rawValue
                        ?? "Recommendation unavailable"
                    )
                    .font(.headline)

                    Text(reasonText)
                        .foregroundStyle(.secondary)
                }
                
                Section("Settings") {
                    NavigationLink {
                        WorkoutClassificationSettingsView()
                    } label: {
                        Text("Workout Classifications")
                    }
                }
            }
            .navigationTitle("Engine Test")
        }
    }

    private var reasonText: String {
        switch assessment.recommendation.reason {
        case .targetsMet:
            "The recorded aerobic and strength targets are met."

        case .aerobicGap:
            "A substantial aerobic gap remains in the current window."

        case .strengthGap:
            "Fewer than two strength-training days are recorded."
            
        case .smallRemainingGap:
            "A small activity gap remains. A hard workout is unnecessary."

        case .recentStrengthSession:
            "Strength is still below target, but a recent session is recorded."

        case .aerobicSessionAlreadyCompleted:
            "An aerobic session has already been completed today."

        case .lowMovement:
            "The targets are met, but today has involved little movement."

        case .recoveryChoice:
            "A recovery day was selected."

        case .incompleteRecords:
            "Some records need review before making a suggestion."

        case .unavailableRecords:
            "No accessible activity records are available."

        case .staleRecords:
            "The records must be refreshed."

        case .importing:
            "Activity history is still importing."

        case .outsideGuidedScope:
            "The general V1 guidance does not fit this profile."
        }
    }
}

private enum DemoScenario: String, CaseIterable, Identifiable {
    case targetsMet
    case missingStrength
    case smallAerobicGap
    case largeAerobicGap
    case incompleteRecords
    case noRecords

    var id: String { rawValue }

    var title: String {
        switch self {
        case .targetsMet: "Targets met"
        case .missingStrength: "Missing strength"
        case .smallAerobicGap: "Small aerobic gap"
        case .largeAerobicGap: "Large aerobic gap"
        case .incompleteRecords: "Needs review"
        case .noRecords: "No accessible records"
        }
    }

    var snapshot: ActivitySnapshot {
        switch self {
        case .targetsMet:
            ActivitySnapshot(
                moderateMinutes: 136,
                vigorousMinutes: 20,
                strengthDays: 2,
                aerobicCoverage: .confirmed,
                strengthCoverage: .confirmed,
                recordedStepsToday: 7_620
            )

        case .missingStrength:
            ActivitySnapshot(
                moderateMinutes: 136,
                vigorousMinutes: 20,
                strengthDays: 2,
                aerobicCoverage: .confirmed,
                strengthCoverage: .confirmed,
                recordedStepsToday: 7_620
            )

        case .smallAerobicGap:
            ActivitySnapshot(
                moderateMinutes: 136,
                vigorousMinutes: 20,
                strengthDays: 2,
                aerobicCoverage: .confirmed,
                strengthCoverage: .confirmed,
                recordedStepsToday: 7_620
            )

        case .largeAerobicGap:
            ActivitySnapshot(
                moderateMinutes: 136,
                vigorousMinutes: 20,
                strengthDays: 2,
                aerobicCoverage: .confirmed,
                strengthCoverage: .confirmed,
                recordedStepsToday: 7_620
            )

        case .incompleteRecords:
            ActivitySnapshot(
                moderateMinutes: 136,
                vigorousMinutes: 20,
                strengthDays: 2,
                aerobicCoverage: .confirmed,
                strengthCoverage: .confirmed,
                recordedStepsToday: 7_620
            )

        case .noRecords:
            ActivitySnapshot(
                recordState: .unavailable,
                isInsideGuidedScope: true
            )
        }
    }
}

#Preview {
    ContentView()
}
