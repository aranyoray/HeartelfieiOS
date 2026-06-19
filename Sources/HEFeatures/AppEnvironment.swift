import Foundation
import Observation
import Combine
import HECore
import HESensors
import HEML
import HEPersistence

/// The app's composition root and shared, observable state container.
///
/// Owns the service layer (sensors, inference, encrypted persistence, HealthKit,
/// BLE, export) and the cached dashboard state the screens read. Injected into the
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
    public let ble: HeartelfieBLEManager
    public let exporter: ReadingExporter

    // MARK: App state
    public var profile: HealthProfile
    public var hasCompletedOnboarding: Bool
    public var deviceState: DeviceState
    public var forceSimulateDevice: Bool {
        didSet {
            guard oldValue != forceSimulateDevice else { return }
            factory.forceSimulation = forceSimulateDevice
            ble.isSimulated = forceSimulateDevice || SensorFactory.isSimulator
            defaults.set(forceSimulateDevice, forKey: Self.simulateKey)
        }
    }

    // MARK: Dashboard cache
    public var todayScore: CardioScore = .empty
    public var streak: CheckStreak = .none
    public var recentReadings: [CardioReading] = []
    public var dailyChecks: [DailyCheck] = []
    public var isLoading: Bool = false

    // MARK: Private
    @ObservationIgnored private let factory: SensorFactory
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    private static let onboardedKey = "he.onboarding.completed"
    private static let simulateKey = "he.developer.simulateDevice"

    // MARK: Init

    /// - Parameters:
    ///   - repository: inject for previews/tests; defaults to the encrypted store
    ///     (falling back to an in-memory store if it can't be opened).
    ///   - defaults: inject for tests.
    ///   - forceSimulate: force mock sensors + simulated device.
    public init(
        repository: (any ReadingRepository)? = nil,
        defaults: UserDefaults = .standard,
        forceSimulate: Bool = SensorFactory.isSimulator
    ) {
        let simulate = forceSimulate
        let bleManager = HeartelfieBLEManager(simulated: simulate || SensorFactory.isSimulator)
        let sensorFactory = SensorFactory(forceSimulation: simulate, deviceBLE: bleManager)

        self.ble = bleManager
        self.factory = sensorFactory
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
        }

        self.profile = .empty
        self.hasCompletedOnboarding = defaults.bool(forKey: Self.onboardedKey)
        self.forceSimulateDevice = simulate
        self.deviceState = bleManager.state

        observeBLE()
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

    private func observeBLE() {
        ble.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                // `.receive(on: .main)` guarantees this runs on the main actor's
                // executor, so assuming isolation here is safe and lets us touch
                // the @MainActor-isolated `deviceState` synchronously.
                MainActor.assumeIsolated { self?.deviceState = state }
            }
            .store(in: &cancellables)
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
    public func record(_ reading: CardioReading) async {
        try? await repository.save(reading)
        try? await healthKit.write(reading: reading)
        await refreshDashboard()
    }

    public func deleteAllData() async {
        try? await repository.deleteAll()
        await refreshDashboard()
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
            await self?.record(reading)
        }
    }

    /// All modalities, with device modalities flagged as available only when the
    /// device can currently measure.
    public func isAvailable(_ modality: Modality) -> Bool {
        guard modality.requiresDevice else { return true }
        return deviceState.canMeasure || deviceState.isSimulated || forceSimulateDevice
    }
}
