import Foundation

/// Where a raw physiological signal physically originates.
///
/// Surfacing the source is part of being *architecturally honest* about each
/// signal. A smartphone has no ECG sensor, so `.device` is the only source that
/// may ever back an ECG, clinical SpO₂, or hemoglobin metric.
public enum SignalSource: String, Codable, Sendable, CaseIterable, Hashable {
    /// Rear camera + torch (transmissive finger PPG).
    case rearCamera
    /// Front camera (contactless facial rPPG via Vision face ROI).
    case frontCamera
    /// Accelerometer / gyroscope (seismocardiography).
    case motion
    /// Microphone (phonocardiography / heart sounds).
    case microphone
    /// The connected Heartelfie hardware device over BLE.
    case device

    public var displayName: String {
        switch self {
        case .rearCamera: return "Rear camera + torch"
        case .frontCamera: return "Front camera"
        case .motion: return "Motion sensors"
        case .microphone: return "Microphone"
        case .device: return "Heartelfie device"
        }
    }

    /// SF Symbol representing the source.
    public var systemImage: String {
        switch self {
        case .rearCamera: return "camera.fill"
        case .frontCamera: return "person.crop.square.badge.video"
        case .motion: return "gyroscope"
        case .microphone: return "waveform.and.mic"
        case .device: return "sensor.tag.radiowaves.forward.fill"
        }
    }

    /// Whether this source is provided exclusively by the hardware device.
    public var requiresDevice: Bool { self == .device }
}
