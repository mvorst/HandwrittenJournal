import UIKit
import PDFKit

/// DESIGN_DOCUMENT.md §4.8. One page per session, oldest first, with a cover.
///
/// The book is the reason the app keeps five years of ink. Rendered entirely on device.
enum PDFBookBuilder {

    struct Options {
        var includeTypedWords = true
        var includeAccuracy = false
        var childName = ""
    }

    static let pageSize = CGSize(width: 612, height: 792)   // US Letter at 72 dpi

    static func build(sessions: [WritingSession], options: Options) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let ordered = sessions.filter(\.hasWriting).sorted { $0.startedAt < $1.startedAt }

        return renderer.pdfData { ctx in
            if ordered.count > 1 { drawCover(ctx, sessions: ordered, options: options) }
            for session in ordered {
                ctx.beginPage()
                draw(session: session, in: ctx.cgContext, options: options)
            }
            if ordered.isEmpty { ctx.beginPage() }
        }
    }

    // MARK: - Pages

    private static func drawCover(_ ctx: UIGraphicsPDFRendererContext, sessions: [WritingSession], options: Options) {
        ctx.beginPage()
        let margin: CGFloat = 56
        let title = "\(options.childName)'s Journal"
        title.draw(at: CGPoint(x: margin, y: margin), withAttributes: [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: UIColor(Tokens.Colour.textPrimary),
        ])
        let first = sessions.first?.startedAt ?? .now
        let last = sessions.last?.startedAt ?? .now
        let range = "\(first.formatted(.dateTime.month(.wide).year())) – \(last.formatted(.dateTime.month(.wide).year()))"
        let words = sessions.reduce(0) { $0 + $1.wordsWritten }
        "\(range)  ·  \(sessions.count) entries  ·  \(words) words".draw(
            at: CGPoint(x: margin, y: margin + 44),
            withAttributes: [.font: UIFont.systemFont(ofSize: 13),
                             .foregroundColor: UIColor(Tokens.Colour.textSecondary)])
        rule(ctx.cgContext, y: margin + 76, margin: margin)
    }

    private static func draw(session: WritingSession, in context: CGContext, options: Options) {
        let margin: CGFloat = 56
        let contentWidth = pageSize.width - margin * 2
        var y = margin

        session.displayDate.draw(at: CGPoint(x: margin, y: y), withAttributes: [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor(Tokens.Colour.textPrimary),
        ])
        y += 26
        var subtitle = session.setup.shortSummary
        if !options.childName.isEmpty { subtitle = "\(options.childName)  ·  " + subtitle }
        subtitle.draw(at: CGPoint(x: margin, y: y), withAttributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(Tokens.Colour.textSecondary),
        ])
        y += 24
        rule(context, y: y, margin: margin)
        y += 24

        if let data = session.strokeArchive,
           let strokes = try? StrokeArchive.decode(data), !strokes.isEmpty {
            var bounds = strokes[0].bounds()
            for stroke in strokes.dropFirst() { bounds = bounds.union(stroke.bounds()) }
            bounds = bounds.insetBy(dx: -6, dy: -6)

            if bounds.width > 0, bounds.height > 0 {
                let available = pageSize.height - margin - 60 - y
                let scale = min(contentWidth / bounds.width, available / bounds.height)
                context.saveGState()
                context.translateBy(x: margin - bounds.minX * scale, y: y - bounds.minY * scale)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.setStrokeColor(UIColor(Tokens.Colour.inkNatural).cgColor)
                for stroke in strokes where stroke.points.count > 1 {
                    for i in 1..<stroke.points.count {
                        let a = stroke.points[i - 1], b = stroke.points[i]
                        let force = (a.force + b.force) / 2
                        context.setLineWidth(max(0.3, (1.5 + 3.5 * force) * scale))
                        context.move(to: CGPoint(x: a.location.x * scale, y: a.location.y * scale))
                        context.addLine(to: CGPoint(x: b.location.x * scale, y: b.location.y * scale))
                        context.strokePath()
                    }
                }
                context.restoreGState()
                y += bounds.height * scale + 18
            }
        }

        if options.includeTypedWords {
            y = min(y + 8, pageSize.height - margin - 90)
            rule(context, y: y, margin: margin); y += 14
            let caption = "\u{201C}\(session.transcript)\u{201D}"
                + (options.includeAccuracy ? "   \(session.accuracyPercent)%" : "")
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor(Tokens.Colour.textSecondary),
            ]
            (caption as NSString).draw(with: CGRect(x: margin, y: y, width: contentWidth, height: 60),
                                       options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                       attributes: attributes,
                                       context: nil)
        }

        rule(context, y: pageSize.height - margin - 20, margin: margin)
        "Handwritten Journal".draw(at: CGPoint(x: margin, y: pageSize.height - margin - 12),
                                   withAttributes: [.font: UIFont.systemFont(ofSize: 9),
                                                    .foregroundColor: UIColor(Tokens.Colour.textSecondary)])
    }

    private static func rule(_ context: CGContext, y: CGFloat, margin: CGFloat) {
        context.setStrokeColor(UIColor(Tokens.Colour.divider).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
        context.strokePath()
    }
}
