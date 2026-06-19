import SwiftUI
import HECore
import HEDesign

/// Scan, connect, and manage the Heartelfie hardware device. Reflects the live
/// `DeviceState` (connection, battery, firmware, electrode contact) and offers the
/// demo simulation toggle.
///
/// Honest framing throughout: the device unlocks the higher-confidence
/// *measurement* tier, but those signals are device-only and still wellness/
/// screening — never diagnostic.
struct DevicePairingView: View {
    @Environment(AppEnvironment.self) private var env

    init() {}

    private var device: DeviceState { env.deviceState }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                statusSection
                contactSection
                detailsSection
                actionSection
                simulateSection
                measurementTierSection
                EmergencyNotice()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle("Heartelfie device")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Connection",
                subtitle: connectionSubtitle,
                systemImage: "sensor.tag.radiowaves.forward.fill"
            )

            DeviceStatusChip(state: device)

            if device.connection == .reconnecting {
                reconnectionNote
            }
        }
    }

    private var connectionSubtitle: String {
        switch device.connection {
        case .connected: return "Your device is connected and ready."
        case .connecting: return "Connecting to your device…"
        case .reconnecting: return "The link dropped — trying to reconnect."
        case .scanning: return "Looking for a nearby Heartelfie device…"
        case .disconnected: return "No device connected yet."
        }
    }

    private var reconnectionNote: some View {
        Label(
            "Keep the device nearby and charged. Heartelfie will reconnect automatically.",
            systemImage: "arrow.triangle.2.circlepath"
        )
        .font(.heCaption)
        .foregroundStyle(Color.heTextSecondary)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Electrode contact / finger placement

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Finger placement",
                subtitle: "Rest your fingertips on both electrodes for a clean signal.",
                systemImage: "hand.point.up.left.fill"
            )

            HECard {
                if device.isConnected {
                    ContactIndicator(contact: device.contact)
                } else {
                    Text("Connect your device to see live electrode contact.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(title: "Device", systemImage: "info.circle")

            HECard {
                VStack(spacing: HESpacing.sm) {
                    detailRow(
                        label: "Name",
                        value: device.deviceName ?? HeartelfieConfig.deviceName
                    )
                    Divider().overlay(Color.heSeparator)
                    detailRow(label: "Battery", value: batteryText)
                    Divider().overlay(Color.heSeparator)
                    detailRow(
                        label: "Firmware",
                        value: device.firmwareVersion ?? "—"
                    )
                    if device.isSimulated {
                        Divider().overlay(Color.heSeparator)
                        detailRow(label: "Mode", value: "Simulated (demo)")
                    }
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.heBody)
                .foregroundStyle(Color.heTextSecondary)
            Spacer()
            Text(value)
                .font(.heBody.weight(.medium))
                .foregroundStyle(Color.heTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var batteryText: String {
        guard let level = device.batteryLevel else { return "—" }
        return "\(Int((level * 100).rounded()))%"
    }

    // MARK: - Actions

    private var actionSection: some View {
        VStack(spacing: HESpacing.sm) {
            switch device.connection {
            case .disconnected:
                HEPrimaryButton("Scan for device", systemImage: "dot.radiowaves.left.and.right") {
                    env.ble.startScanning()
                }
            case .scanning:
                HEPrimaryButton("Connect", systemImage: "link") {
                    env.ble.connect()
                }
                HESecondaryButton("Stop scanning", systemImage: "stop.circle") {
                    env.ble.disconnect()
                }
            case .connecting, .reconnecting:
                HEPrimaryButton("Connecting…", isLoading: true) {}
                    .disabled(true)
                HESecondaryButton("Cancel", systemImage: "xmark") {
                    env.ble.disconnect()
                }
            case .connected:
                HESecondaryButton("Disconnect", systemImage: "link.badge.plus") {
                    env.ble.disconnect()
                }
            }
        }
    }

    // MARK: - Simulate toggle

    private var simulateSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            HESectionHeader(title: "Demos", systemImage: "wand.and.stars")

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Toggle(isOn: Binding(
                        get: { env.forceSimulateDevice },
                        set: { env.forceSimulateDevice = $0 }
                    )) {
                        Text("Simulate device for demos")
                            .font(.heBody)
                            .foregroundStyle(Color.heTextPrimary)
                    }
                    .tint(Color.hePrimary)

                    Text("Forces a synthetic Heartelfie peripheral so you can explore the measurement tier without hardware. Synthetic battery, firmware, and contact are shown above.")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextSecondary)
                }
            }
        }
    }

    // MARK: - Measurement tier note

    private var measurementTierSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            HESectionHeader(title: "What the device adds", systemImage: "waveform.path.ecg")

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Text("The Heartelfie device unlocks the higher-confidence measurement tier.")
                        .font(.heBody.weight(.medium))
                        .foregroundStyle(Color.heTextPrimary)

                    VStack(alignment: .leading, spacing: HESpacing.xs) {
                        tierItem("Hemoglobin estimate")
                        tierItem("Clinical-grade SpO₂")
                        tierItem("Single-lead ECG")
                        tierItem("Bioimpedance (BioZ)")
                    }

                    Text("These signals are device-only and still wellness and screening insights — not a diagnosis.")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                }
            }
        }
    }

    private func tierItem(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.heCallout)
            .foregroundStyle(Color.heTextSecondary)
            .labelStyle(.titleAndIcon)
    }
}

// MARK: - Contact indicator

/// A live electrode-contact indicator. Conveys quality with an icon, a label, and a
/// segmented bar — never color alone — so it remains legible with VoiceOver and for
/// color-vision differences.
private struct ContactIndicator: View {
    let contact: DeviceState.Contact

    var body: some View {
        HStack(spacing: HESpacing.md) {
            Image(systemName: glyph)
                .font(.title2)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: HESpacing.xs) {
                Text(contact.displayName)
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                Text(guidance)
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                qualityBar
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Electrode contact: \(contact.displayName). \(guidance)")
    }

    private var filledSegments: Int {
        switch contact {
        case .good: return 3
        case .poor: return 2
        case .none: return 1
        case .unknown: return 0
        }
    }

    private var qualityBar: some View {
        HStack(spacing: HESpacing.xs) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index < filledSegments ? tint : Color.heSeparator)
                    .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private var glyph: String {
        switch contact {
        case .good: return "hand.thumbsup.fill"
        case .poor: return "hand.point.up.braille.fill"
        case .none: return "hand.raised.slash.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var tint: Color {
        switch contact {
        case .good: return Color.heRisk(.normal)
        case .poor: return Color.heRisk(.watch)
        case .none: return Color.heRisk(.elevated)
        case .unknown: return Color.heTextTertiary
        }
    }

    private var guidance: String {
        switch contact {
        case .good: return "Great contact — hold steady while measuring."
        case .poor: return "Press a little more firmly and stay still."
        case .none: return "Place your fingertips on both electrodes."
        case .unknown: return "Waiting for a contact reading…"
        }
    }
}

#Preview("Device pairing") {
    NavigationStack {
        DevicePairingView()
            .environment(AppEnvironment.preview())
    }
}
