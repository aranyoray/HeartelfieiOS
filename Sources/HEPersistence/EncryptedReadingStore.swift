import Foundation
import HECore

/// The production, on-device ``ReadingRepository``.
///
/// Storage model: the full dataset is a `Codable` snapshot (`[CardioReading]` +
/// `HealthProfile`) serialised to JSON, sealed with **AES-GCM** via ``CryptoBox``
/// (key in the Keychain), and written as a single encrypted blob to the app's
/// Application Support directory. This keeps all health data encrypted at rest
/// with minimal moving parts — no schema migrations, no plaintext on disk.
///
/// The store is an `actor`, so its in-memory cache and disk writes are
/// serialised and data-race free. The cache is loaded lazily on first access and
/// re-sealed to disk after every mutation.
///
/// A SwiftData-backed alternative model is provided separately in
/// `SwiftDataReadingModel.swift` behind `#if canImport(SwiftData)`; this
/// file-based store is the recommended default for robustness.
public actor EncryptedReadingStore: ReadingRepository {

    // MARK: Persisted snapshot

    /// The on-disk shape. Versioned so a future migration can branch on `schema`.
    private struct Snapshot: Codable, Sendable {
        var schema: Int
        var readings: [CardioReading]
        var profile: HealthProfile?

        static let currentSchema = 1
        static let empty = Snapshot(schema: currentSchema, readings: [], profile: nil)

        init(schema: Int, readings: [CardioReading], profile: HealthProfile?) {
            self.schema = schema
            self.readings = readings
            self.profile = profile
        }

        private enum CodingKeys: String, CodingKey { case schema, readings, profile }

        /// Resilient decode: any reading that no longer maps to a current enum case
        /// (e.g. a modality or metric removed in a later version) is skipped rather
        /// than throwing and bricking the entire store. Valid readings survive.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? Self.currentSchema
            // Decode the profile through the same `Lossy` wrapper used for readings:
            // a valid (incl. legacy) profile is preserved, and only a genuinely
            // corrupt one is dropped — deliberately, not via a silent bare `try?`.
            profile = (try? c.decode(Lossy<HealthProfile>.self, forKey: .profile))?.value
            let lossy = (try? c.decode([Lossy<CardioReading>].self, forKey: .readings)) ?? []
            readings = lossy.compactMap(\.value)
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(schema, forKey: .schema)
            try c.encode(readings, forKey: .readings)
            try c.encodeIfPresent(profile, forKey: .profile)
        }
    }

    /// Decodes `T` if possible, otherwise holds `nil` — lets an array skip elements
    /// that fail to decode (used to drop readings with retired enum rawValues).
    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

    // MARK: Stored state

    private let fileURL: URL
    private let crypto: CryptoBox
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Lazily-loaded in-memory cache; `nil` until first access.
    private var cache: Snapshot? = nil

    // MARK: Init

    /// Creates the store.
    /// - Parameters:
    ///   - directory: Directory for the encrypted file. Defaults to
    ///     `Application Support/Heartelfie`, created if needed.
    ///   - crypto: Encryption box (defaults to one keyed from the Keychain).
    ///   - fileName: Name of the encrypted blob on disk.
    public init(
        directory: URL? = nil,
        crypto: CryptoBox? = nil,
        fileName: String = "heartelfie.store"
    ) throws {
        let dir = try directory ?? Self.defaultDirectory()
        try Self.ensureDirectoryExists(dir)
        self.fileURL = dir.appendingPathComponent(fileName, isDirectory: false)
        self.crypto = try crypto ?? CryptoBox()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Default directory: `Application Support/Heartelfie`.
    public static func defaultDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent(HeartelfieConfig.storageDirectoryName, isDirectory: true)
    }

    private static func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: - CRUD

    public func save(_ reading: CardioReading) async throws {
        var snapshot = try loadSnapshot()
        if let index = snapshot.readings.firstIndex(where: { $0.id == reading.id }) {
            snapshot.readings[index] = reading
        } else {
            snapshot.readings.append(reading)
        }
        try persist(snapshot)
    }

    public func allReadings() async throws -> [CardioReading] {
        try loadSnapshot().readings.sorted { $0.timestamp > $1.timestamp }
    }

    public func readings(for modality: Modality?) async throws -> [CardioReading] {
        let all = try await allReadings()
        guard let modality else { return all }
        return all.filter { $0.modality == modality }
    }

    public func reading(id: UUID) async throws -> CardioReading? {
        try loadSnapshot().readings.first { $0.id == id }
    }

    public func delete(id: UUID) async throws {
        var snapshot = try loadSnapshot()
        snapshot.readings.removeAll { $0.id == id }
        try persist(snapshot)
    }

    /// Full delete for data portability: clears all readings, the profile, and
    /// removes the encrypted file from disk.
    public func deleteAll() async throws {
        // Remove the file first: if removal fails we must NOT reset the cache,
        // or the UI reports success while the data quietly returns next launch.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        let quarantineURL = fileURL.appendingPathExtension("corrupt")
        if FileManager.default.fileExists(atPath: quarantineURL.path) {
            try FileManager.default.removeItem(at: quarantineURL)
        }
        cache = .empty
    }

    // MARK: - Aggregations

    public func dailyChecks(days: Int) async throws -> [DailyCheck] {
        ReadingAggregator.dailyChecks(from: try loadSnapshot().readings, days: days)
    }

    public func streak() async throws -> CheckStreak {
        ReadingAggregator.streak(from: try loadSnapshot().readings)
    }

    public func todayScore() async throws -> CardioScore {
        ReadingAggregator.todayScore(from: try loadSnapshot().readings)
    }

    public func timeSeries(metric: MetricKind, days: Int) async throws -> [TimeSeriesPoint] {
        ReadingAggregator.timeSeries(from: try loadSnapshot().readings, metric: metric, days: days)
    }

    // MARK: - Profile

    public func loadProfile() async throws -> HealthProfile? {
        try loadSnapshot().profile
    }

    public func saveProfile(_ profile: HealthProfile) async throws {
        var snapshot = try loadSnapshot()
        snapshot.profile = profile
        try persist(snapshot)
    }

    // MARK: - Disk I/O (encrypted)

    /// Returns the cached snapshot, loading + decrypting from disk on first use.
    private func loadSnapshot() throws -> Snapshot {
        if let cache { return cache }
        let snapshot = try readFromDisk()
        cache = snapshot
        return snapshot
    }

    /// Reads + decrypts + decodes the snapshot, or returns `.empty` if no file.
    ///
    /// An unreadable blob (key mismatch after a device restore — the Keychain key
    /// is `ThisDeviceOnly` while the file rides along in backups — or bit-rot) is
    /// quarantined instead of thrown: the store restarts empty and stays usable,
    /// rather than failing every subsequent `save` forever. The ciphertext is
    /// kept beside the store as `*.corrupt` so nothing is silently destroyed.
    private func readFromDisk() throws -> Snapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        let sealed = try Data(contentsOf: fileURL)
        guard !sealed.isEmpty else { return .empty }
        do {
            let plaintext = try crypto.open(sealed)
            return try decoder.decode(Snapshot.self, from: plaintext)
        } catch {
            // If the blob can't even be moved aside, fail the read rather than
            // return .empty — a later save would overwrite the only ciphertext
            // copy, breaking the "nothing is silently destroyed" promise.
            try quarantineUnreadableStore()
            return .empty
        }
    }

    /// Removes the on-disk blob (and any quarantined copy) without needing a
    /// working Keychain/crypto stack. Used by delete-all when the app is running
    /// on the in-memory fallback: the user's deletion must still reach the disk.
    public static func destroyOnDiskStore(fileName: String = "heartelfie.store") throws {
        let dir = try defaultDirectory()
        let fm = FileManager.default
        for name in [fileName, fileName + ".corrupt"] {
            let url = dir.appendingPathComponent(name, isDirectory: false)
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
            }
        }
    }

    /// Moves an undecryptable/undecodable blob aside so the store can restart.
    private func quarantineUnreadableStore() throws {
        let quarantineURL = fileURL.appendingPathExtension("corrupt")
        // Keep only the most recent quarantined copy; this is a recovery aid,
        // not an archive.
        if FileManager.default.fileExists(atPath: quarantineURL.path) {
            try FileManager.default.removeItem(at: quarantineURL)
        }
        try FileManager.default.moveItem(at: fileURL, to: quarantineURL)
    }

    /// Encodes + seals + atomically writes the snapshot, updating the cache.
    private func persist(_ snapshot: Snapshot) throws {
        let plaintext = try encoder.encode(snapshot)
        let sealed = try crypto.seal(plaintext)
        try sealed.write(to: fileURL, options: Self.writeOptions)
        cache = snapshot
    }

    /// Atomic write with a data-protection class matching the Keychain key
    /// (`AfterFirstUnlock…`): stricter Complete protection would make saves fail
    /// while the device is locked even though the key is still available.
    private static var writeOptions: Data.WritingOptions {
        #if os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
        return [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #else
        return [.atomic]
        #endif
    }
}
