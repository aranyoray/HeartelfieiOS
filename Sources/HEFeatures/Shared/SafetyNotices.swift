import SwiftUI
import HECore
import HEDesign

/// The persistent emergency notice shown across the app. Calm, but unmissable.
public struct EmergencyNotice: View {
    public init() {}

    public var body: some View {
        HStack(alignment: .top, spacing: HESpacing.sm) {
            Image(systemName: "cross.case.fill")
                .foregroundStyle(Color.heRisk(.elevated))
                .accessibilityHidden(true)
            Text(Disclaimers.emergency)
                .font(.heCaption)
                .foregroundStyle(Color.heTextSecondary)
        }
        .padding(HESpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.heSurface, in: RoundedRectangle(cornerRadius: HERadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: HERadius.md)
                .strokeBorder(Color.heRisk(.elevated).opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Emergency notice. \(Disclaimers.emergency)")
    }
}

/// A compact, reusable non-diagnostic footer for result and detail screens.
public struct NonDiagnosticFooter: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.xs) {
            Label(Disclaimers.notDiagnostic, systemImage: "info.circle")
                .font(.heCaption)
                .foregroundStyle(Color.heTextSecondary)
            Text(Disclaimers.emergency)
                .font(.heCaption)
                .foregroundStyle(Color.heTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 16) {
        EmergencyNotice()
        NonDiagnosticFooter()
    }
    .padding()
}
