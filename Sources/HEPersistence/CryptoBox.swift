import Foundation
import HECore

#if canImport(CryptoKit)
import CryptoKit
#endif

/// Errors thrown while sealing or opening data.
public enum CryptoBoxError: Error, Sendable, CustomStringConvertible {
    case sealFailed
    case openFailed
    case invalidKey

    public var description: String {
        switch self {
        case .sealFailed: return "Failed to encrypt (seal) data."
        case .openFailed: return "Failed to decrypt (open) data."
        case .invalidKey: return "The encryption key was invalid."
        }
    }
}

/// Authenticated symmetric encryption for data at rest.
///
/// On Apple platforms this uses **AES-GCM** (`AES.GCM` from CryptoKit) with a
/// 256-bit key pulled from the ``KeychainStore``. The combined output
/// (nonce ‖ ciphertext ‖ tag) is returned as a single `Data` blob.
///
/// On platforms lacking CryptoKit/Security, a clearly-marked **insecure
/// passthrough** is used so the module still compiles and runs (tests, Linux CI).
/// Production targets are always Apple platforms, where real encryption applies.
///
/// `CryptoBox` is `Sendable`: it caches the key bytes loaded once at init.
public struct CryptoBox: Sendable {

    private let keyData: Data

    /// Creates a box, loading (or generating on first run) the symmetric key from
    /// the given Keychain store.
    public init(keychain: KeychainStore = KeychainStore()) throws {
        self.keyData = try keychain.loadOrCreateKeyData()
    }

    /// Creates a box from explicit key bytes (useful for tests / key rotation).
    public init(keyData: Data) {
        self.keyData = keyData
    }

    /// Encrypts `data`, returning a self-contained sealed blob.
    public func seal(_ data: Data) throws -> Data {
        #if canImport(CryptoKit)
        let key = SymmetricKey(data: keyData)
        do {
            let sealed = try AES.GCM.seal(data, using: key)
            guard let combined = sealed.combined else { throw CryptoBoxError.sealFailed }
            return combined
        } catch {
            throw CryptoBoxError.sealFailed
        }
        #else
        // WARNING: fallback — not encrypted. Compiles/runs only where CryptoKit
        // is unavailable; never reached on Apple platforms.
        return data
        #endif
    }

    /// Decrypts a blob previously produced by ``seal(_:)``.
    public func open(_ data: Data) throws -> Data {
        #if canImport(CryptoKit)
        let key = SymmetricKey(data: keyData)
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw CryptoBoxError.openFailed
        }
        #else
        // WARNING: fallback — not encrypted. Mirrors the passthrough in `seal`.
        return data
        #endif
    }

    /// Whether real cryptography is in effect on this platform. `false` indicates
    /// the insecure passthrough fallback is active.
    public static var isEncryptionAvailable: Bool {
        #if canImport(CryptoKit) && canImport(Security)
        return true
        #else
        return false
        #endif
    }
}
