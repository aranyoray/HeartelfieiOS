import Foundation

/// Single source of truth for replaceable identifiers: product naming, cloud
/// model endpoints, and the hardware BLE GATT profile. Everything here is a
/// **placeholder** the team swaps for production values — keeping it in one file
/// is a deliberate requirement.
public enum HeartelfieConfig {

    // MARK: - Branding

    public static let appName = "Heartelfie"
    public static let deviceName = "Heartelfie Device"
    public static let deviceShortName = "Heartelfie"

    // MARK: - Cloud model API (placeholders — wire to real endpoints)

    public enum CloudAPI {
        /// Base URL for the cloud model service. Replace for production.
        public static let baseURL = URL(string: "https://api.heartelfie.example/v1")!

        /// Endpoint paths per model family.
        public static let ecgAnalysisPath = "/models/ecg-fm/analyze"
        public static let ppgEncodePath = "/models/ppg/encode"

        /// Whether to short-circuit networking and return realistic mock
        /// responses (true by default so the app is fully demoable offline).
        public static let useMockResponses = true

        /// SHA-256 pins for TLS certificate pinning (base64). Placeholder.
        public static let certificatePinsBase64: [String] = [
            "REPLACE_WITH_REAL_SPKI_SHA256_PIN="
        ]
    }

    // MARK: - BLE GATT profile (placeholders — replace with real firmware profile)

    /// Configurable BLE service/characteristic UUIDs for the Heartelfie device.
    /// These are invented placeholders; swap for the real firmware GATT profile.
    public enum BLE {
        /// Primary Heartelfie service.
        public static let serviceUUID = "0000FE40-CC7A-482A-984A-7F2ED5B3E58F"

        /// Multi-channel PPG stream (multi-wavelength).
        public static let ppgStreamCharacteristic = "0000FE41-CC7A-482A-984A-7F2ED5B3E58F"
        /// ECG stream.
        public static let ecgStreamCharacteristic = "0000FE42-CC7A-482A-984A-7F2ED5B3E58F"
        /// Bio-impedance stream.
        public static let bioZStreamCharacteristic = "0000FE43-CC7A-482A-984A-7F2ED5B3E58F"
        /// Battery level.
        public static let batteryCharacteristic = "0000FE44-CC7A-482A-984A-7F2ED5B3E58F"
        /// Electrode / finger contact status.
        public static let contactStatusCharacteristic = "0000FE45-CC7A-482A-984A-7F2ED5B3E58F"
        /// Control / command channel (start/stop streams, config).
        public static let controlCharacteristic = "0000FE46-CC7A-482A-984A-7F2ED5B3E58F"
        /// Firmware revision string.
        public static let firmwareCharacteristic = "0000FE47-CC7A-482A-984A-7F2ED5B3E58F"
    }

    // MARK: - Persistence

    /// Keychain account name under which the local DB encryption key is stored.
    public static let encryptionKeyAccount = "com.heartelfie.dbkey"
    /// Keychain service identifier.
    public static let keychainService = "com.heartelfie.app"
}
