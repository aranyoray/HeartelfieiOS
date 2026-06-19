import Foundation

/// Live connection/quality state of the Heartelfie hardware device. Device
/// `.measurement` modalities only unlock when `isConnected` and contact is good.
public struct DeviceState: Codable, Sendable, Hashable {
    public enum Connection: String, Codable, Sendable, Hashable {
        case disconnected, scanning, connecting, connected, reconnecting

        public var displayName: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .scanning: return "Scanning…"
            case .connecting: return "Connecting…"
            case .connected: return "Connected"
            case .reconnecting: return "Reconnecting…"
            }
        }
    }

    /// Quality of electrode / finger contact on the device.
    public enum Contact: String, Codable, Sendable, Hashable {
        case unknown, none, poor, good

        public var displayName: String {
            switch self {
            case .unknown: return "Unknown"
            case .none: return "No contact"
            case .poor: return "Poor contact"
            case .good: return "Good contact"
            }
        }

        public var isUsable: Bool { self == .good }
    }

    public var connection: Connection
    public var contact: Contact
    /// Battery level 0...1, or nil if unknown.
    public var batteryLevel: Double?
    public var firmwareVersion: String?
    public var deviceName: String?
    /// Whether the developer "simulate device" toggle is forcing a mock peripheral.
    public var isSimulated: Bool

    public init(
        connection: Connection = .disconnected,
        contact: Contact = .unknown,
        batteryLevel: Double? = nil,
        firmwareVersion: String? = nil,
        deviceName: String? = nil,
        isSimulated: Bool = false
    ) {
        self.connection = connection
        self.contact = contact
        self.batteryLevel = batteryLevel
        self.firmwareVersion = firmwareVersion
        self.deviceName = deviceName
        self.isSimulated = isSimulated
    }

    public var isConnected: Bool { connection == .connected }

    /// Device measurements are only permitted when connected with good contact.
    public var canMeasure: Bool { isConnected && contact.isUsable }

    public static let disconnected = DeviceState()
}
