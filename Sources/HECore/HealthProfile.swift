import Foundation

public enum BiologicalSex: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case female, male, intersex, preferNotToSay
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .intersex: return "Intersex"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

/// Self-identified race/ethnicity. Optional and self-reported; collected only to
/// add context and support equitable performance work. Never used to make a claim.
public enum Race: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case americanIndianOrAlaskaNative
    case asian
    case blackOrAfricanAmerican
    case hispanicOrLatino
    case middleEasternOrNorthAfrican
    case nativeHawaiianOrPacificIslander
    case white
    case multiracial
    case otherRace
    case preferNotToSay

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .americanIndianOrAlaskaNative: return "American Indian or Alaska Native"
        case .asian: return "Asian"
        case .blackOrAfricanAmerican: return "Black or African American"
        case .hispanicOrLatino: return "Hispanic or Latino"
        case .middleEasternOrNorthAfrican: return "Middle Eastern or North African"
        case .nativeHawaiianOrPacificIslander: return "Native Hawaiian or Pacific Islander"
        case .white: return "White"
        case .multiracial: return "Multiracial"
        case .otherRace: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

/// A prior condition the user can flag. Kept to the cardiovascular-relevant set
/// surfaced as checkboxes; stored only on device and used only to phrase insights
/// more carefully — never to diagnose.
public enum PriorCondition: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case hypertension
    case cardiac

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hypertension: return "Hypertension"
        case .cardiac: return "Cardiac condition"
        }
    }

    public var systemImage: String {
        switch self {
        case .hypertension: return "gauge.with.dots.needle.67percent"
        case .cardiac: return "heart.text.square"
        }
    }
}

public enum UnitSystem: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case metric, imperial
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .metric: return "Metric (kg, cm)"
        case .imperial: return "Imperial (lb, in)"
        }
    }
}

/// The mostly-optional health profile. Kept lean to minimise PII. `name` defaults
/// to a non-identifying participant ID ("PID001"). Everything except the unit
/// preference and the ID is optional.
public struct HealthProfile: Codable, Sendable, Hashable {
    /// Display name / participant ID (defaults to a non-identifying "PID001").
    public var name: String
    public var age: Int?
    /// Stored as biological sex; surfaced in the UI as "Gender".
    public var biologicalSex: BiologicalSex?
    public var heightCM: Double?
    public var weightKG: Double?
    public var race: Race?
    /// Free-form conditions (legacy / "other").
    public var knownConditions: [String]
    /// Structured prior-condition checkboxes (hypertension, cardiac).
    public var priorConditions: Set<PriorCondition>
    public var monkSkinTone: MonkSkinTone?
    public var unitSystem: UnitSystem

    public init(
        name: String = "PID001",
        age: Int? = nil,
        biologicalSex: BiologicalSex? = nil,
        heightCM: Double? = nil,
        weightKG: Double? = nil,
        race: Race? = nil,
        knownConditions: [String] = [],
        priorConditions: Set<PriorCondition> = [],
        monkSkinTone: MonkSkinTone? = nil,
        unitSystem: UnitSystem = .metric
    ) {
        self.name = name.isEmpty ? "PID001" : name
        self.age = age
        self.biologicalSex = biologicalSex
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.race = race
        self.knownConditions = knownConditions
        self.priorConditions = priorConditions
        self.monkSkinTone = monkSkinTone
        self.unitSystem = unitSystem
    }

    public static let empty = HealthProfile()

    // MARK: Derived

    /// Body Mass Index, computed from height + weight when both are present.
    public var bmi: Double? {
        guard let heightCM, let weightKG, heightCM > 0 else { return nil }
        let meters = heightCM / 100.0
        return weightKG / (meters * meters)
    }

    /// BMI formatted to one decimal, e.g. "22.3".
    public var bmiText: String? {
        guard let bmi else { return nil }
        return bmi.formatted(.number.precision(.fractionLength(1)))
    }

    // MARK: Codable (resilient to profiles saved before new fields existed)

    private enum CodingKeys: String, CodingKey {
        case name, age, biologicalSex, heightCM, weightKG, race
        case knownConditions, priorConditions, monkSkinTone, unitSystem
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "PID001"
        age = try c.decodeIfPresent(Int.self, forKey: .age)
        biologicalSex = try c.decodeIfPresent(BiologicalSex.self, forKey: .biologicalSex)
        heightCM = try c.decodeIfPresent(Double.self, forKey: .heightCM)
        weightKG = try c.decodeIfPresent(Double.self, forKey: .weightKG)
        race = try c.decodeIfPresent(Race.self, forKey: .race)
        knownConditions = try c.decodeIfPresent([String].self, forKey: .knownConditions) ?? []
        priorConditions = try c.decodeIfPresent(Set<PriorCondition>.self, forKey: .priorConditions) ?? []
        monkSkinTone = try c.decodeIfPresent(MonkSkinTone.self, forKey: .monkSkinTone)
        unitSystem = try c.decodeIfPresent(UnitSystem.self, forKey: .unitSystem) ?? .metric
    }
}
