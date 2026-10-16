import SwiftUI

struct MovingStreamView: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 30.0,
                    paused: reduceMotion
                )
            ) { timeline in
                let time =
                    timeline.date
                        .timeIntervalSinceReferenceDate

                ZStack {
                    movingLayer(
                        imageName: "stream_lines_back",
                        size: proxy.size,
                        time: time,
                        duration: 28,
                        opacity: 0.65
                    )

                    movingLayer(
                        imageName: "stream_lines_front",
                        size: proxy.size,
                        time: time,
                        duration: 19,
                        opacity: 0.90
                    )
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func movingLayer(
        imageName: String,
        size: CGSize,
        time: TimeInterval,
        duration: TimeInterval,
        opacity: Double
    ) -> some View {
        let progress =
            reduceMotion
            ? 0
            : time
                .truncatingRemainder(
                    dividingBy: duration
                ) / duration

        let offset =
            -CGFloat(progress) * size.width

        return ZStack(alignment: .leading) {
            streamImage(
                named: imageName,
                size: size
            )
            .offset(x: offset)

            streamImage(
                named: imageName,
                size: size
            )
            .offset(
                x: offset + size.width
            )
        }
        .opacity(opacity)
    }

    private func streamImage(
        named imageName: String,
        size: CGSize
    ) -> some View {
        Image(imageName)
            .resizable()
            .renderingMode(.original)
            .frame(
                width: size.width,
                height: size.height
            )
    }
}
