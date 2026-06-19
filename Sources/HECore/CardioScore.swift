import Foundation

/// A glanceable 0–100 daily cardio wellness score shown as the Home ring. It is a
/// soft, non-diagnostic roll-up of the day's readings — explicitly *not* a
/// clinical risk score.
public struct CardioScore: Codable, Sendable, Hashable {
    /// 0...100 composite score.
    public let value: Int
    /// Softened risk band the score falls into.
    public let risk: RiskLevel
    /// Short, friendly summary line.
    public let headline: String
    /// Number of readings that contributed to today's score.
    public let contributingReadings: Int

    public init(value: Int, risk: RiskLevel, headline: String, contributingReadings: Int) {
        self.value = min(max(value, 0), 100)
        self.risk = risk
        self.headline = headline
        self.contributingReadings = contributingReadings
    }

    /// Placeholder shown before any check has been taken today.
    public static let empty = CardioScore(
        value: 0,
        risk: .unknown,
        headline: "Take today's first check",
        contributingReadings: 0
    )

    /// Normalised 0...1 progress for the ring.
    public var progress: Double { Double(value) / 100.0 }
}
