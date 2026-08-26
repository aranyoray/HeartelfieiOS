import Foundation

/// Single source of truth for replaceable identifiers: product naming and
/// persistence keys.
public enum HeartelfieConfig {

    // MARK: - Branding

    public static let appName = "DailyDil"

    // MARK: - Persistence

    /// On-disk data directory name. Frozen at the original brand so existing
    /// installs keep finding their encrypted readings after the DailyDil rename.
    public static let storageDirectoryName = "Heartelfie"
    /// Keychain account name under which the local DB encryption key is stored.
    public static let encryptionKeyAccount = "com.heartelfie.dbkey"
    /// Keychain service identifier.
    public static let keychainService = "com.heartelfie.app"
    /// App-group container shared with the widget extension. Carries only the
    /// non-sensitive dashboard rollup (score + streak), never readings.
    public static let appGroupID = "group.com.heartelfie.ios"
}
