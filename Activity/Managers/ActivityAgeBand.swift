import Foundation

enum ActivityAgeBand:
    String,
    CaseIterable,
    Identifiable,
    Sendable {

    case adult18To64 = "18to64"

    var id: String {
        rawValue
    }

    var title: String {
        "General adult guidance"
    }

    var explanation: String {
        """
        Starts with 150 aerobic minutes and \
        2 strength days.
        """
    }

    var supportsCoreActivityGuidance: Bool {
        true
    }

    var defaultTargets: ActivityTargets? {
        .generalAdultGuidance
    }

    var showsBalanceGuidance: Bool {
        false
    }
}
