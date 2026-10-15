import Foundation

enum ActivityAgeBand:
    String,
    CaseIterable,
    Identifiable,
    Sendable {

    case under18 = "under18"
    case adult18To64 = "18to64"
    case adult65Plus = "65plus"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .under18:
            return "Under 18"

        case .adult18To64:
            return "18–64"

        case .adult65Plus:
            return "65 or older"
        }
    }

    var explanation: String {
        switch self {
        case .under18:
            return """
            Activity guidance for children and teenagers \
            is not supported in this version.
            """

        case .adult18To64:
            return """
            Uses the general adult aerobic and \
            strength guidance.
            """

        case .adult65Plus:
            return """
            Uses the adult aerobic and strength guidance. \
            Balance activity is also recommended but is \
            not measured by the app yet.
            """
        }
    }

    var supportsCoreActivityGuidance: Bool {
        switch self {
        case .under18:
            return false

        case .adult18To64,
             .adult65Plus:
            return true
        }
    }

    var defaultTargets: ActivityTargets? {
        guard supportsCoreActivityGuidance else {
            return nil
        }


        return .generalAdultGuidance
    }

    var showsBalanceGuidance: Bool {
        self == .adult65Plus
    }
}
