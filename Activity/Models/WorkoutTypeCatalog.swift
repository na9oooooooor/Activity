import Foundation
import HealthKit

struct WorkoutTypeDefinition: Identifiable {
    let activityType: HKWorkoutActivityType
    let title: String

    init(
        _ activityType: HKWorkoutActivityType,
        _ title: String
    ) {
        self.activityType = activityType
        self.title = title
    }

    var id: Int {
        Int(activityType.rawValue)
    }

    var activityTypeRawValue: Int {
        Int(activityType.rawValue)
    }

    var defaultRole: WorkoutRole {
        WorkoutClassifier.defaultRole(
            for: activityType
        )
    }
}

enum WorkoutTypeCatalog {
    static let all: [WorkoutTypeDefinition] = [
        .init(.americanFootball, "American Football"),
        .init(.archery, "Archery"),
        .init(.australianFootball, "Australian Football"),
        .init(.badminton, "Badminton"),
        .init(.barre, "Barre"),
        .init(.baseball, "Baseball"),
        .init(.basketball, "Basketball"),
        .init(.bowling, "Bowling"),
        .init(.boxing, "Boxing"),
        .init(.cardioDance, "Cardio Dance"),
        .init(.climbing, "Climbing"),
        .init(.cooldown, "Cooldown"),
        .init(.coreTraining, "Core Training"),
        .init(.cricket, "Cricket"),
        .init(.crossCountrySkiing, "Cross-Country Skiing"),
        .init(.crossTraining, "Cross Training"),
        .init(.curling, "Curling"),
        .init(.cycling, "Cycling"),
        .init(.discSports, "Disc Sports"),
        .init(.downhillSkiing, "Downhill Skiing"),
        .init(.elliptical, "Elliptical"),
        .init(.equestrianSports, "Equestrian Sports"),
        .init(.fencing, "Fencing"),
        .init(.fishing, "Fishing"),
        .init(.fitnessGaming, "Fitness Gaming"),
        .init(.flexibility, "Flexibility"),
        .init(
            .functionalStrengthTraining,
            "Functional Strength Training"
        ),
        .init(.golf, "Golf"),
        .init(.gymnastics, "Gymnastics"),
        .init(.handCycling, "Hand Cycling"),
        .init(.handball, "Handball"),
        .init(.highIntensityIntervalTraining, "HIIT"),
        .init(.hiking, "Hiking"),
        .init(.hockey, "Hockey"),
        .init(.hunting, "Hunting"),
        .init(.jumpRope, "Jump Rope"),
        .init(.kickboxing, "Kickboxing"),
        .init(.lacrosse, "Lacrosse"),
        .init(.martialArts, "Martial Arts"),
        .init(.mindAndBody, "Mind and Body"),
        .init(.mixedCardio, "Mixed Cardio"),
        .init(.other, "Other"),
        .init(.paddleSports, "Paddle Sports"),
        .init(.pickleball, "Pickleball"),
        .init(.pilates, "Pilates"),
        .init(
            .preparationAndRecovery,
            "Preparation and Recovery"
        ),
        .init(.racquetball, "Racquetball"),
        .init(.rowing, "Rowing"),
        .init(.rugby, "Rugby"),
        .init(.running, "Running"),
        .init(.sailing, "Sailing"),
        .init(.skatingSports, "Skating Sports"),
        .init(.snowSports, "Snow Sports"),
        .init(.snowboarding, "Snowboarding"),
        .init(.soccer, "Soccer"),
        .init(.socialDance, "Social Dance"),
        .init(.softball, "Softball"),
        .init(.squash, "Squash"),
        .init(.stairClimbing, "Stair Climber"),
        .init(.stairs, "Stairs"),
        .init(.stepTraining, "Step Training"),
        .init(.surfingSports, "Surfing Sports"),
        .init(.swimBikeRun, "Swim, Bike and Run"),
        .init(.swimming, "Swimming"),
        .init(.tableTennis, "Table Tennis"),
        .init(.taiChi, "Tai Chi"),
        .init(.tennis, "Tennis"),
        .init(.trackAndField, "Track and Field"),
        .init(
            .traditionalStrengthTraining,
            "Traditional Strength Training"
        ),
        .init(.transition, "Multisport Transition"),
        .init(.underwaterDiving, "Underwater Diving"),
        .init(.volleyball, "Volleyball"),
        .init(.walking, "Walking"),
        .init(.waterFitness, "Water Fitness"),
        .init(.waterPolo, "Water Polo"),
        .init(.waterSports, "Water Sports"),
        .init(
            .wheelchairRunPace,
            "Wheelchair Run Pace"
        ),
        .init(
            .wheelchairWalkPace,
            "Wheelchair Walk Pace"
        ),
        .init(.wrestling, "Wrestling"),
        .init(.yoga, "Yoga")
    ]
    .sorted {
        $0.title.localizedCaseInsensitiveCompare(
            $1.title
        ) == .orderedAscending
    }
    
    static func definition(
        forRawValue rawValue: Int
    ) -> WorkoutTypeDefinition? {
        all.first {
            $0.activityTypeRawValue == rawValue
        }
    }

    static var knownRawValues: Set<Int> {
        Set(
            all.map(\.activityTypeRawValue)
        )
    }
}
