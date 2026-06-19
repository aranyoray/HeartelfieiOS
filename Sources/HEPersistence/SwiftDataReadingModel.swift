import Foundation
import HECore

#if canImport(SwiftData)
import SwiftData

/// Optional SwiftData persistence model for cardio readings.
///
/// This is a **supplementary** option — the recommended default store is the
/// file-based ``EncryptedReadingStore``. It is kept fully self-contained behind
/// `#if canImport(SwiftData)` so it never affects the build on platforms lacking
/// SwiftData.
///
/// The reading is stored as a single encrypted blob plus a few plaintext index
/// columns (`id`, `timestamp`, `modalityRaw`) so the SwiftData layer can sort and
/// filter without ever holding decrypted health data at rest. Decryption /
/// encryption flows through ``CryptoBox`` exactly like the file-based store.
///
/// - Note: Custom waveforms and hemoglobin live only inside the encrypted blob;
///   they are never written to HealthKit.
@available(iOS 17, *)
@Model
public final class StoredReadingModel {
    /// Stable reading identifier (also the SwiftData unique key).
    @Attribute(.unique) public var id: UUID
    /// Plaintext index column for sorting/filtering trends.
    public var timestamp: Date
    /// Plaintext index column for per-modality queries (`Modality.rawValue`).
    public var modalityRaw: String
    /// AES-GCM-sealed JSON of the full ``CardioReading``.
    public var sealedPayload: Data

    public init(id: UUID, timestamp: Date, modalityRaw: String, sealedPayload: Data) {
        self.id = id
        self.timestamp = timestamp
        self.modalityRaw = modalityRaw
        self.sealedPayload = sealedPayload
    }

    /// Builds a model row from a reading, sealing its JSON with the given box.
    public static func make(
        from reading: CardioReading,
        crypto: CryptoBox,
        encoder: JSONEncoder
    ) throws -> StoredReadingModel {
        let plaintext = try encoder.encode(reading)
        let sealed = try crypto.seal(plaintext)
        return StoredReadingModel(
            id: reading.id,
            timestamp: reading.timestamp,
            modalityRaw: reading.modality.rawValue,
            sealedPayload: sealed
        )
    }

    /// Decrypts and decodes this row back into a ``CardioReading``.
    public func decoded(crypto: CryptoBox, decoder: JSONDecoder) throws -> CardioReading {
        let plaintext = try crypto.open(sealedPayload)
        return try decoder.decode(CardioReading.self, from: plaintext)
    }
}

/// Convenience for constructing an in-memory or on-disk SwiftData container for
/// ``StoredReadingModel``. Wire this into a SwiftData-backed repository if the
/// team prefers SwiftData over the file-based store.
///
/// - TODO: Provide a full `SwiftDataReadingStore: ReadingRepository` actor if/when
///   SwiftData replaces the file-based store as the default.
@available(iOS 17, *)
public enum SwiftDataReadingContainer {
    /// Creates a `ModelContainer` for the reading model.
    /// - Parameter inMemory: When `true`, data is not persisted to disk (tests).
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: StoredReadingModel.self, configurations: configuration)
    }
}
#endif
