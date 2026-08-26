import Foundation

/// Errors that can abort or block a capture. `poorSignalQuality` is the most
/// important: it is the mechanism by which the mandatory SQI gate prevents a
/// metric from ever being computed off a rejected signal.
public enum CaptureError: Error, Sendable, Hashable {
    /// The capture cleared acquisition but failed the SQI gate. Carries the
    /// quality result so the UI can coach the user with specific fixes.
    case poorSignalQuality(SignalQuality)
    /// The user aborted the capture.
    case aborted
    /// A required permission was denied. Associated value names the permission.
    case permissionDenied(String)
    /// The capture ran past its time budget without enough clean signal.
    case timeout
    /// The sensor/source is unavailable on this hardware.
    case sensorUnavailable
    /// The reading was measured but could not be saved to the on-device store.
    case persistenceFailure

    public var userMessage: String {
        switch self {
        case .poorSignalQuality:
            return "We couldn't get a clean enough signal. Follow the on-screen tips and try again."
        case .aborted:
            return "Capture cancelled."
        case .permissionDenied(let name):
            return "DailyDil needs \(name) access for this check. You can enable it in Settings."
        case .timeout:
            return "That took longer than expected without a clean signal. Let's try again."
        case .sensorUnavailable:
            return "This sensor isn't available on your device."
        case .persistenceFailure:
            return "Your reading was measured but couldn't be saved on this device. Free up storage and try again."
        }
    }
}
