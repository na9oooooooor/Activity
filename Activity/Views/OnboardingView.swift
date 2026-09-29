import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext)
    private var modelContext

    @Bindable var healthKit:
        HealthKitService

    let onCompleted: () -> Void

    @State private var page = 0

    @State private var selectedAgeBand:
        ActivityAgeBand = .adult18To64

    @State private var isFinishing = false

    @State private var errorMessage:
        String?

    var body: some View {
        ZStack {
            ActivityTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                pageIndicator

                Group {
                    switch page {
                    case 0:
                        introductionPage

                    case 1:
                        agePage

                    default:
                        appleHealthPage
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

                bottomButton
            }
            .padding(24)
        }
        .interactiveDismissDisabled()
    }

    private var pageIndicator:
        some View {

        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) {
                index in

                Capsule()
                    .fill(
                        index == page
                            ? ActivityTheme.accent
                            : Color.secondary
                                .opacity(0.18)
                    )
                    .frame(
                        width:
                            index == page
                                ? 28
                                : 8,
                        height: 8
                    )
            }

            Spacer()
        }
        .animation(
            .easeInOut(duration: 0.2),
            value: page
        )
    }

    private var introductionPage:
        some View {

        VStack(
            alignment: .leading,
            spacing: 22
        ) {
            Spacer()

            Text("Enough")
                .font(
                    .system(
                        size: 56,
                        weight: .bold,
                        design: .rounded
                    )
                )

            Text(
                """
                Do enough for your health. \
                Then rest.
                """
            )
            .font(.title2.weight(.medium))

            Text(
                """
                Enough uses your recent activity to show \
                whether you are meeting the essentials and \
                what would help today.
                """
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            Spacer()
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private var agePage:
        some View {

        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            Spacer()

            Text("Which age group?")
                .font(.largeTitle.bold())

            Text(
                """
                We only use this to select the right \
                activity guidance. Your exact age is \
                not needed.
                """
            )
            .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(
                    ActivityAgeBand.allCases
                ) { ageBand in
                    ageButton(ageBand)
                }
            }

            if !selectedAgeBand
                .supportsCoreActivityGuidance {

                Text(
                    """
                    This version is designed for adults. \
                    Guidance for people under 18 uses \
                    different activity rules.
                    """
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func ageButton(
        _ ageBand: ActivityAgeBand
    ) -> some View {

        Button {
            selectedAgeBand = ageBand
        } label: {
            HStack(spacing: 16) {
                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    Text(ageBand.title)
                        .font(.headline)

                    Text(ageBand.explanation)
                        .font(.footnote)
                        .foregroundStyle(
                            .secondary
                        )
                        .multilineTextAlignment(
                            .leading
                        )
                }

                Spacer()

                Image(
                    systemName:
                        selectedAgeBand == ageBand
                            ? "checkmark.circle.fill"
                            : "circle"
                )
                .font(.title3)
                .foregroundStyle(
                    selectedAgeBand == ageBand
                        ? ActivityTheme.accent
                        : Color.secondary
                )
            }
            .padding(16)
            .background(
                selectedAgeBand == ageBand
                    ? ActivityTheme.accent
                        .opacity(0.10)
                    : Color.secondary
                        .opacity(0.06),
                in: RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }

    private var appleHealthPage:
        some View {

        VStack(
            alignment: .leading,
            spacing: 22
        ) {
            Spacer()

            Image(
                systemName:
                    "heart.text.square"
            )
            .font(.system(size: 44))
            .foregroundStyle(
                ActivityTheme.accent
            )

            Text("Connect Apple Health")
                .font(.largeTitle.bold())

            Text(
                """
                Enough reads workouts, activity and movement \
                data to calculate your rolling seven days.
                """
            )
            .foregroundStyle(.secondary)

            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                permissionRow(
                    icon: "figure.run",
                    text:
                        "Workouts and exercise"
                )

                permissionRow(
                    icon: "shoeprints.fill",
                    text:
                        "Steps and movement"
                )

                permissionRow(
                    icon: "lock.fill",
                    text:
                        "Your health data stays private"
                )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
    }

    private func permissionRow(
        icon: String,
        text: String
    ) -> some View {

        Label(text, systemImage: icon)
            .font(.body.weight(.medium))
    }

    @ViewBuilder
    private var bottomButton:
        some View {

        if page < 2 {
            Button {
                withAnimation {
                    page += 1
                }
            } label: {
                Text("Continue")
                    .frame(
                        maxWidth: .infinity
                    )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(
                page == 1
                    && !selectedAgeBand
                        .supportsCoreActivityGuidance
            )
        } else {
            Button {
                Task {
                    await finishOnboarding()
                }
            } label: {
                if isFinishing {
                    ProgressView()
                        .frame(
                            maxWidth: .infinity
                        )
                } else {
                    Text(
                        healthKit.accessState
                            == .requestFinished
                            ? "Start"
                            : "Connect and Start"
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isFinishing)
        }
    }

    private func finishOnboarding() async {
        guard selectedAgeBand
            .supportsCoreActivityGuidance
        else {
            return
        }

        isFinishing = true
        errorMessage = nil

        await healthKit.refreshAccessState()

        if healthKit.accessState.canRequest {
            await healthKit.requestReadAccess()
        }

        do {
            let repository =
                ActivityRepository(
                    modelContext:
                        modelContext
                )

            try repository
                .completeOnboarding(
                    ageBand:
                        selectedAgeBand
                )

            onCompleted()
        } catch {
            errorMessage =
                error.localizedDescription
        }

        isFinishing = false
    }
}
