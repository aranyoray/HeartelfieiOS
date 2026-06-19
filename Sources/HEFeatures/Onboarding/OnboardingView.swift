import SwiftUI
import HECore
import HEDesign

/// The multi-step onboarding host.
///
/// Drives a small step state machine (`OnboardingStep`) over five screens —
/// welcome, permission priming, skin-tone selection, optional health profile, and
/// consent — collecting everything into a shared `OnboardingDraft`. On the final
/// step it assembles a `HealthProfile` and calls
/// `AppEnvironment.completeOnboarding(_:)`.
///
/// Navigation is a calm Back / Continue pair plus a step progress bar. Transitions
/// respect Reduce Motion.
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: OnboardingStep = .welcome
    @State private var draft = OnboardingDraft()
    @State private var isFinishing = false

    init() {}

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(
                currentIndex: step.index,
                total: OnboardingStep.allCases.count
            )
            .padding(.horizontal, HESpacing.lg)
            .padding(.top, HESpacing.md)
            .padding(.bottom, HESpacing.sm)

            ScrollView {
                stepContent
                    .padding(.horizontal, HESpacing.lg)
                    .padding(.top, HESpacing.sm)
                    .padding(.bottom, HESpacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Re-identify so each step animates in cleanly.
                    .id(step)
                    .transition(stepTransition)
            }

            navigationBar
        }
        .background(Color.heBackground.ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            OnboardingWelcomeStep()
        case .permissions:
            OnboardingPermissionsStep()
        case .skinTone:
            OnboardingSkinToneStep(draft: draft)
        case .profile:
            OnboardingProfileStep(draft: draft)
        case .consent:
            OnboardingConsentStep(draft: draft)
        }
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: - Navigation bar

    private var navigationBar: some View {
        VStack(spacing: HESpacing.sm) {
            primaryControl

            if step != .welcome {
                Button(action: goBack) {
                    Text("Back")
                        .font(.heCallout.weight(.semibold))
                        .foregroundStyle(Color.heTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HESpacing.xs)
                }
                .accessibilityHint("Returns to the previous step")
            }
        }
        .padding(.horizontal, HESpacing.lg)
        .padding(.top, HESpacing.sm)
        .padding(.bottom, HESpacing.md)
        .background(
            Color.heBackground
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.heSeparator.opacity(0.6))
                        .frame(height: 1)
                }
        )
    }

    @ViewBuilder
    private var primaryControl: some View {
        if step == .consent {
            HEPrimaryButton(
                "Start using Heartelfie",
                systemImage: "heart.fill",
                isLoading: isFinishing
            ) {
                finish()
            }
            .disabled(!draft.hasAcceptedConsent || isFinishing)
            .accessibilityHint(
                draft.hasAcceptedConsent
                    ? "Saves your preferences and opens Heartelfie"
                    : "Accept the summary above to continue"
            )
        } else {
            HEPrimaryButton(step.primaryTitle, systemImage: "arrow.right") {
                goNext()
            }
        }
    }

    // MARK: - Transitions

    private func goNext() {
        guard let next = step.next else { return }
        step = next
    }

    private func goBack() {
        guard let previous = step.previous else { return }
        step = previous
    }

    private func finish() {
        guard draft.hasAcceptedConsent, !isFinishing else { return }
        isFinishing = true
        let profile = draft.makeProfile()
        Task {
            await env.completeOnboarding(profile)
            // On success `RootView` swaps this view out; reset the flag defensively
            // in case the view is still alive.
            isFinishing = false
        }
    }
}

/// The five onboarding steps, in order. Index/`next`/`previous` keep the host
/// view's navigation logic declarative.
enum OnboardingStep: Int, CaseIterable, Hashable, Identifiable {
    case welcome
    case permissions
    case skinTone
    case profile
    case consent

    var id: Int { rawValue }
    var index: Int { rawValue }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    /// Label for the forward button on non-final steps.
    var primaryTitle: String {
        switch self {
        case .welcome: return "Get started"
        case .permissions: return "Continue"
        case .skinTone: return "Continue"
        case .profile: return "Continue"
        case .consent: return "Start using Heartelfie"
        }
    }
}

/// A slim, accessible step progress bar. Conveys progress with both fill width and
/// a spoken "Step N of M" so it is never purely visual.
private struct OnboardingProgressBar: View {
    let currentIndex: Int
    let total: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        guard total > 1 else { return 1 }
        return Double(currentIndex + 1) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HESpacing.xs) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.heSeparator)
                    Capsule()
                        .fill(Color.hePrimaryGradient)
                        .frame(width: max(8, proxy.size.width * fraction))
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.25),
                            value: fraction
                        )
                }
            }
            .frame(height: 6)

            Text("Step \(currentIndex + 1) of \(total)")
                .font(.heCaption)
                .foregroundStyle(Color.heTextTertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Step \(currentIndex + 1) of \(total)")
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .environment(AppEnvironment.preview(onboarded: false))
}
