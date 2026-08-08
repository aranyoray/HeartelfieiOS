import Foundation
import HECore

#if canImport(Security)
import Security
#endif

/// Errors thrown by the Keychain-backed key store.
public enum KeychainError: Error, Sendable, CustomStringConvertible {
    /// The Security framework returned a non-success status (`OSStatus` raw value).
    /// Stored as `Int32` (the underlying type of `OSStatus`) so the error type
    /// stays portable to platforms without the Security framework.
    case unhandled(Int32)
    /// The Security framework is unavailable on this platform.
    case unavailable
    /// A stored item existed but could not be decoded into the expected shape.
    case malformedItem

    public var description: String {
        switch self {
        case .unhandled(let status):
            return "Keychain operation failed with status \(status)."
        case .unavailable:
            return "Keychain (Security framework) is unavailable on this platform."
        case .malformedItem:
            return "A stored Keychain item could not be decoded."
        }
    }
}

/// Stores and loads the symmetric encryption key used by ``CryptoBox`` in the
/// system Keychain.
///
/// The key data lives under ``HeartelfieConfig/keychainService`` /
/// ``HeartelfieConfig/encryptionKeyAccount`` as a generic-password item. On first
/// run a fresh 256-bit key is generated and persisted; subsequent runs load it.
///
/// On platforms without the Security framework (e.g. Linux CI) a clearly-marked
/// in-memory fallback keeps the module compiling and runnable for tests. The
/// fallback is **not** persistent and **not** secure — production targets are
/// always Apple platforms where the real Keychain path is used.
///
/// The type is `Sendable`; it holds no mutable state of its own (the Keychain is
/// the backing store), and the fallback uses a process-wide lock.
public struct KeychainStore: Sendable {

    /// Keychain service identifier (defaults to the configured Heartelfie value).
    public let service: String
    /// Keychain account name (defaults to the configured Heartelfie value).
    public let account: String

    public init(
        service: String = HeartelfieConfig.keychainService,
        account: String = HeartelfieConfig.encryptionKeyAccount
    ) {
        self.service = service
        self.account = account
    }

    /// Loads the existing key, or generates and persists a new 256-bit key on
    /// first run. Returns the raw key bytes.
    public func loadOrCreateKeyData(byteCount: Int = 32) throws -> Data {
        if let existing = try loadKeyData() {
            return existing
        }
        let fresh = Self.randomBytes(count: byteCount)
        try storeKeyData(fresh)
        return fresh
    }

    /// Loads the stored key bytes, or `nil` if no key has been persisted yet.
    public func loadKeyData() throws -> Data? {
        #if canImport(Security)
        var query = baseQuery()
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw KeychainError.malformedItem }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandled(status)
        }
        #else
        return Self.fallback.load(service: service, account: account)
        #endif
    }

    /// Persists the given key bytes, replacing any existing item.
    ///
    /// Uses an in-place `SecItemUpdate`, falling back to `SecItemAdd` only when no
    /// item exists yet. This is deliberately **not** delete-then-add: a crash
    /// between a delete and a subsequent add would leave no key at all, rendering
    /// every existing encrypted reading permanently unrecoverable. Update-or-add
    /// never removes the live key until a replacement is in place.
    public func storeKeyData(_ data: Data) throws {
        #if canImport(Security)
        // Available after first unlock; survives reboot but not restore-to-new-device.
        let mutableAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, mutableAttributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            // First run — no existing item to update, so add a fresh one.
            var attributes = baseQuery()
            for (key, value) in mutableAttributes { attributes[key] = value }
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
        default:
            throw KeychainError.unhandled(updateStatus)
        }
        #else
        Self.fallback.store(data, service: service, account: account)
        #endif
    }

    /// Deletes the stored key. Safe to call when no key exists.
    public func deleteKey() throws {
        #if canImport(Security)
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
        #else
        Self.fallback.delete(service: service, account: account)
        #endif
    }

    // MARK: - Private

    #if canImport(Security)
    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
    #endif

    /// Cryptographically-strong random bytes, with a deterministic-but-unique
    /// last-resort fallback if the system RNG call is unavailable.
    private static func randomBytes(count: Int) -> Data {
        #if canImport(Security)
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        if status == errSecSuccess {
            return Data(bytes)
        }
        #endif
        // Fallback RNG (non-Apple platforms only). Adequate for test fixtures.
        var generator = SystemRandomNumberGenerator()
        return Data((0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
    }

    // MARK: - Non-Apple fallback (in-memory, NOT secure / NOT persistent)

    #if !canImport(Security)
    /// WARNING: fallback — keys are kept only in process memory and are lost on
    /// exit. Used solely so the module compiles/runs on platforms lacking the
    /// Security framework. Never used on Apple platforms.
    private final class FallbackKeyStore: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String: Data] = [:]

        private func key(service: String, account: String) -> String { "\(service)|\(account)" }

        func load(service: String, account: String) -> Data? {
            lock.lock(); defer { lock.unlock() }
            return storage[key(service: service, account: account)]
        }

        func store(_ data: Data, service: String, account: String) {
            lock.lock(); defer { lock.unlock() }
            storage[key(service: service, account: account)] = data
        }

        func delete(service: String, account: String) {
            lock.lock(); defer { lock.unlock() }
            storage[key(service: service, account: account)] = nil
        }
    }

    private static let fallback = FallbackKeyStore()
    #endif
}
