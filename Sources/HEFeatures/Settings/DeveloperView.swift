import SwiftUI
import HECore
import HEDesign

/// Developer-only conveniences: force the synthetic device, inspect the cloud and
/// BLE configuration, and confirm this is a demo build. Read-only except for the
/// simulation toggle.
struct DeveloperView: View {
    @Environment(AppEnvironment.self) private var env

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                demoBanner
                simulateSection
                cloudSection
                bleSection
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Demo banner

    private var demoBanner: some View {
        HStack(alignment: .top, spacing: HESpacing.sm) {
            Image(systemName: "hammer.fill")
                .foregroundStyle(Color.heAccent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: HESpacing.xxs) {
                Text("Demo build")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                Text("These tools are for development and demos only and aren't shown to end users.")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(HESpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.heSurface, in: RoundedRectangle(cornerRadius: HERadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: HERadius.md)
                .strokeBorder(Color.heAccent.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Simulate

    private var simulateSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(title: "Device simulation", systemImage: "wand.and.stars")

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Toggle(isOn: Binding(
                        get: { env.forceSimulateDevice },
                        set: { env.forceSimulateDevice = $0 }
                    )) {
                        Text("Simulate device")
                            .font(.heBody)
                            .foregroundStyle(Color.heTextPrimary)
                    }
                    .tint(Color.hePrimary)

                    Text("Forces a synthetic Heartelfie peripheral with mock sensors, so the measurement tier works without hardware.")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Cloud

    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(title: "Cloud models", systemImage: "cloud")

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    configRow(
                        label: "Mock responses",
                        value: HeartelfieConfig.CloudAPI.useMockResponses ? "On" : "Off"
                    )
                    Text("When mock responses are on, cloud model calls return canned results instead of contacting the server. Toggle it in `HeartelfieConfig.CloudAPI.useMockResponses`.")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - BLE

    private var bleSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "BLE GATT profile",
                subtitle: "Service and characteristic UUIDs (read-only).",
                systemImage: "dot.radiowaves.left.and.right"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    uuidRow(label: "Service", uuid: HeartelfieConfig.BLE.serviceUUID)
                    Divider().overlay(Color.heSeparator)
                    uuidRow(label: "PPG stream", uuid: HeartelfieConfig.BLE.ppgStreamCharacteristic)
                    Divider().overlay(Color.heSeparator)
                    uuidRow(label: "Rhythm stream", uuid: HeartelfieConfig.BLE.ecgStreamCharacteristic)
                    Divider().overlay(Color.heSeparator)
                    uuidRow(label: "BioZ stream", uuid: HeartelfieConfig.BLE.bioZStreamCharacteristic)
                    Divider().overlay(Color.heSeparator)
                    uuidRow(label: "Battery", uuid: HeartelfieConfig.BLE.batteryCharacteristic)
                    Divider().overlay(Color.heSeparator)
                    uuidRow(label: "Contact status", uuid: HeartelfieConfig.BLE.contactStatusCharacteristic)
                    Divider().overlay(Color.heSeparator)
                    uuidRow(label: "Control", uuid: HeartelfieConfig.BLE.controlCharacteristic)
                    Divider().overlay(Color.heSeparator)
                    uuidRow(label: "Firmware", uuid: HeartelfieConfig.BLE.firmwareCharacteristic)
                }
            }
        }
    }

    // MARK: - Rows

    private func configRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.heBody)
                .foregroundStyle(Color.heTextSecondary)
            Spacer()
            Text(value)
                .font(.heBody.weight(.medium))
                .foregroundStyle(Color.heTextPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func uuidRow(label: String, uuid: String) -> some View {
        VStack(alignment: .leading, spacing: HESpacing.xxs) {
            Text(label)
                .font(.heCaption.weight(.semibold))
                .foregroundStyle(Color.heTextSecondary)
            Text(uuid)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.heTextPrimary)
                .textSelection(.enabled)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) U U I D \(uuid)")
    }
}

#Preview("Developer") {
    NavigationStack {
        DeveloperView()
            .environment(AppEnvironment.preview())
    }
}
