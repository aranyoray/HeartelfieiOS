import Foundation
import Observation
import HECore
import HESensors
import HEML
import HEPersistence

/// The app's composition root and shared, observable state container.
///
/// Owns the service layer (sensors, inference, encrypted persistence, HealthKit,
/// export) and the cached dashboard state the screens read. Injected into the
/// SwiftUI environment by `RootView` and read with
/// `@Environment(AppEnvironment.self)`.
@MainActor
@Observable
public final class AppEnvironment {

    // MARK: Services
    public let sensors: SensorProviding
    public let repository: any ReadingRepository
    public let inference: any InferenceProviding
    public let healthKit: HealthKitBridge
    public let exporter: ReadingExporter

    // MARK: App state
    public var profile: HealthProfile
    public var hasCompletedOnboarding: Bool

    // MARK: Dashboard cache
    public var todayScore: CardioScore = .empty
    public var streak: CheckStreak = .none
    public var recentReadings: [CardioReading] = []
    public var dailyChecks: [DailyCheck] = []
    public var isLoading: Bool = false

    /// True when the encrypted store could not be opened and the app fell back
    /// to in-memory storage — new readings will be lost when the app closes.
    /// Home surfaces this so the degradation is never silent.
    public private(set) var storageDegraded = false

    // MARK: Private
    @ObservationIgnored private let defaults: UserDefaults

    private static let onboardedKey = "he.onboarding.completed"

    // MARK: Init

    /// - Parameters:
    ///   - repository: inject for previews/tests; defaults to the encrypted store
    ///     (falling back to an in-memory store if it can't be opened).
    ///   - defaults: inject for tests.
    ///   - forceSimulate: force mock sensors (defaults on in the Simulator).
    public init(
        repository: (any ReadingRepository)? = nil,
        defaults: UserDefaults = .standard,
        forceSimulate: Bool = SensorFactory.isSimulator
    ) {
        let sensorFactory = SensorFactory(forceSimulation: forceSimulate)

        self.sensors = sensorFactory
        self.inference = InferenceCoordinator()
        self.healthKit = HealthKitBridge()
        self.exporter = ReadingExporter()
        self.defaults = defaults

        if let repository {
            self.repository = repository
        } else if let encrypted = try? EncryptedReadingStore() {
            self.repository = encrypted
        } else {
            self.repository = InMemoryReadingRepository()
            self.storageDegraded = true
        }

        self.profile = .empty
        self.hasCompletedOnboarding = defaults.bool(forKey: Self.onboardedKey)
    }

    /// A fully in-memory, seeded environment for SwiftUI previews and demos.
    public static func preview(onboarded: Bool = true) -> AppEnvironment {
        let env = AppEnvironment(
            repository: InMemoryReadingRepository(),
            defaults: UserDefaults(suiteName: "he.preview") ?? .standard,
            forceSimulate: true
        )
        env.hasCompletedOnboarding = onboarded
        env.profile = SampleData.profile
        Task { await env.refreshDashboard() }
        return env
    }

    // MARK: Lifecycle

    /// Load persisted profile and dashboard data on launch.
    public func bootstrap() async {
        if let saved = try? await repository.loadProfile() {
            profile = saved
        }
        await refreshDashboard()
    }

    /// Refresh the cached Home/Trends data from the repository.
    public func refreshDashboard() async {
        isLoading = true
        defer { isLoading = false }
        async let scoreT = repository.todayScore()
        async let streakT = repository.streak()
        async let recentT = repository.allReadings()
        async let checksT = repository.dailyChecks(days: 49)

        todayScore = (try? await scoreT) ?? .empty
        streak = (try? await streakT) ?? .none
        recentReadings = Array(((try? await recentT) ?? []).prefix(12))
        dailyChecks = (try? await checksT) ?? []
    }

    // MARK: Mutations

    public func completeOnboarding(_ profile: HealthProfile) async {
        self.profile = profile
        try? await repository.saveProfile(profile)
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Self.onboardedKey)
    }

    public func updateProfile(_ profile: HealthProfile) async {
        self.profile = profile
        try? await repository.saveProfile(profile)
    }

    /// Persist a finished reading, mirror supported types to HealthKit, refresh.
    ///
    /// Throws when the on-device save fails so callers can tell the user the
    /// reading wasn't kept. The HealthKit mirror only runs after a successful
    /// save and stays best-effort — Health never holds a reading the app lost.
    public func record(_ reading: CardioReading) async throws {
        try await repository.save(reading)
        try? await healthKit.write(reading: reading)
        await refreshDashboard()
    }

    /// Permanently removes user data: every reading and profile value in the
    /// on-device store, exported report files left in the temporary directory,
    /// and (best-effort) the samples DailyDil wrote to Apple Health.
    ///
    /// Throws if the on-device store could not be wiped — the best-effort
    /// cleanups never run first, so a failure is never masked by partial success.
    public func deleteAllData() async throws {
        try await repository.deleteAll()
        profile = .empty
        Self.deleteExportedFiles()
        await healthKit.deleteAllWrittenSamples()
        await refreshDashboard()
    }

    /// Removes exported report files (CSV/PDF) that the share flows wrote to the
    /// temporary directory. Matches both brand prefixes ever shipped.
    private static func deleteExportedFiles() {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        guard let names = try? fm.contentsOfDirectory(atPath: tmp.path) else { return }
        for name in names where name.hasPrefix("DailyDil-") || name.hasPrefix("Heartelfie-") {
            try? fm.removeItem(at: tmp.appendingPathComponent(name))
        }
    }

    public func enableHealthKit() async {
        try? await healthKit.requestAuthorization()
    }

    // MARK: Capture

    /// Build a capture view model wired to record its result into the store.
    public func makeCaptureViewModel(for modality: Modality) -> CaptureViewModel {
        CaptureViewModel(
            modality: modality,
            sensors: sensors,
            inference: inference,
            profile: profile,
            skinTone: profile.monkSkinTone
        ) { [weak self] reading in
            try await self?.record(reading)
        }
    }
}
