import SwiftUI
import HEDesign

/// Developer-only notice confirming this is a demo build.
struct DeveloperView: View {
    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
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
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Developer") {
    NavigationStack {
        DeveloperView()
    }
}
