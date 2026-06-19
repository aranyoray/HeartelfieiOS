import Foundation
import HECore

/// An in-memory ``ReadingRepository`` for SwiftUI previews, demos and tests.
///
/// Seeded by default from `SampleData.history()` so previews show realistic
/// trends and streaks. State is held inside the actor, so access is data-race
/// free. Aggregation reuses ``ReadingAggregator`` exactly like the production
/// store.
public actor InMemoryReadingRepository: ReadingRepository {

    private var storedReadings: [CardioReading]
    private var storedProfile: HealthProfile?

    /// Creates a repository with explicit seed data.
    /// - Parameters:
    ///   - readings: Initial readings (defaults to `SampleData.history()`).
    ///   - profile: Initial profile (defaults to `SampleData.profile`).
    public init(
        readings: [CardioReading] = SampleData.history(),
        profile: HealthProfile? = SampleData.profile
    ) {
        self.storedReadings = readings
        self.storedProfile = profile
    }

    // MARK: - CRUD

    public func save(_ reading: CardioReading) async throws {
        if let index = storedReadings.firstIndex(where: { $0.id == reading.id }) {
            storedReadings[index] = reading
        } else {
            storedReadings.append(reading)
        }
    }

    public func allReadings() async throws -> [CardioReading] {
        storedReadings.sorted { $0.timestamp > $1.timestamp }
    }

    public func readings(for modality: Modality?) async throws -> [CardioReading] {
        let all = try await allReadings()
        guard let modality else { return all }
        return all.filter { $0.modality == modality }
    }

    public func reading(id: UUID) async throws -> CardioReading? {
        storedReadings.first { $0.id == id }
    }

    public func delete(id: UUID) async throws {
        storedReadings.removeAll { $0.id == id }
    }

    public func deleteAll() async throws {
        storedReadings.removeAll()
        storedProfile = nil
    }

    // MARK: - Aggregations

    public func dailyChecks(days: Int) async throws -> [DailyCheck] {
        ReadingAggregator.dailyChecks(from: storedReadings, days: days)
    }

    public func streak() async throws -> CheckStreak {
        ReadingAggregator.streak(from: storedReadings)
    }

    public func todayScore() async throws -> CardioScore {
        ReadingAggregator.todayScore(from: storedReadings)
    }

    public func timeSeries(metric: MetricKind, days: Int) async throws -> [TimeSeriesPoint] {
        ReadingAggregator.timeSeries(from: storedReadings, metric: metric, days: days)
    }

    // MARK: - Profile

    public func loadProfile() async throws -> HealthProfile? {
        storedProfile
    }

    public func saveProfile(_ profile: HealthProfile) async throws {
        storedProfile = profile
    }
}
