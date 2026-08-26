import Foundation

/// Single source of truth for replaceable identifiers: product naming and
/// persistence keys.
public enum HeartelfieConfig {

    // MARK: - Branding

    public static let appName = "Heartelfie"

    // MARK: - Persistence

    /// Keychain account name under which the local DB encryption key is stored.
    public static let encryptionKeyAccount = "com.heartelfie.dbkey"
    /// Keychain service identifier.
    public static let keychainService = "com.heartelfie.app"
}
