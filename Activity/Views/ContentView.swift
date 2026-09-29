import SwiftUI
import SwiftData


private enum AppTab: Hashable {
    case today
    case trends
}


struct ContentView: View {
    @State private var healthKit = HealthKitService()
    @State private var dashboard = DashboardController()
    @State private var showingExplanation = false
    @State private var selectedTab: AppTab = .today
    @State private var showingSettings = false
    @Query private var savedSettings:
        [AppSettings]

    @Environment(\.modelContext)
    private var modelContext
    
    private var onboardingPresented:
        Binding<Bool> {

        Binding(
            get: {
                savedSettings.first?
                    .hasCompletedOnboarding
                    != true
            },
            set: { _ in }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            todayTab
                .tabItem {
                    Label(
                        "Today",
                        systemImage: "circle"
                    )
                }
                .tag(AppTab.today)
            
            NavigationStack {
                TrendsView(
                    healthKit: healthKit
                ) {
                    dashboard.loadStoredData(
                        modelContext: modelContext
                    )
                }                    .toolbar {
                        ToolbarItem(
                            placement:
                                    .topBarTrailing
                        ) {
                            settingsButton
                        }
                    }
            }
            .tabItem {
                Label(
                    "Trends",
                    systemImage:
                        "chart.bar.xaxis"
                )
            }
            .tag(AppTab.trends)
        }
        .tint(ActivityTheme.accent)
        .task {
            await prepareDashboard()
        }
        .sheet(
            isPresented:
                $showingExplanation
        ) {
            if let input = dashboard.input,
               let assessment =
                dashboard.assessment {
                
                ActivityExplanationView(
                    input: input,
                    assessment: assessment,
                    recommendationReason:
                        reasonText(
                            for: assessment
                        )
                )
                .presentationDetents([
                    .medium,
                    .large
                ])
            }
        }
        .fullScreenCover(
            isPresented:
                onboardingPresented
        ) {
            OnboardingView(
                healthKit: healthKit
            ) {
                Task {
                    await prepareDashboard()
                }
            }
        }
        .sheet(
            isPresented:
                $showingSettings
        ) {
            settingsSheet
        }
    }

    // MARK: - Apple Health

    @ViewBuilder
    private var appleHealthSection:
        some View {

        Section("Apple Health") {
            switch healthKit.accessState {
            case .checking:
                ProgressView(
                    "Checking Apple Health…"
                )

            case .unavailable:
                Label(
                    healthKit.accessState.message,
                    systemImage:
                        "heart.slash"
                )
                .foregroundStyle(.secondary)

            case .readyToRequest,
                 .failed(_):
                Text(
                    healthKit.accessState.message
                )
                .foregroundStyle(.secondary)

                Button {
                    Task {
                        await requestAccess()
                    }
                } label: {
                    Text(
                        "Connect Apple Health"
                    )
                }
                .disabled(
                    !healthKit
                        .accessState
                        .canRequest
                )

            case .requesting:
                HStack {
                    ProgressView()

                    Text(
                        "Waiting for permission…"
                    )
                }

            case .requestFinished:
                Label(
                    "Apple Health request completed",
                    systemImage:
                        "checkmark.circle"
                )
                .foregroundStyle(.secondary)

                Button {
                    Task {
                        await refreshDashboard()
                    }
                } label: {
                    Label(
                        "Refresh Activity",
                        systemImage:
                            "arrow.clockwise"
                    )
                }
                .disabled(
                    dashboard.state.isLoading
                )
            }
        }
    }

    // MARK: - Loading and errors

    @ViewBuilder
    private var dashboardStateSection:
        some View {

        if dashboard.state.isLoading {
            Section {
                HStack {
                    ProgressView()

                    Text(
                        "Updating activity…"
                    )
                }
            }
        }

        if let error =
            dashboard.state.errorMessage {

            Section {
                Text(error)
                    .foregroundStyle(.red)

                Button("Try Again") {
                    Task {
                        await refreshDashboard()
                    }
                }
            }
        }
    }

    // MARK: - Activity Health

    private func activityHealthSection(
        input: DashboardInput,
        assessment: ActivityAssessment
    ) -> some View {
        Section{
            Text(assessment.status.rawValue)
                .font(.title2)
                .fontWeight(.semibold)

            Text(
                reasonText(
                    for: assessment
                )
            )
            .foregroundStyle(.secondary)
            
            if input.usesCustomActivityTargets {
                Label(
                    "Personal targets active",
                    systemImage: "slider.horizontal.3"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            LabeledContent(
                "Aerobic",
                value:
                    """
                    \(Int(
                        input.snapshot
                            .moderateEquivalentMinutes
                            .rounded()
                    )) / \(Int(
                        input.targets
                            .aerobicMinimumMinutes
                            .rounded()
                    )) min
                    """
            )

            LabeledContent(
                "Strength",
                value:
                    """
                    \(input.snapshot.strengthDays) / \
                    \(input.targets.strengthMinimumDays) days
                    """
            )
        } header: {
            HStack {
                Text(
                    input.usesCustomActivityTargets
                        ? "Your Activity Targets"
                        : "Activity Health"
                )
                Spacer()

                Button {
                    showingExplanation = true
                } label: {
                    Image(
                        systemName: "info.circle"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "How Activity Health is calculated"
                )
            }
        }
    }

    // MARK: - Today

    private func todaySection(
        assessment: ActivityAssessment
    ) -> some View {
        Section("Today") {
            Text(
                assessment
                    .recommendation
                    .outcome?
                    .rawValue
                ?? "Recommendation unavailable"
            )
            .font(.headline)

            Text(
                reasonText(
                    for: assessment
                )
            )
            .foregroundStyle(.secondary)

            Picker(
                "Today’s context",
                selection: Binding(
                    get: {
                        dashboard.todayContext
                    },
                    set: { selection in
                        dashboard
                            .updateTodayContext(
                                selection,
                                modelContext:
                                    modelContext
                            )
                    }
                )
            ) {
                ForEach(
                    TodayContextSelection
                        .allCases
                ) { selection in
                    Text(selection.title)
                        .tag(selection)
                }
            }
            .pickerStyle(.segmented)

  
        }
    }

    // MARK: - Personal baseline

    private func personalBaselineSection(
        comparison:
            PersonalBaselineComparison
    ) -> some View {
        Section("Compared with you") {
            comparisonRow(
                title: "Aerobic",
                comparison:
                    comparison.aerobic,
                unit: "min/week",
                decimalPlaces: 0
            )

            comparisonRow(
                title: "Steps",
                comparison:
                    comparison.steps,
                unit: "steps/day",
                decimalPlaces: 0
            )

            comparisonRow(
                title: "Stand Hours",
                comparison:
                    comparison.standHours,
                unit: "hours/day",
                decimalPlaces: 1
            )

            Text(
                """
                Last 7 completed days compared with your \
                preceding 90 days.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func comparisonRow(
        title: String,
        comparison:
            PersonalMetricComparison?,
        unit: String,
        decimalPlaces: Int
    ) -> some View {
        if let comparison {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                HStack {
                    Text(title)

                    Spacer()

                    Text(
                        changeText(
                            comparison
                                .percentChange
                        )
                    )
                    .fontWeight(.semibold)
                }

                Text(
                    """
                    \(formatValue(
                        comparison.currentValue,
                        decimalPlaces:
                            decimalPlaces
                    )) vs usual \(formatValue(
                        comparison.usualValue,
                        decimalPlaces:
                            decimalPlaces
                    )) \(unit)
                    """
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        } else {
            LabeledContent(
                title,
                value:
                    "Not enough history"
            )
        }
    }

    // MARK: - Movement

    private func movementSection(
        input: DashboardInput
    ) -> some View {
        Section("Movement today") {
            if let steps =
                input.snapshot.recordedStepsToday {

                LabeledContent(
                    "Steps",
                    value:
                        steps.formatted()
                )
            } else {
                LabeledContent(
                    "Steps",
                    value: "No accessible data"
                )
            }
        }
    }

    // MARK: - Navigation

        private var settingsButton:
            some View {

            Button {
                showingSettings = true
            } label: {
                Image(
                    systemName:
                        "line.3.horizontal"
                )
            }
            .accessibilityLabel("Settings")
        }
        
    private var todayTab:
        some View {

        NavigationStack {
            Group {
                if let input = dashboard.input,
                   let assessment =
                    dashboard.assessment {

                    TodayDashboardView(
                        input: input,
                        assessment: assessment,
                        todayContext:
                            dashboard.todayContext,
                        recommendationReason:
                            reasonText(
                                for: assessment
                            ),
                        onContextChange: {
                            selection in

                            dashboard
                                .updateTodayContext(
                                    selection,
                                    modelContext:
                                        modelContext
                                )
                        },
                        onShowExplanation: {
                            showingExplanation =
                                true
                        },
                        onRefresh: {
                            await refreshDashboard()
                        }
                    )
                } else {
                    Form {
                        appleHealthSection
                        dashboardStateSection
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItemGroup(
                    placement: .topBarTrailing
                ) {
                    NavigationLink {
                        ManualWorkoutEntryView(
                            healthKit: healthKit
                        ) {
                            dashboard.loadStoredData(
                                modelContext:
                                    modelContext
                            )
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(
                        "Add workout"
                    )

                    settingsButton
                }
            }
        }
    }
    
        private var settingsSheet:
            some View {

        NavigationStack {
            Form {
                appleHealthSection

                Section("Activity") {
                    NavigationLink {
                        ActivityTargetSettingsView {
                            dashboard
                                .loadStoredData(
                                    modelContext:
                                        modelContext
                                )
                        }
                    } label: {
                        Label(
                            "Activity Targets",
                            systemImage:
                                "target"
                        )
                    }

                    NavigationLink {
                        ActivityDaySettingsView(
                            healthKit: healthKit,
                            dashboard: dashboard
                        )
                    } label: {
                        Label(
                            "Activity Day",
                            systemImage:
                                "clock"
                        )
                    }
                }
                NavigationLink {
                    ManualWorkoutEntryView(
                        healthKit: healthKit
                    ) {
                        dashboard.loadStoredData(
                            modelContext: modelContext
                        )
                    }
                } label: {
                    Label(
                        "Add Workout",
                        systemImage: "plus.circle"
                    )
                }
                
                Section("Workouts") {
                    NavigationLink {
                        WorkoutClassificationSettingsView {
                            dashboard.loadStoredData(
                                modelContext: modelContext
                            )
                        }
                    } label: {
                        Label(
                            "Workout Classifications",
                            systemImage:
                                "list.bullet.rectangle"
                        )
                    }

                }

                Section("About") {
                    if let input =
                        dashboard.input,
                       let assessment =
                        dashboard.assessment {

                        Button {
                            showingExplanation =
                                true
                        } label: {
                            Label(
                                "How Activity Health Works",
                                systemImage:
                                    "info.circle"
                            )
                        }
                    }

                    LabeledContent(
                        "Guidance version",
                        value: "1.0"
                    )
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Done") {
                        showingSettings = false
                    }
                }
            }
        }
    }
    


    // MARK: - Actions

    private func prepareDashboard() async {
        await healthKit.refreshAccessState()

        if healthKit.accessState
            == .requestFinished {

            await refreshDashboard()
        } else {
            /*
             Cached data can still be displayed while a
             new HealthKit request is waiting.
             */
            dashboard.loadStoredData(
                modelContext: modelContext
            )
        }
    }

    private func requestAccess() async {
        await healthKit.requestReadAccess()

        guard healthKit.accessState
            == .requestFinished
        else {
            return
        }

        await refreshDashboard()
    }

    private func refreshDashboard() async {
        guard healthKit.accessState
            == .requestFinished
        else {
            dashboard.loadStoredData(
                modelContext: modelContext
            )

            return
        }

        await dashboard.refresh(
            healthKit: healthKit,
            modelContext: modelContext
        )
    }

    // MARK: - Formatting

    private func changeText(
        _ percentage: Double?
    ) -> String {
        guard let percentage else {
            return "No usual value"
        }

        if abs(percentage) < 0.5 {
            return "About usual"
        }

        let arrow =
            percentage > 0 ? "↑" : "↓"

        let value =
            abs(percentage).formatted(
                .number.precision(
                    .fractionLength(0)
                )
            )

        return "\(arrow) \(value)%"
    }

    private func formatValue(
        _ value: Double,
        decimalPlaces: Int
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(
                    decimalPlaces
                )
            )
        )
    }

    private func reasonText(
        for assessment: ActivityAssessment
    ) -> String {
        switch assessment
            .recommendation
            .reason {

        case .targetsMet:
            return """
            Your recorded aerobic and strength targets \
            are met.
            """

        case .aerobicGap:
            return """
            A substantial aerobic gap remains in the \
            current seven-day window.
            """

        case .strengthGap:
            return """
            Your recorded strength days remain below your \
            current target.
            """

        case .smallRemainingGap:
            return """
            A small activity gap remains. A hard workout \
            is unnecessary.
            """

        case .recentStrengthSession:
            return """
            Strength is below target, but a recent \
            session is recorded.
            """

        case .aerobicSessionAlreadyCompleted:
            return """
            An aerobic session has already been completed \
            today.
            """

        case .lowMovement:
            return """
            Your targets are met, but today has involved \
            little movement.
            """

        case .recoveryChoice:
            return """
            You selected a recovery day. Light movement \
            is enough if it feels appropriate.
            """

        case .unavailableRecords:
            return """
            No accessible activity records are available.
            """

        case .staleRecords:
            return """
            Your activity records need to be refreshed.
            """

        case .importing:
            return """
            Activity history is still importing.
            """

        case .outsideGuidedScope:
            return """
            The general V1 guidance does not fit this \
            profile.
            """
        }
    }
}

#Preview {
    ContentView()
}
