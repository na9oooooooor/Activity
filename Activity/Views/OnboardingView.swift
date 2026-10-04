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
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                ScrollView {
                    Group {
                        switch page {
                        case 0:
                            introductionPage

                        case 1:
                            rollingWeekPage

                        case 2:
                            agePage

                        default:
                            appleHealthPage
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .id(page)
                .scrollIndicators(.hidden)

                bottomNavigation
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
            }
        }
        .animation(
            .easeInOut(duration: 0.22),
            value: page
        )
        .interactiveDismissDisabled()
    }

    private var pageIndicator:
        some View {

        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) {
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
            
            Image("pebble_enough")
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: 170
                )
                .accessibilityHidden(true)

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
                Pebble keeps the goal simple: understand what \
                counts, do what is useful, and stop when you \
                have done enough.
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
    
    private var rollingWeekPage:
        some View {

        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            Spacer()

            Image("pebble_movement")
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: 150
                )
                .accessibilityHidden(true)

            Text("Your week moves with you")
                .font(.largeTitle.bold())

            Text(
                """
                Enough always looks at your latest seven \
                activity days. There is no weekly reset and \
                no streak to protect.
                """
            )
            .foregroundStyle(.secondary)

            rollingWeekIllustration

            Text(
                """
                Older activity leaves naturally as a new day \
                begins. Pebble may suggest a small replacement \
                before your totals fall below their targets.
                """
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()
        }
    }
    
    private var rollingWeekIllustration:
        some View {

        VStack(spacing: 12) {
            HStack(
                alignment: .bottom,
                spacing: 8
            ) {
                ForEach(0..<7, id: \.self) {
                    index in

                    RoundedRectangle(
                        cornerRadius: 7,
                        style: .continuous
                    )
                    .fill(
                        index < 2
                            ? Color.secondary
                                .opacity(0.14)
                            : ActivityTheme.accent
                                .opacity(0.32)
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight:
                            index == 6
                                ? 48
                                : 34,
                        maxHeight:
                            index == 6
                                ? 48
                                : 34
                    )
                    .overlay {
                        if index == 6 {
                            RoundedRectangle(
                                cornerRadius: 7,
                                style: .continuous
                            )
                            .stroke(
                                ActivityTheme.accent,
                                lineWidth: 2
                            )
                        }
                    }
                }
            }

            HStack {
                Text("Leaves first")

                Spacer()

                Text("Today")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            ActivityTheme.surface,
            in: RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private var agePage: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            HStack(
                alignment: .top,
                spacing: 16
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    Text("Which age group?")
                        .font(.largeTitle.bold())

                    Text(
                        """
                        We use this only to choose the appropriate \
                        activity guidance. Your exact age is not needed.
                        """
                    )
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }

                Spacer(minLength: 0)

                Image("pebble_enough")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: 92,
                        height: 92
                    )
                    .accessibilityHidden(true)
            }

            VStack(spacing: 12) {
                ForEach(
                    ActivityAgeBand.allCases
                ) { ageBand in
                    ageButton(ageBand)
                }
            }

            if !selectedAgeBand
                .supportsCoreActivityGuidance {

                Label {
                    Text(
                        """
                        This version is designed for adults. \
                        People under 18 need different activity guidance.
                        """
                    )
                } icon: {
                    Image(
                        systemName:
                            "exclamationmark.circle.fill"
                    )
                    .foregroundStyle(.orange)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(16)
                .background(
                    Color.orange.opacity(0.10),
                    in: RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                )
            }
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

    private var appleHealthPage: some View {
        VStack(
            alignment: .leading,
            spacing: 22
        ) {
            ZStack(alignment: .bottomTrailing) {
                Image("pebble_updating")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: 150
                    )
                    .accessibilityHidden(true)

                Image(
                    systemName:
                        "heart.text.square.fill"
                )
                .font(.title2)
                .foregroundStyle(.white)
                .padding(11)
                .background(
                    ActivityTheme.accent,
                    in: Circle()
                )
                .accessibilityHidden(true)
            }

            Text("Connect Apple Health")
                .font(.largeTitle.bold())

            Text(
                """
                Apple Health gives Enough the information it needs \
                to understand what already counts toward your week.
                """
            )
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                permissionRow(
                    icon: "figure.run",
                    text:
                        "Workouts and exercise minutes"
                )

                permissionRow(
                    icon: "shoeprints.fill",
                    text:
                        "Steps for everyday movement context"
                )

                permissionRow(
                    icon: "hand.raised.fill",
                    text:
                        "You control access in Apple Health"
                )
            }
            .padding(18)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                ActivityTheme.surface,
                in: RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
            )

            Label {
                Text(
                    """
                    Enough keeps imported health information on this \
                    device and does not store it in iCloud.
                    """
                )
            } icon: {
                Image(systemName: "lock.fill")
                    .foregroundStyle(
                        ActivityTheme.accent
                    )
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func permissionRow(
        icon: String,
        text: String
    ) -> some View {

        Label(text, systemImage: icon)
            .font(.body.weight(.medium))
    }
    
    private var bottomNavigation:
        some View {

        HStack(spacing: 12) {
            if page > 0 {
                Button {
                    withAnimation {
                        page -= 1
                    }
                } label: {
                    Label(
                        "Back",
                        systemImage:
                            "chevron.left"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            bottomButton
        }
    }
    
    @ViewBuilder
    private var bottomButton:
        some View {

            if page < 3 {
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
                page == 2
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
