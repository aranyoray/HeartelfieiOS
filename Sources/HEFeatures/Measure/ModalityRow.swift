import SwiftUI
import HECore
import HEDesign

/// A rich picker row for a single `Modality` on the Measure screen: icon,
/// display name, honest one-line summary, tier badge, experimental qualifier,
/// supported-metric chips, and an explicit primary action.
///
/// Phone (screening) modalities start the capture flow directly. Device
/// (measurement) modalities that can't currently measure offer "Connect device"
/// instead, and every row links to a "What this does / doesn't mean" explainer so
/// the user is never left guessing what a reading means.
struct ModalityRow: View {
    let modality: Modality
    /// Whether this modality can be captured right now.
    let isAvailable: Bool

    private var isGatedDevice: Bool { modality.requiresDevice && !isAvailable }

    var body: some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                header
                summaryText
                metricsChips
                actionRow
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: HESpacing.md) {
            Image(systemName: modality.systemImage)
                .font(.title2)
                .foregroundStyle(Color.hePrimary)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: HESpacing.xs) {
                Text(modality.displayName)
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: HESpacing.xs) {
                    TierBadge(modality.tier, compact: true)
                    if modality.isExperimental {
                        ExperimentalChip()
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var summaryText: some View {
        Text(modality.summary)
            .font(.heCallout)
            .foregroundStyle(Color.heTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Metric chips

    @ViewBuilder
    private var metricsChips: some View {
        if !modality.supportedMetrics.isEmpty {
            VStack(alignment: .leading, spacing: HESpacing.xs) {
                Text("Measures")
                    .font(.heCaption.weight(.semibold))
                    .foregroundStyle(Color.heTextTertiary)

                MetricChipsFlow(metrics: modality.supportedMetrics)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Measures: " + modality.supportedMetrics
                .map(\.displayName)
                .joined(separator: ", "))
        }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: HESpacing.sm) {
            if isGatedDevice {
                NavigationLink(value: AppRoute.devicePairing) {
                    Label("Connect device", systemImage: "sensor.tag.radiowaves.forward.fill")
                        .font(.heCallout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HESpacing.sm)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint("Opens device pairing. This measurement needs the Heartelfie device.")
            } else {
                NavigationLink(value: AppRoute.capture(modality)) {
                    Label(startTitle, systemImage: "record.circle")
                        .font(.heCallout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HESpacing.sm)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityHint("Starts a \(modality.tier.shortLabel.lowercased()) with \(modality.displayName).")
            }

            NavigationLink(value: AppRoute.modalityInfo(modality)) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(Color.hePrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(Color.hePrimary.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("What this does and doesn't mean")
            .accessibilityHint("Explains \(modality.displayName).")
        }
    }

    private var startTitle: String {
        modality.tier == .measurement ? "Start measurement" : "Start screening"
    }
}

/// A simple wrapping flow layout of compact metric chips. Uses SwiftUI's native
/// `Layout` so chips wrap to the available width without a fixed column count.
struct MetricChipsFlow: View {
    let metrics: [MetricKind]

    var body: some View {
        FlowLayout(spacing: HESpacing.xs) {
            ForEach(metrics) { kind in
                MetricChip(kind: kind)
            }
        }
    }
}

/// A single compact, neutral chip naming a supported metric by its short name.
struct MetricChip: View {
    let kind: MetricKind

    var body: some View {
        HStack(spacing: HESpacing.xs) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 10, weight: .semibold))
                .accessibilityHidden(true)
            Text(kind.shortName)
                .font(.heCaption.weight(.medium))
        }
        .foregroundStyle(Color.heTextSecondary)
        .padding(.horizontal, HESpacing.sm)
        .padding(.vertical, HESpacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(Color.heSurfaceElevated)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.heSeparator, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.displayName)
    }
}

/// A lightweight wrapping layout: lays children left-to-right, wrapping to a new
/// row when the current row would overflow the proposed width.
struct FlowLayout: Layout {
    var spacing: CGFloat = HESpacing.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for element in row.elements {
                let size = subviews[element.index].sizeThatFits(.unspecified)
                subviews[element.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var elements: [(index: Int, width: CGFloat)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projected = current.elements.isEmpty ? size.width : current.width + spacing + size.width
            if !current.elements.isEmpty, projected > maxWidth {
                rows.append(current)
                current = Row()
            }
            let added = current.elements.isEmpty ? size.width : current.width + spacing + size.width
            current.elements.append((index, size.width))
            current.width = added
            current.height = max(current.height, size.height)
        }
        if !current.elements.isEmpty { rows.append(current) }
        return rows
    }
}

#Preview("Modality rows") {
    NavigationStack {
        ScrollView {
            VStack(spacing: HESpacing.md) {
                ModalityRow(modality: .fingerPPG, isAvailable: true)
                ModalityRow(modality: .facialRPPG, isAvailable: true)
                ModalityRow(modality: .deviceECG, isAvailable: false)
                ModalityRow(modality: .deviceMultiWavelengthPPG, isAvailable: true)
            }
            .padding()
        }
        .background(Color.heBackground)
    }
}
