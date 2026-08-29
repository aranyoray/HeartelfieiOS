import Foundation
import HECore

#if canImport(UIKit)
import UIKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif

/// Exports DailyDil readings for full data portability (CSV + PDF).
///
/// CSV is one row per metric per reading; PDF is a clean, human-readable summary.
/// Both always carry the non-diagnostic disclaimers (`Disclaimers.notDiagnostic`
/// and `Disclaimers.emergency`). PDF rendering uses `UIGraphicsPDFRenderer`
/// (iOS); on platforms without UIKit/PDFKit it returns empty `Data()` so the
/// module always builds.
public struct ReadingExporter: Sendable {

    public init() {}

    // MARK: - CSV

    /// CSV columns, in order.
    private static let csvHeader = [
        "timestamp", "modality", "tier", "metric", "value", "unit",
        "risk", "confidence", "provenance"
    ]

    /// Renders readings to CSV: a header row plus one row per metric per reading.
    /// Fields are RFC-4180 quoted/escaped. Readings are sorted newest-first.
    public func csv(readings: [CardioReading]) -> String {
        var rows: [String] = []
        rows.append(Self.csvHeader.joined(separator: ","))

        let sorted = readings.sorted { $0.timestamp > $1.timestamp }
        let formatter = ISO8601DateFormatter()

        for reading in sorted {
            let timestamp = formatter.string(from: reading.timestamp)
            let modality = reading.modality.displayName
            let tier = reading.tier.shortLabel
            let confidence = reading.confidence.percentString
            let provenance = reading.provenance.shortLabel

            // Emit one line per metric so each value is independently analysable.
            let metrics = reading.metrics
            if metrics.isEmpty {
                // Still emit a single row so a metric-less reading isn't lost.
                let fields = [timestamp, modality, tier, "", "", "", reading.overallRisk.displayName, confidence, provenance]
                rows.append(fields.map(Self.escapeCSV).joined(separator: ","))
            } else {
                for metric in metrics {
                    let fields = [
                        timestamp, modality, tier,
                        metric.kind.displayName,
                        metric.exportValue,
                        metric.unit,
                        metric.risk.displayName,
                        confidence,
                        provenance
                    ]
                    rows.append(fields.map(Self.escapeCSV).joined(separator: ","))
                }
            }
        }
        return rows.joined(separator: "\n")
    }

    /// RFC-4180 escaping: wrap in quotes if the field contains a comma, quote, or
    /// newline, doubling any embedded quotes.
    private static func escapeCSV(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - PDF

    /// Renders a simple, clean PDF summary of the readings, with the profile (if
    /// any) and the non-diagnostic disclaimer footer. Returns empty `Data()` where
    /// UIKit/PDFKit is unavailable.
    public func pdf(readings: [CardioReading], profile: HealthProfile?) -> Data {
        #if canImport(UIKit) && canImport(PDFKit)
        return Self.renderPDF(readings: readings, profile: profile)
        #else
        // Stub: PDF rendering needs UIKit/PDFKit (iOS). Other platforms get empty.
        return Data()
        #endif
    }

    // MARK: - File convenience

    /// Writes CSV to `url` (UTF-8). Export files carry full data-protection so
    /// they stay encrypted at rest until they're shared or cleaned up.
    public func writeCSV(_ readings: [CardioReading], to url: URL) throws {
        let text = csv(readings: readings)
        try text.data(using: .utf8)?.write(to: url, options: [.atomic, .completeFileProtection])
    }

    /// Writes a PDF summary to `url` (same protection as ``writeCSV(_:to:)``).
    public func writePDF(_ readings: [CardioReading], profile: HealthProfile?, to url: URL) throws {
        let data = pdf(readings: readings, profile: profile)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}

// MARK: - PDF rendering (iOS)

#if canImport(UIKit) && canImport(PDFKit)
extension ReadingExporter {

    /// US-Letter page geometry and layout constants.
    private enum Layout {
        static let pageWidth: CGFloat = 612   // 8.5"
        static let pageHeight: CGFloat = 792  // 11"
        static let margin: CGFloat = 48
        static let bottomReserve: CGFloat = 96 // space kept for the footer
        static var contentWidth: CGFloat { pageWidth - margin * 2 }
    }

    private static func renderPDF(readings: [CardioReading], profile: HealthProfile?) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: Layout.pageWidth, height: Layout.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let sorted = readings.sorted { $0.timestamp > $1.timestamp }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        return renderer.pdfData { context in
            context.beginPage()
            var cursorY = Layout.margin

            cursorY = drawText(
                "\(DailyDilConfig.appName) — Health Export",
                at: cursorY, font: .boldSystemFont(ofSize: 22)
            )
            cursorY += 4
            cursorY = drawText(
                "Generated \(dateFormatter.string(from: Date()))",
                at: cursorY, font: .systemFont(ofSize: 11), color: .secondaryLabel
            )
            cursorY += 8

            // Profile summary (minimal PII).
            if let profile {
                cursorY = drawText("Profile", at: cursorY, font: .boldSystemFont(ofSize: 14))
                cursorY = drawText(profileSummary(profile), at: cursorY, font: .systemFont(ofSize: 11), color: .secondaryLabel)
                cursorY += 8
            }

            cursorY = drawText(
                "Readings (\(sorted.count))",
                at: cursorY, font: .boldSystemFont(ofSize: 14)
            )
            cursorY += 4

            // Per-reading blocks; start a new page when we run low on space.
            for reading in sorted {
                let block = readingBlock(reading, dateFormatter: dateFormatter)
                let needed = block.height(constrainedToWidth: Layout.contentWidth) + 14
                if cursorY + needed > Layout.pageHeight - Layout.bottomReserve {
                    drawFooter(in: context)
                    context.beginPage()
                    cursorY = Layout.margin
                }
                cursorY = drawAttributed(block, at: cursorY)
                cursorY += 10
            }

            // Footer (disclaimers) on the final page.
            drawFooter(in: context)
        }
    }

    /// Builds the multi-line attributed block for one reading.
    private static func readingBlock(_ reading: CardioReading, dateFormatter: DateFormatter) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.label
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.label
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.secondaryLabel
        ]

        result.append(NSAttributedString(
            string: "\(dateFormatter.string(from: reading.timestamp)) · \(reading.modality.displayName) · \(reading.tier.shortLabel)\n",
            attributes: titleAttrs
        ))

        let metrics = reading.metrics
        if metrics.isEmpty {
            result.append(NSAttributedString(string: "No metrics.\n", attributes: bodyAttrs))
        } else {
            for metric in metrics {
                let line = "• \(metric.kind.displayName): \(metric.formattedValueWithUnit)  [\(metric.risk.displayName)]\n"
                result.append(NSAttributedString(string: line, attributes: bodyAttrs))
            }
        }

        result.append(NSAttributedString(
            string: "Confidence \(reading.confidence.percentString) · \(reading.provenance.shortLabel) · \(reading.provenance.engine.displayName)\n",
            attributes: subAttrs
        ))
        return result
    }

    private static func profileSummary(_ profile: HealthProfile) -> String {
        var parts: [String] = []
        if let age = profile.age { parts.append("Age \(age)") }
        if let sex = profile.biologicalSex { parts.append(sex.displayName) }
        if let height = profile.heightCM { parts.append("Height \(Int(height)) cm") }
        if let weight = profile.weightKG { parts.append("Weight \(Int(weight)) kg") }
        if !profile.knownConditions.isEmpty {
            parts.append("Conditions: \(profile.knownConditions.joined(separator: ", "))")
        }
        return parts.isEmpty ? "Not provided." : parts.joined(separator: " · ")
    }

    // MARK: Drawing primitives

    @discardableResult
    private static func drawText(
        _ string: String,
        at y: CGFloat,
        font: UIFont,
        color: UIColor = .label
    ) -> CGFloat {
        let attributed = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        return drawAttributed(attributed, at: y)
    }

    /// Draws an attributed string at the left margin and returns the new Y.
    @discardableResult
    private static func drawAttributed(_ attributed: NSAttributedString, at y: CGFloat) -> CGFloat {
        let height = attributed.height(constrainedToWidth: Layout.contentWidth)
        let rect = CGRect(x: Layout.margin, y: y, width: Layout.contentWidth, height: height)
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin], context: nil)
        return y + height
    }

    /// Draws the mandatory non-diagnostic + emergency disclaimers near the page
    /// bottom.
    private static func drawFooter(in context: UIGraphicsPDFRendererContext) {
        let footer = "\(Disclaimers.notDiagnostic)\n\(Disclaimers.emergency)"
        let attributed = NSAttributedString(
            string: footer,
            attributes: [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        let height = attributed.height(constrainedToWidth: Layout.contentWidth)
        let y = Layout.pageHeight - Layout.margin - height
        let rect = CGRect(x: Layout.margin, y: y, width: Layout.contentWidth, height: height)
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin], context: nil)
    }
}

private extension NSAttributedString {
    /// Measures the rendered height for a given wrapping width.
    func height(constrainedToWidth width: CGFloat) -> CGFloat {
        let bounding = boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(bounding.height)
    }
}
#endif
