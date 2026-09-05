import UIKit
import CoreText

/// Lays out the guide text and renders the mask the scorer tests against.
///
/// Ported from TraceRight with one substantive change: the mask is indexed **per glyph**
/// (DESIGN_DOCUMENT.md §7), so every letter can be scored independently and a letter the
/// child never touched can score zero.
final class MaskRenderer {

    /// One scorable letter, positioned in canvas points with a top-left origin.
    struct GlyphBox {
        let charIndex: Int
        /// Which word this letter belongs to — the scorer only grades words the child
        /// has actually started (DESIGN_DOCUMENT §8.1).
        let wordIndex: Int
        /// Which laid-out line it sits on. The page renders line by line — graded lines
        /// lose their guide — and a tap selects a line, so line identity is load-bearing
        /// (WIREFRAME_SPEC.md §11.11).
        let lineIndex: Int
        let character: Character
        let rect: CGRect
        var isScorable: Bool { !character.isWhitespace }
        /// A letter or a digit — what counts towards a whole word's three letters (§8.3).
        var isAlphanumeric: Bool { character.isLetter || character.isNumber }
        var center: CGPoint { CGPoint(x: rect.midX, y: rect.midY) }
    }

    struct Layout {
        let baselines: [CGFloat]
        let glyphBoxes: [GlyphBox]
        let frameRect: CGRect
        let totalHeight: CGFloat
        let contentHeight: CGFloat
        let lineSpacing: CGFloat
        /// One band per line, spanning the text column: what the re-trace highlight is
        /// drawn behind and what a tap resolves to.
        let lineBands: [CGRect]
        /// Line -> indices into `glyphBoxes` of the scorable letters on it. Precomputed
        /// because the graded set is recomputed on every stroke.
        let scorableByLine: [Int: [Int]]

        var lineCount: Int { baselines.count }
        /// Letters the scorer cares about — whitespace is never scored.
        var scorableCount: Int { glyphBoxes.filter(\.isScorable).count }
        var wordCount: Int { (glyphBoxes.filter(\.isScorable).map(\.wordIndex).max()).map { $0 + 1 } ?? 0 }

        /// Word index -> the vertical band it occupies, so the view can scroll to it.
        func rect(forWord word: Int) -> CGRect? {
            let boxes = glyphBoxes.filter { $0.isScorable && $0.wordIndex == word }
            guard let first = boxes.first else { return nil }
            return boxes.dropFirst().reduce(first.rect) { $0.union($1.rect) }
        }

        func rect(forLine line: Int) -> CGRect? {
            lineBands.indices.contains(line) ? lineBands[line] : nil
        }

        /// Which line a point falls on. The gap between two lines belongs to the nearer
        /// of them, so no part of the page is dead to a tap.
        func lineIndex(at point: CGPoint) -> Int? {
            guard !baselines.isEmpty else { return nil }
            var best = 0
            var bestDistance = CGFloat.greatestFiniteMagnitude
            for (i, baseline) in baselines.enumerated() {
                let distance = abs(point.y - baseline)
                if distance < bestDistance { bestDistance = distance; best = i }
            }
            // Beyond a line's worth of slack the tap is off the text entirely.
            return bestDistance <= max(lineSpacing, 1) ? best : nil
        }

        /// Lines that carry at least one letter — a line of pure whitespace is not
        /// something the child can write, so it can never be graded or selected.
        var writableLines: Set<Int> { Set(scorableByLine.keys) }

        /// The character index just past the last glyph on a line — where the record ends
        /// when the child finishes that line (v2.5 §11.11).
        func endCharIndex(ofLine line: Int) -> Int? {
            let boxes = glyphBoxes.lazy.filter { $0.lineIndex == line }
            return boxes.map(\.charIndex).max().map { $0 + 1 }
        }

        /// The first line carrying any character at or past `index` — how the canvas maps
        /// the record/buffer boundary to a line. Everything before it is written.
        func firstLine(atOrAfterChar index: Int) -> Int {
            var best = lineCount
            for box in glyphBoxes where box.charIndex >= index {
                if box.lineIndex < best { best = box.lineIndex }
            }
            return best
        }

        /// The next line after `line` that has letters to write, if any.
        func nextWritableLine(after line: Int) -> Int? {
            scorableByLine.keys.filter { $0 > line }.min()
        }

        /// The word under a tap, with its character range and bounding box — what the
        /// fix-a-word gesture resolves to (v2.5 §11.13).
        func word(at point: CGPoint, slack: CGFloat = 10) -> (word: Int, range: ClosedRange<Int>, rect: CGRect)? {
            var hit: Int?
            var bestDistance = CGFloat.greatestFiniteMagnitude
            for box in glyphBoxes where box.isScorable {
                guard box.rect.insetBy(dx: -slack, dy: -slack).contains(point) else { continue }
                let d = hypot(point.x - box.center.x, point.y - box.center.y)
                if d < bestDistance { bestDistance = d; hit = box.wordIndex }
            }
            guard let word = hit else { return nil }
            let boxes = glyphBoxes.filter { $0.wordIndex == word && $0.isScorable }
            guard let lo = boxes.map(\.charIndex).min(), let hi = boxes.map(\.charIndex).max(),
                  let first = boxes.first else { return nil }
            let rect = boxes.dropFirst().reduce(first.rect) { $0.union($1.rect) }
            return (word, lo...hi, rect)
        }

        static let empty = Layout(baselines: [], glyphBoxes: [], frameRect: .zero,
                                  totalHeight: 0, contentHeight: 0, lineSpacing: 0,
                                  lineBands: [], scorableByLine: [:])
    }

    private(set) var pixelData: [UInt8] = []
    private(set) var width = 0
    private(set) var height = 0
    private(set) var scale: CGFloat = 1
    private(set) var layout = Layout.empty
    /// The exact outlines from the laid-out CoreText runs, one per advance box. Keeping
    /// these separate prevents ink on the next letter from passing this letter's test.
    private var glyphPaths: [Int: CGPath] = [:]

    func glyphPath(for index: Int) -> CGPath? { glyphPaths[index] }
    /// Kept so the visible guide is drawn from the *same* frame the mask came from —
    /// they cannot drift apart.
    private var ctFrame: CTFrame?
    private var topPadding: CGFloat = 0

    // MARK: - Generation

    @discardableResult
    func generate(text: String,
                  setup: WritingSetup,
                  canvasSize: CGSize,
                  inset: CGFloat = Tokens.Layout.surfaceInset,
                  topPadding: CGFloat = Tokens.Space.s7,
                  screenScale: CGFloat = UIScreen.main.scale,
                  layoutOnly: Bool = false,
                  alignment: NSTextAlignment = .left) -> Layout {

        scale = screenScale
        width = max(0, Int(canvasSize.width * screenScale))
        height = max(0, Int(canvasSize.height * screenScale))

        guard width > 0, height > 0, !text.isEmpty else {
            pixelData = []
            layout = .empty
            glyphPaths = [:]
            guideCaches = [:]
            return layout
        }

        let attributed = Self.attributedString(text: text, setup: setup, alignment: alignment)
        let textWidth = canvasSize.width - inset * 2
        let frameRect = CGRect(x: inset, y: 0, width: textWidth, height: canvasSize.height)
        let framePath = CGPath(rect: frameRect, transform: nil)

        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributed.length), framePath, nil)

        self.ctFrame = ctFrame
        self.topPadding = topPadding
        layout = Self.measure(frame: ctFrame,
                              text: text,
                              canvasHeight: canvasSize.height,
                              frameRect: frameRect,
                              topPadding: topPadding,
                              lineSpacing: Self.lineAdvance(for: setup))
        glyphPaths = Self.measureGlyphPaths(frame: ctFrame, text: text,
                                           canvasHeight: canvasSize.height,
                                           frameRect: frameRect, topPadding: topPadding)

        guideSource = GuideSource(text: text, setup: setup, frameRect: frameRect,
                                  canvasHeight: canvasSize.height, alignment: alignment)
        guideCaches = [:]
        if !layoutOnly {
            renderBitmap(frame: ctFrame, canvasSize: canvasSize, topPadding: topPadding, screenScale: screenScale)
        } else {
            pixelData = []
        }
        return layout
    }

    static func attributedString(text: String,
                                 setup: WritingSetup,
                                 colour: UIColor = .white,
                                 alignment: NSTextAlignment = .left) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: setup.uiFont(),
            .foregroundColor: colour,
            .paragraphStyle: paragraphStyle(for: setup, alignment: alignment),
        ])
    }

    /// What one line of this face at this size actually costs, top to top.
    ///
    /// `NSParagraphStyle.lineSpacing` is *added to* the face's own advance — ascent plus
    /// descent plus its built-in leading — not to the point size. Jua at 72 pt advances
    /// 90 pt on its own, so asking for `lineSpacing = 96 − 72` produced 114 pt lines while
    /// the ruled lines, the page height and the tap bands all still assumed 96. The page
    /// came out short by a line and a half, and the last line fell outside the frame where
    /// the child could not write it at all.
    ///
    /// So: ask the face what a line costs, top the difference up to the token, and if a
    /// face is too tall for the token, report the truth rather than the token. Everything
    /// that measures the page goes through here.
    static func lineAdvance(for setup: WritingSetup) -> CGFloat {
        max(setup.size.lineSpacing, naturalAdvance(for: setup))
    }

    /// Measured, not calculated. `CTFontGetAscent + Descent + Leading` is right for some
    /// faces and wrong for others — Comic Neue at 72 pt advances 112 pt while its metrics
    /// add up to 96 — so the only trustworthy answer is to lay two lines out and look at
    /// the gap between them.
    private static func naturalAdvance(for setup: WritingSetup) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let sample = NSAttributedString(string: "Ag\nAg", attributes: [
            .font: setup.uiFont(),
            .paragraphStyle: paragraph,
        ])
        let framesetter = CTFramesetterCreateWithAttributedString(sample)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: 4000, height: 4000), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, sample.length), path, nil)
        let lines = CTFrameGetLines(frame) as! [CTLine]
        guard lines.count >= 2 else { return setup.size.lineSpacing }
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)
        return max(1, origins[0].y - origins[1].y)
    }

    /// `alignment` is the journal page's `.left` everywhere but the remediation modal,
    /// whose one-letter sheet centres so the letter does not huddle at the left edge.
    /// The measured glyph boxes and the drawn guide both follow the frame's own line
    /// origins, so a centred line scores exactly where it is drawn.
    static func paragraphStyle(for setup: WritingSetup,
                               alignment: NSTextAlignment = .left) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = max(0, setup.size.lineSpacing - naturalAdvance(for: setup))
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = alignment
        return paragraph
    }

    // MARK: - Per-glyph measurement

    private static func measureGlyphPaths(frame: CTFrame, text: String,
                                          canvasHeight: CGFloat, frameRect: CGRect,
                                          topPadding: CGFloat) -> [Int: CGPath] {
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)
        let characterIndices = utf16ToCharacterIndex(text)
        var measured: [(character: Int, path: CGPath?)] = []
        for (lineIndex, line) in lines.enumerated() {
            let baseline = canvasHeight - origins[lineIndex].y + topPadding
            let lineX = frameRect.minX + origins[lineIndex].x
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let count = CTRunGetGlyphCount(run)
                guard count > 0 else { continue }
                let attributes = CTRunGetAttributes(run) as NSDictionary
                guard let rawFont = attributes[kCTFontAttributeName] else { continue }
                let font = rawFont as! CTFont
                var glyphs = [CGGlyph](repeating: 0, count: count)
                var positions = [CGPoint](repeating: .zero, count: count)
                var advances = [CGSize](repeating: .zero, count: count)
                var indices = [CFIndex](repeating: 0, count: count)
                CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
                CTRunGetPositions(run, CFRangeMake(0, 0), &positions)
                CTRunGetAdvances(run, CFRangeMake(0, 0), &advances)
                CTRunGetStringIndices(run, CFRangeMake(0, 0), &indices)
                for i in 0..<count where advances[i].width > 0 {
                    guard let character = characterIndices[indices[i]] else { continue }
                    var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
                                                     tx: lineX + positions[i].x,
                                                     ty: baseline - positions[i].y)
                    let path = CTFontCreatePathForGlyph(font, glyphs[i], &transform)
                    measured.append((character, path))
                }
            }
        }
        measured.sort { $0.character < $1.character }
        return Dictionary(uniqueKeysWithValues: measured.enumerated().compactMap { index, item in
            item.path.map { (index, $0) }
        })
    }

    private static func measure(frame ctFrame: CTFrame,
                                text: String,
                                canvasHeight: CGFloat,
                                frameRect: CGRect,
                                topPadding: CGFloat,
                                lineSpacing: CGFloat) -> Layout {

        let lines = CTFrameGetLines(ctFrame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), &origins)

        // Map UTF-16 offsets back to Character indices once.
        let utf16ToChar = Self.utf16ToCharacterIndex(text)
        let characters = Array(text)
        let wordOfChar = Self.wordIndexPerCharacter(characters)

        var baselines: [CGFloat] = []
        var bands: [CGRect] = []
        var boxes: [GlyphBox] = []

        for (lineIndex, line) in lines.enumerated() {
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

            // CoreText origins are bottom-left; convert to a top-left baseline.
            let baseline = canvasHeight - origins[lineIndex].y + topPadding
            baselines.append(baseline)
            bands.append(CGRect(x: frameRect.minX, y: baseline - ascent,
                                width: frameRect.width, height: ascent + descent))

            // CTFrameGetLineOrigins returns x relative to the frame path, so the path's
            // own inset has to be added back. Without this every glyph box sits one
            // surface-inset to the left of its ink and per-letter attribution is wrong.
            let lineX = frameRect.minX + origins[lineIndex].x
            guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { continue }

            for run in runs {
                let glyphCount = CTRunGetGlyphCount(run)
                guard glyphCount > 0 else { continue }

                var positions = [CGPoint](repeating: .zero, count: glyphCount)
                var advances  = [CGSize](repeating: .zero, count: glyphCount)
                var indices   = [CFIndex](repeating: 0, count: glyphCount)
                CTRunGetPositions(run, CFRangeMake(0, glyphCount), &positions)
                CTRunGetAdvances(run, CFRangeMake(0, glyphCount), &advances)
                CTRunGetStringIndices(run, CFRangeMake(0, glyphCount), &indices)

                for g in 0..<glyphCount {
                    let utf16Index = Int(indices[g])
                    guard let charIndex = utf16ToChar[utf16Index], charIndex < characters.count else { continue }
                    let advance = advances[g].width
                    guard advance > 0 else { continue }
                    let rect = CGRect(x: lineX + positions[g].x,
                                      y: baseline - ascent,
                                      width: advance,
                                      height: ascent + descent)
                    boxes.append(GlyphBox(charIndex: charIndex,
                                          wordIndex: wordOfChar[charIndex],
                                          lineIndex: lineIndex,
                                          character: characters[charIndex],
                                          rect: rect))
                }
            }
        }

        boxes.sort { $0.charIndex < $1.charIndex }
        var scorableByLine: [Int: [Int]] = [:]
        for (i, box) in boxes.enumerated() where box.isScorable {
            scorableByLine[box.lineIndex, default: []].append(i)
        }
        let deepest = boxes.map(\.rect.maxY).max() ?? (baselines.last ?? 0)
        return Layout(baselines: baselines, glyphBoxes: boxes, frameRect: frameRect,
                      totalHeight: baselines.last ?? 0, contentHeight: deepest,
                      lineSpacing: lineSpacing, lineBands: bands, scorableByLine: scorableByLine)
    }

    /// Word index for every character, counting runs separated by whitespace.
    private static func wordIndexPerCharacter(_ characters: [Character]) -> [Int] {
        var out: [Int] = []
        out.reserveCapacity(characters.count)
        var word = 0
        var inWord = false
        for character in characters {
            if character.isWhitespace {
                if inWord { word += 1; inWord = false }
                out.append(word)      // never scored, but keeps the array aligned
            } else {
                inWord = true
                out.append(word)
            }
        }
        return out
    }

    /// How many lines the text needs at this width — measured, never guessed, because the
    /// bundled faces differ by up to 40% in advance width.
    static func lineCount(text: String, setup: WritingSetup, width: CGFloat) -> Int {
        guard !text.isEmpty, width > 0 else { return 0 }
        let attributed = attributedString(text: text, setup: setup)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude), transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributed.length), path, nil)
        return (CTFrameGetLines(frame) as! [CTLine]).count
    }

    /// Height the scrolling page needs for this text.
    ///
    /// The trailing `space-7` is not decoration: a frame sized to the last descender drops
    /// the last line, so the page always carries one clear line of slack beneath the text.
    static func contentHeight(text: String, setup: WritingSetup, width: CGFloat,
                              topPadding: CGFloat = Tokens.Space.s7) -> CGFloat {
        let lines = max(1, lineCount(text: text, setup: setup, width: width))
        return topPadding + CGFloat(lines + 1) * lineAdvance(for: setup) + Tokens.Space.s7
    }

    private static func utf16ToCharacterIndex(_ text: String) -> [Int: Int] {
        var map: [Int: Int] = [:]
        var utf16Offset = 0
        for (charIndex, character) in text.enumerated() {
            let width = String(character).utf16.count
            for step in 0..<width { map[utf16Offset + step] = charIndex }
            utf16Offset += width
        }
        return map
    }

    // MARK: - Bitmap

    private func renderBitmap(frame ctFrame: CTFrame, canvasSize: CGSize, topPadding: CGFloat, screenScale: CGFloat) {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            pixelData = []
            return
        }

        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: screenScale, y: screenScale)
        // CoreText draws bottom-up; shift by the same top padding the layout used.
        context.translateBy(x: 0, y: -topPadding)
        CTFrameDraw(ctFrame, context)

        if let data = context.data {
            let buffer = data.bindMemory(to: UInt8.self, capacity: width * height)
            pixelData = Array(UnsafeBufferPointer(start: buffer, count: width * height))
        } else {
            pixelData = [UInt8](repeating: 0, count: width * height)
        }
    }

    /// Draws the guide text in the given colour, one line at a time.
    ///
    /// Built from the same text, setup and frame path as the mask, so the letters the
    /// child sees and the letters the scorer tests against cannot drift apart.
    ///
    /// `alphaForLine` is how the line states of WIREFRAME_SPEC.md §11.11 are drawn: a
    /// written line returns 0 and loses its guide entirely, a line mid-settle returns a
    /// fading value, and everything else returns 1.
    func drawGuide(in context: CGContext,
                   colour: UIColor,
                   alphaForLine: ((Int) -> CGFloat)? = nil) {
        drawGuide(in: context) { line in
            let alpha = alphaForLine?(line) ?? 1
            return alpha > 0.004 ? (colour, alpha) : nil
        }
    }

    /// v2.5 — every line carries its own colour as well as its own alpha, because the
    /// page has two text tiers at once: `guide-text` on the line in hand and
    /// `spoken-text` below it. Returning nil skips the line.
    func drawGuide(in context: CGContext,
                   style: (Int) -> (colour: UIColor, alpha: CGFloat)?) {
        guard let source = guideSource else { return }

        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: source.canvasHeight)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: 0, y: -topPadding)
        for i in 0..<layout.lineCount {
            guard let (colour, alpha) = style(i), alpha > 0.004,
                  let guide = guideLines(colour: colour), i < guide.lines.count else { continue }
            context.saveGState()
            if alpha < 1 { context.setAlpha(alpha) }
            context.textPosition = CGPoint(x: source.frameRect.minX + guide.origins[i].x,
                                           y: guide.origins[i].y)
            CTLineDraw(guide.lines[i], context)
            context.restoreGState()
        }
        context.restoreGState()
    }

    /// The guide is laid out once per colour and reused — the page draws two colours per
    /// frame (guide and spoken), and rebuilding a framesetter at 60 fps is not free.
    private func guideLines(colour: UIColor) -> GuideCache? {
        if let cached = guideCaches[colour.description] { return cached }
        guard let source = guideSource else { return nil }
        let attributed = Self.attributedString(text: source.text, setup: source.setup,
                                               colour: colour, alignment: source.alignment)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: source.frameRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributed.length), path, nil)
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)
        let cache = GuideCache(colour: colour, frame: frame, lines: lines, origins: origins)
        guideCaches[colour.description] = cache
        return cache
    }

    private struct GuideCache {
        let colour: UIColor
        let frame: CTFrame
        let lines: [CTLine]
        let origins: [CGPoint]
    }
    private var guideCaches: [String: GuideCache] = [:]

    /// v3.1 — the practice sheet's completed letters: a colour per character, the rest
    /// in `colour`. Same text, setup and frame path as the mask with only the colour
    /// attribute varying, so every glyph lands exactly where the scorer thinks it is.
    /// `colourForCharacter` takes the UTF-16 index the glyph boxes carry as `charIndex`.
    func drawGuide(in context: CGContext, colour: UIColor, colourForCharacter: (Int) -> UIColor?) {
        guard let source = guideSource else { return }
        let length = (source.text as NSString).length
        var overrides: [(index: Int, colour: UIColor)] = []
        for i in 0..<length {
            if let override = colourForCharacter(i) { overrides.append((i, override)) }
        }
        guard !overrides.isEmpty else { drawGuide(in: context, colour: colour); return }

        let key = [source.text, source.setup.face.id, "\(source.setup.size.size)", "\(source.frameRect)",
                   colour.description,
                   overrides.map { "\($0.index):\($0.colour.description)" }.joined(separator: ",")]
            .joined(separator: "|")
        let guide: GuideCache
        if let cached = overrideCache, cached.key == key {
            guide = cached.guide
        } else {
            let attributed = NSMutableAttributedString(
                attributedString: Self.attributedString(text: source.text, setup: source.setup,
                                                        colour: colour, alignment: source.alignment))
            for item in overrides {
                attributed.addAttribute(.foregroundColor, value: item.colour,
                                        range: NSRange(location: item.index, length: 1))
            }
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let path = CGPath(rect: source.frameRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributed.length), path, nil)
            let lines = CTFrameGetLines(frame) as! [CTLine]
            var origins = [CGPoint](repeating: .zero, count: lines.count)
            CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)
            guide = GuideCache(colour: colour, frame: frame, lines: lines, origins: origins)
            overrideCache = (key, guide)
        }

        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: source.canvasHeight)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: 0, y: -topPadding)
        for i in 0..<min(layout.lineCount, guide.lines.count) {
            context.textPosition = CGPoint(x: source.frameRect.minX + guide.origins[i].x,
                                           y: guide.origins[i].y)
            CTLineDraw(guide.lines[i], context)
        }
        context.restoreGState()
    }

    /// Only the latest per-character variant is kept — the sheet's completed set changes
    /// a few dozen times a day at most — and its key carries the text and frame, so a
    /// stale entry can never match a new layout.
    private var overrideCache: (key: String, guide: GuideCache)?

    private struct GuideSource {
        let text: String
        let setup: WritingSetup
        let frameRect: CGRect
        let canvasHeight: CGFloat
        let alignment: NSTextAlignment
    }
    private var guideSource: GuideSource?

    // MARK: - Queries

    /// Whether the scoring bitmap is present. `generate(layoutOnly:)` produces the layout
    /// without it, and every ink query below reads false until it is put back.
    var hasBitmap: Bool { !pixelData.isEmpty }

    func isLetterPixel(x: Int, y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        let index = y * width + x
        guard index < pixelData.count else { return false }
        return pixelData[index] > 127
    }

    /// True when the point falls on ink, allowing a circular tolerance in points.
    func isInsideLetter(point: CGPoint, tolerance: CGFloat) -> Bool {
        let px = Int(point.x * scale)
        let py = Int(point.y * scale)
        let t = Int((tolerance * scale).rounded())
        if t <= 0 { return isLetterPixel(x: px, y: py) }
        let t2 = t * t
        for dx in -t...t {
            for dy in -t...t where dx * dx + dy * dy <= t2 {
                if isLetterPixel(x: px + dx, y: py + dy) { return true }
            }
        }
        return false
    }

    /// Which letter the child was aiming at. Nearest scorable glyph whose box — inflated
    /// by `slack` — contains the point; ties break on distance to centre.
    func glyphIndex(at point: CGPoint, slack: CGFloat = 12, onLine: Int? = nil) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for (i, box) in layout.glyphBoxes.enumerated() where box.isScorable {
            if let onLine, box.lineIndex != onLine { continue }
            // Cheap vertical reject first: re-attributing a whole page after an append
            // walks every point past every glyph, and most of them are lines away.
            guard point.y >= box.rect.minY - slack, point.y <= box.rect.maxY + slack else { continue }
            let inflated = box.rect.insetBy(dx: -slack, dy: -slack)
            guard inflated.contains(point) else { continue }
            let d = hypot(point.x - box.center.x, point.y - box.center.y)
            if best == nil || d < best!.distance { best = (i, d) }
        }
        return best?.index
    }
}
