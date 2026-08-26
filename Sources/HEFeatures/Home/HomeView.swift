import SwiftUI
import HECore
import HEDesign

/// The Home dashboard: a glanceable, scrollable overview of the day's cardio
/// wellness. Shows today's score ring, the daily-check streak, quick-start tiles
/// for phone screenings, recent readings, and the always-present emergency notice.
///
/// All copy is wellness-grade and explicitly non-diagnostic. Phone modalities are
/// screenings, not medical measurements.
struct HomeView: View {
    @Environment(AppEnvironment.self) private var env

    private let gridColumns = [
        GridItem(.flexible(), spacing: HESpacing.md),
        GridItem(.flexible(), spacing: HESpacing.md)
    ]

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                greetingHeader
                snapshotSection
                HomeTrendsCard()
                StreakCard(streak: env.streak, recentReadings: env.recentReadings)
                quickStartSection
                recentReadingsSection
                insightsLink
                EmergencyNotice()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle("DailyDil")
        .navigationBarTitleDisplayMode(.inline)
        .task { await env.refreshDashboard() }
        .refreshable { await env.refreshDashboard() }
    }

    // MARK: - Greeting

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: HESpacing.xxs) {
            Text(greeting)
                .font(.heLargeTitle)
                .foregroundStyle(Color.heTextPrimary)
            Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.heCallout)
                .foregroundStyle(Color.heTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Time-of-day greeting. No name is stored in the lean health profile, so this
    /// stays warm but generic.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    // MARK: - Today's snapshot

    private var snapshotSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Today's snapshot",
                subtitle: "A soft, non-diagnostic roll-up of today's checks.",
                systemImage: "heart.text.square.fill"
            )

            HECard {
                VStack(spacing: HESpacing.md) {
                    ScoreRing(score: env.todayScore)
                        .frame(maxWidth: 260)
                        .frame(height: 260)
                        .frame(maxWidth: .infinity)

                    if env.todayScore.contributingReadings == 0 {
                        Text("Take your first check today to see your score.")
                            .font(.heCallout)
                            .foregroundStyle(Color.heTextSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("From \(env.todayScore.contributingReadings) \(env.todayScore.contributingReadings == 1 ? "check" : "checks") today.")
                            .font(.heCaption)
                            .foregroundStyle(Color.heTextTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Quick start

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Quick start",
                subtitle: "Phone checks are wellness screenings — not medical measurements.",
                systemImage: "bolt.heart.fill"
            )

            LazyVGrid(columns: gridColumns, spacing: HESpacing.md) {
                ForEach(Modality.allCases) { modality in
                    QuickStartTile(modality: modality)
                }
            }
        }
    }

    // MARK: - Recent readings

    private var recentReadingsSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Recent readings",
                systemImage: "clock.arrow.circlepath"
            )

            if env.recentReadings.isEmpty {
                HECard {
                    EmptyStateView(
                        systemImage: "waveform.path.ecg",
                        title: "No readings yet",
                        message: "Your recent checks will appear here. Start with a quick finger-PPG screening above."
                    )
                }
            } else {
                VStack(spacing: HESpacing.md) {
                    ForEach(env.recentReadings) { reading in
                        RecentReadingRow(reading: reading)
                    }
                }
            }
        }
    }

    // MARK: - Insights link

    private var insightsLink: some View {
        NavigationLink(value: AppRoute.insights) {
            HStack(spacing: HESpacing.md) {
                Image(systemName: "lightbulb.max.fill")
                    .font(.heHeadline)
                    .foregroundStyle(Color.hePrimary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: HESpacing.xxs) {
                    Text("Insights")
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                    Text("Daily summary, trend callouts, and wellness notices.")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: HESpacing.sm)

                Image(systemName: "chevron.right")
                    .font(.heCaption.weight(.semibold))
                    .foregroundStyle(Color.heTextTertiary)
                    .accessibilityHidden(true)
            }
            .padding(HESpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                    .fill(Color.heSurface)
            )
            .heSubtleShadow()
            .contentShape(RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Insights. Daily summary, trend callouts, and wellness notices.")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Home") {
    NavigationStack {
        HomeView()
            .environment(AppEnvironment.preview())
    }
}
