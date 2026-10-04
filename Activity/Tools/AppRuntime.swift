import Foundation

enum ScreenshotScenario:
    String {

    case standard
    case recommendation
    case covered
    case recovery
    case trends30
    case workoutDetail
    case onboarding
    case paywall
}

enum AppRuntime {
    private static let arguments =
        ProcessInfo.processInfo.arguments
    
    static let screenshotUsesDarkMode =
        arguments.contains(
            "--screenshot-dark"
        )
    static let isScreenshotMode =
        arguments.contains(
            "--screenshot-mode"
        )

    static let screenshotScenario:
        ScreenshotScenario = {

        guard let argumentIndex =
                arguments.firstIndex(
                    of:
                        "--screenshot-scenario"
                ),
              arguments.indices.contains(
                argumentIndex + 1
              )
        else {
            return .standard
        }

        return ScreenshotScenario(
            rawValue:
                arguments[
                    argumentIndex + 1
                ]
        ) ?? .standard
    }()

    static let screenshotPlusAccess =
        arguments.contains(
            "--screenshot-plus"
        )

    static var now: Date {
        guard isScreenshotMode else {
            return .now
        }

        var calendar =
            Calendar(identifier: .gregorian)

        calendar.timeZone =
            TimeZone(
                identifier: "Asia/Kuwait"
            )!

        return calendar.date(
            from:
                DateComponents(
                    timeZone:
                        calendar.timeZone,
                    year: 2026,
                    month: 9,
                    day: 28,
                    hour: 10,
                    minute: 42
                )
        )!
    }
}
