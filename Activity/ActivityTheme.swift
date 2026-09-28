import SwiftUI

enum ActivityTheme {
    // MARK: - Colors

    static let background = dynamicColor(
        light: UIColor(
            red: 246 / 255,
            green: 248 / 255,
            blue: 249 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 10 / 255,
            green: 15 / 255,
            blue: 19 / 255,
            alpha: 1
        )
    )

    static let surface = dynamicColor(
        light: UIColor.white,
        dark: UIColor(
            red: 18 / 255,
            green: 26 / 255,
            blue: 32 / 255,
            alpha: 1
        )
    )

    static let elevatedSurface =
        dynamicColor(
            light: UIColor(
                red: 239 / 255,
                green: 243 / 255,
                blue: 245 / 255,
                alpha: 1
            ),
            dark: UIColor(
                red: 28 / 255,
                green: 38 / 255,
                blue: 46 / 255,
                alpha: 1
            )
        )

    static let divider = dynamicColor(
        light: UIColor(
            red: 216 / 255,
            green: 222 / 255,
            blue: 226 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 45 / 255,
            green: 57 / 255,
            blue: 66 / 255,
            alpha: 1
        )
    )

    static let accent = dynamicColor(
        light: UIColor(
            red: 75 / 255,
            green: 124 / 255,
            blue: 164 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 112 / 255,
            green: 169 / 255,
            blue: 211 / 255,
            alpha: 1
        )
    )

    static let caution = dynamicColor(
        light: UIColor(
            red: 185 / 255,
            green: 111 / 255,
            blue: 46 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 224 / 255,
            green: 162 / 255,
            blue: 91 / 255,
            alpha: 1
        )
    )

    static let success = dynamicColor(
        light: UIColor(
            red: 48 / 255,
            green: 126 / 255,
            blue: 99 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 91 / 255,
            green: 180 / 255,
            blue: 143 / 255,
            alpha: 1
        )
    )

    // MARK: - Layout

    static let pagePadding: CGFloat = 20
    static let cardPadding: CGFloat = 18
    static let cardRadius: CGFloat = 18
    static let sectionSpacing: CGFloat = 16

    // MARK: - Typography

    static let heroFont =
        Font.system(
            size: 44,
            weight: .bold,
            design: .default
        )

    static let largeMetricFont =
        Font.system(
            size: 34,
            weight: .bold,
            design: .default
        )

    static let cardTitleFont =
        Font.system(
            size: 12,
            weight: .semibold,
            design: .default
        )

    private static func dynamicColor(
        light: UIColor,
        dark: UIColor
    ) -> Color {
        Color(
            uiColor: UIColor {
                traits in

                traits.userInterfaceStyle
                    == .dark
                    ? dark
                    : light
            }
        )
    }
}

// MARK: - Card style

private struct ActivityCardModifier:
    ViewModifier {

    func body(
        content: Content
    ) -> some View {
        content
            .padding(
                ActivityTheme.cardPadding
            )
            .background(
                ActivityTheme.surface,
                in: RoundedRectangle(
                    cornerRadius:
                        ActivityTheme.cardRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius:
                        ActivityTheme.cardRadius,
                    style: .continuous
                )
                .stroke(
                    ActivityTheme.divider,
                    lineWidth: 0.75
                )
            }
    }
}

extension View {
    func activityCard() -> some View {
        modifier(
            ActivityCardModifier()
        )
    }
}

// MARK: - Section label

struct ActivitySectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(
                ActivityTheme.cardTitleFont
            )
            .tracking(1.4)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(
                .isHeader
            )
    }
}

// MARK: - Progress track

struct ActivityProgressTrack: View {
    let value: Double
    let target: Double

    var tint: Color =
        ActivityTheme.accent

    private var progress: Double {
        guard target > 0 else {
            return 0
        }

        return min(
            1,
            max(0, value / target)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(
                alignment: .leading
            ) {
                Capsule()
                    .fill(
                        ActivityTheme
                            .elevatedSurface
                    )

                Capsule()
                    .fill(tint)
                    .frame(
                        width:
                            geometry.size.width
                            * progress
                    )
            }
        }
        .frame(height: 5)
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            "Progress"
        )
        .accessibilityValue(
            "\(Int((progress * 100).rounded())) percent"
        )
    }
}

// MARK: - Divider

struct ActivityDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                ActivityTheme.divider
            )
            .frame(height: 0.75)
    }
}
