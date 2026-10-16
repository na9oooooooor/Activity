import SwiftUI

struct RiverStatusScene: View {
    let aerobicProgress: Double
    let strengthProgress: Double
    let recommendationReason: DecisionReason
    let recordState: RecordState

    @Environment(\.layoutDirection)
    private var layoutDirection

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @Environment(\.colorScheme)
    private var colorScheme

    private let stonePositions: [CGFloat] = [
        0.14,
        0.28,
        0.42,
        0.56,
        0.70
    ]

    private var waterColor: Color {
        colorScheme == .dark
            ? Color(
                red: 0.035,
                green: 0.16,
                blue: 0.22
            )
            : Color(
                red: 0.74,
                green: 0.87,
                blue: 0.91
            )
    }

    private var normalizedAerobicProgress: Double {
        min(max(aerobicProgress, 0), 1)
    }

    private var normalizedStrengthProgress: Double {
        min(max(strengthProgress, 0), 1)
    }

    private var targetsCovered: Bool {
        normalizedAerobicProgress >= 1 &&
        normalizedStrengthProgress >= 1
    }

 

    private var currentStoneIndex: Int {
        guard recordState == .current else {
            return 0
        }

        let index = Int(
            floor(
                normalizedAerobicProgress *
                Double(stonePositions.count)
            )
        )

        return min(
            max(index, 0),
            stonePositions.count - 1
        )
    }

    private var pebbleAssetName: String {
        guard recordState == .current else {
            return "pebble_stream_neutral"
        }

        if normalizedStrengthProgress < 1 {
            return "pebble_stream_strength"
        }

        return "pebble_stream_walking"
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            let waterHeight =
                height * 0.48

            let waterY =
                height * 0.61

            let shoreWidth =
                width * 0.30

            let shoreHeight =
                waterHeight * 1.35

            ZStack {
                skyLayer(
                    width: width,
                    height: height
                )

                waterLayer(
                    width: width,
                    height: waterHeight
                )
                .position(
                    x: width / 2,
                    y: waterY
                )

                Image("river_stones")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(
                        width: width * 0.70
                    )
                    .position(
                        x: width * 0.42,
                        y: waterY + 8
                    )

                shoreImage(
                    named: targetsCovered
                        ? "stream_shore_right_complete"
                        : "stream_shore_right",
                    width: shoreWidth,
                    height: shoreHeight
                )
                .position(
                    x: width - shoreWidth / 2,
                    y: waterY
                )

                if !targetsCovered {
                    Image(pebbleAssetName)
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: width * 0.19)
                        .position(
                            x:
                                width *
                                stonePositions[currentStoneIndex],
                            y: height * 0.47
                        )
                        .transition(.opacity)
                }
            }
            .scaleEffect(
                x:
                    layoutDirection == .rightToLeft
                    ? -1
                    : 1,
                y: 1
            )
            .clipped()
        }
        .frame(height: 190)
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 0.7),
            value: currentStoneIndex
        )
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 0.7),
            value: targetsCovered
        )
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            accessibilityDescription
        )
    }

    private func skyLayer(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        ZStack {
            if colorScheme == .dark {
                Image("stars_field_dark")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(
                        width: width * 0.78
                    )
                    .opacity(0.55)
                    .position(
                        x: width * 0.45,
                        y: height * 0.20
                    )

                Image("moon_dark")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(
                        width: width * 0.11
                    )
                    .position(
                        x: width * 0.66,
                        y: 42
                    )
            }

            Image("cloud_wide")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(
                    width: width * 0.25
                )
                .opacity(0.65)
                .position(
                    x: width * 0.18,
                    y: height * 0.24
                )

            Image("cloud_medium")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(
                    width: width * 0.18
                )
                .opacity(0.55)
                .position(
                    x: width * 0.52,
                    y: height * 0.14
                )

            Image("cloud_small")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(
                    width: width * 0.12
                )
                .opacity(0.50)
                .position(
                    x: width * 0.72,
                    y: height * 0.29
                )
        }
    }

    private func waterLayer(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(waterColor)

            MovingStreamView()
                .padding(.vertical, 8)
        }
        .frame(
            width: width,
            height: height
        )
        .mask {
            LinearGradient(
                stops: [
                    .init(
                        color: .clear,
                        location: 0
                    ),
                    .init(
                        color: .black,
                        location: 0.12
                    ),
                    .init(
                        color: .black,
                        location: 0.88
                    ),
                    .init(
                        color: .clear,
                        location: 1
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func shoreImage(
        named imageName: String,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        Image(imageName)
            .resizable()
            .renderingMode(.original)
            .scaledToFill()
            .frame(
                width: width,
                height: height
            )
            .clipped()
    }

    private var accessibilityDescription: String {
        if targetsCovered {
            return """
            Both seven-day targets are covered. \
            Pebble is resting.
            """
        }

        return """
        Pebble is crossing the stream as you progress \
        toward your seven-day targets.
        """
    }
}

