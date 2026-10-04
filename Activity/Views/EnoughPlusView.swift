import SwiftUI
import StoreKit

struct EnoughPlusView: View {
    @Bindable var purchases:
        PurchaseManager

    @Environment(\.dismiss)
    private var dismiss

    @State private var selectedProductID:
        EnoughProductID = .yearly

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    hero

                    benefits

                    plans

                    purchaseButton

                    restoreButton

                    renewalNotice
                }
                .padding(
                    .horizontal,
                    ActivityTheme.pagePadding
                )
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(
                ActivityTheme.background
                    .ignoresSafeArea()
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button {
                        dismiss()
                    } label: {
                        Image(
                            systemName:
                                "xmark.circle.fill"
                        )
                        .font(.title2)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .accessibilityLabel("Close")
                }
            }
            .task {
                if purchases.products.isEmpty {
                    await purchases.prepare()
                }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            Image("pebble_enough")
                .resizable()
                .scaledToFit()
                .frame(height: 118)
                .accessibilityHidden(true)

            Text("Enough Plus")
                .font(
                    .system(
                        size: 36,
                        weight: .bold
                    )
                )

            Text(
                """
                See your longer patterns while keeping \
                the basics simple.
                """
            )
            .font(.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Text(
                "Today and your 7-day progress stay free."
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(
                ActivityTheme.success
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(spacing: 16) {
            benefitRow(
                icon: "calendar",
                title: "Longer trends",
                detail:
                    "See your 30- and 90-day patterns."
            )

            benefitRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Personal comparisons",
                detail:
                    "Understand how activity compares with your usual."
            )

            benefitRow(
                icon: "slider.horizontal.3",
                title: "Your own targets",
                detail:
                    "Adjust activity targets and week settings."
            )
        }
        .activityCard()
    }

    private func benefitRow(
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(
                    ActivityTheme.accent
                )
                .frame(width: 28)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Plans

    private var plans: some View {
        VStack(spacing: 12) {
            planButton(
                id: .yearly,
                title: "Yearly",
                detail:
                    "7-day free trial for eligible subscribers",
                suffix: "per year",
                badge: "Best value"
            )

            planButton(
                id: .monthly,
                title: "Monthly",
                detail: "Flexible monthly access",
                suffix: "per month"
            )

            planButton(
                id: .lifetime,
                title: "Lifetime",
                detail:
                    "One payment · permanent access",
                suffix: "once"
            )
        }
    }

    private func planButton(
        id: EnoughProductID,
        title: String,
        detail: String,
        suffix: String,
        badge: String? = nil
    ) -> some View {
        let isSelected =
            selectedProductID == id

        return Button {
            selectedProductID = id
        } label: {
            HStack(spacing: 14) {
                Image(
                    systemName:
                        isSelected
                        ? "largecircle.fill.circle"
                        : "circle"
                )
                .font(.title3)
                .foregroundStyle(
                    isSelected
                    ? ActivityTheme.accent
                    : Color.secondary
                )

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(
                                .headline
                            )

                        if let badge {
                            Text(badge)
                                .font(
                                    .caption2
                                        .weight(
                                            .bold
                                        )
                                )
                                .foregroundStyle(
                                    ActivityTheme
                                        .success
                                )
                                .padding(
                                    .horizontal,
                                    7
                                )
                                .padding(
                                    .vertical,
                                    3
                                )
                                .background(
                                    ActivityTheme
                                        .success
                                        .opacity(0.12),
                                    in: Capsule()
                                )
                        }
                    }

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .multilineTextAlignment(
                            .leading
                        )
                }

                Spacer(minLength: 8)

                VStack(
                    alignment: .trailing,
                    spacing: 2
                ) {
                    Text(
                        displayPrice(
                            for: id
                        )
                    )
                    .font(
                        .headline
                    )

                    Text(suffix)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                }
            }
            .foregroundStyle(.primary)
            .padding(16)
            .background(
                ActivityTheme.surface,
                in: RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    isSelected
                    ? ActivityTheme.accent
                    : ActivityTheme.divider,
                    lineWidth:
                        isSelected ? 2 : 0.75
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func displayPrice(
        for id: EnoughProductID
    ) -> String {
        if let price =
            purchases.product(
                for: id
            )?.displayPrice {

            return price
        }

        guard AppRuntime.isScreenshotMode
        else {
            return "…"
        }

        switch id {
        case .monthly:
            return "$2.99"

        case .yearly:
            return "$19.99"

        case .lifetime:
            return "$49.99"
        }
    }

    // MARK: - Purchase

    private var purchaseButton: some View {
        Button {
            purchaseSelectedProduct()
        } label: {
            HStack(spacing: 10) {
                if purchases.isPurchasing {
                    ProgressView()
                        .tint(.white)
                }

                Text(purchaseButtonTitle)
                    .font(
                        .headline
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                ActivityTheme.accent,
                in: RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(
            purchases.isPurchasing
            || (
                !AppRuntime.isScreenshotMode
                && purchases.product(
                    for: selectedProductID
                ) == nil
            )
        )
        .opacity(
            AppRuntime.isScreenshotMode
            || purchases.product(
                for: selectedProductID
            ) != nil
            ? 1
            : 0.55
        )
    }

    private var purchaseButtonTitle: String {
        if purchases.isPurchasing {
            return "Completing purchase…"
        }

        switch selectedProductID {
        case .yearly:
            return "Continue with yearly"

        case .monthly:
            return "Continue with monthly"

        case .lifetime:
            return "Unlock lifetime"
        }
    }

    private func purchaseSelectedProduct() {
        guard !AppRuntime.isScreenshotMode
        else {
            return
        }
        guard let product =
            purchases.product(
                for: selectedProductID
            )
        else {
            return
        }

        Task {
            let purchased =
                await purchases.purchase(
                    product
                )

            if purchased {
                dismiss()
            }
        }
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task {
                await purchases
                    .restorePurchases()

                if purchases.hasPlusAccess {
                    dismiss()
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(
            ActivityTheme.accent
        )
    }

    // MARK: - Renewal information

    private var renewalNotice: some View {
        VStack(spacing: 8) {
            Text(renewalText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error =
                purchases.errorMessage {

                Text(error)
                    .font(.caption)
                    .foregroundStyle(
                        ActivityTheme.caution
                    )
                    .multilineTextAlignment(
                        .center
                    )
            }
        }
    }

    private var renewalText: String {
        switch selectedProductID {
        case .yearly:
            return """
            Eligible new subscribers receive 7 days free. \
            The subscription then renews yearly unless canceled.
            """

        case .monthly:
            return """
            The subscription renews monthly unless canceled.
            """

        case .lifetime:
            return """
            Lifetime is a one-time purchase with no renewal.
            """
        }
    }
}
