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

/// The minimal, mostly-optional health profile collected at onboarding. Kept lean
/// to minimise PII; everything except unit preference is optional.
public struct HealthProfile: Codable, Sendable, Hashable {
    public var age: Int?
    public var biologicalSex: BiologicalSex?
    public var heightCM: Double?
    public var weightKG: Double?
    public var knownConditions: [String]
    public var monkSkinTone: MonkSkinTone?
    public var unitSystem: UnitSystem

    public init(
        age: Int? = nil,
        biologicalSex: BiologicalSex? = nil,
        heightCM: Double? = nil,
        weightKG: Double? = nil,
        knownConditions: [String] = [],
        monkSkinTone: MonkSkinTone? = nil,
        unitSystem: UnitSystem = .metric
    ) {
        self.age = age
        self.biologicalSex = biologicalSex
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.knownConditions = knownConditions
        self.monkSkinTone = monkSkinTone
        self.unitSystem = unitSystem
    }

    public static let empty = HealthProfile()
}
