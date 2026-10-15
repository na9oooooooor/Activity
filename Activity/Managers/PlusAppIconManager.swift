import UIKit

@MainActor
enum PlusAppIconManager {
    private static let plusIconName =
        "AppIconPlus"

    static func synchronize(
        isPlusActive: Bool
    ) {
        guard !AppRuntime.isScreenshotMode,
              UIApplication.shared
                .supportsAlternateIcons
        else {
            return
        }

        let requiredIconName =
            isPlusActive
            ? plusIconName
            : nil

        guard UIApplication.shared
            .alternateIconName
                != requiredIconName
        else {
            return
        }

        UIApplication.shared
            .setAlternateIconName(
                requiredIconName
            ) { error in
                #if DEBUG
                if let error {
                    print(
                        "APP ICON ERROR:",
                        error.localizedDescription
                    )
                }
                #endif
            }
    }
}
