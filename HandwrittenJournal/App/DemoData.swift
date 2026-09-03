#if DEBUG
import SwiftUI
import SwiftData

/// Screenshot and manual-testing harness. DEBUG only — never compiled into a release.
///
///     xcrun simctl launch <device> <bundle-id> -seed YES -screen home
enum DemoData {

    static var wantsSeed: Bool { UserDefaults.standard.bool(forKey: "seed") }
    static var screen: String? { UserDefaults.standard.string(forKey: "screen") }
    /// `-orientation landscape` — the simulator has no rotate gesture a script can send,
    /// so the v3.3 layouts are smoke-tested by asking for the orientation at launch.
    static var orientation: String? { UserDefaults.standard.string(forKey: "orientation") }
    /// `-dumpStrokes YES` — write the unfinished fixture's synthesised ink, at this
    /// device's surface width, to `Documents/demo_strokes.json` (see `dumpStrokesIfRequested`).
    static var wantsStrokeDump: Bool { UserDefaults.standard.bool(forKey: "dumpStrokes") }

    /// The setup every fixture is written in. Jua is the only face the formations are
    /// fitted to (§4.11), so it is the only face the synthesised hand can follow.
    static let fixtureSetup = WritingSetup(faceID: "jua", sizeID: "l", mode: .trace)

    /// The entry with spoken words still waiting — the page a screenshot of the writing
    /// screen is taken on. Its record is written; the rest of the telling is spoken.
    static let unfinishedRecord = "Today we went to the park and I saw a big dog."
    static let unfinishedSpoken = "The dog wanted to play with me and we threw a ball for it until it got tired."
    static var unfinishedPageText: String { unfinishedRecord + "\n" + unfinishedSpoken }

    /// The width the writing surface has on this device: the shorter side of the screen,
    /// which the page keeps in both orientations (`ScreenLayout.pageWidth`). Fixtures are
    /// captured at this width because the editor restores ink only at the width it was
    /// drawn at (`TracingCanvasView.restore`) — an archive from a narrower iPad would
    /// open as a page with no ink on it.
    @MainActor
    static var liveCanvasWidth: CGFloat {
        let bounds = UIScreen.main.bounds.size
        return min(bounds.width, bounds.height)
    }

    @MainActor
    static func applyRequestedOrientation() {
        guard let orientation else { return }
        let mask: UIInterfaceOrientationMask = orientation == "landscape" ? .landscapeRight : .portrait
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        }
    }

    /// v3.4 — the welcome is settled whenever the harness is driving, so a screenshot
    /// run lands on the screen it asked for; `-screen welcome` asks for the welcome
    /// itself, on a fresh iPad.
    @MainActor
    static func settleWelcome(_ onboarding: Onboarding) {
        if screen == "welcome" { onboarding.reset(); return }
        guard wantsSeed || screen != nil else { return }
        if !onboarding.hasAcceptedCurrentTerms { onboarding.acceptTerms() }
        if !onboarding.hasChosenVoiceFeedback { onboarding.chooseVoiceFeedback(true) }
        if !onboarding.hasSeenPencil { onboarding.recordPencilCheck(.pencil) }
        if !onboarding.isComplete { onboarding.finish() }
    }

    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        guard wantsSeed else { return }
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard existing.isEmpty else { return }

        let width = liveCanvasWidth

        let milo = UserProfile(name: "Milo")
        milo.setup = fixtureSetup
        milo.currentStreak = 5
        milo.longestStreak = 11
        milo.totalPoints = 1_840
        milo.totalStars = 46
        milo.totalWordsWritten = 640
        milo.lastWroteOn = .now
        milo.earnedBadgeIDs = ["first_entry", "sharp_shooter", "streak_5"]
        // Ten letters traced on the practice sheet today (§8.3): eight in the arrow order,
        // two out of it — 8 × 2 + 2 × 1 = the "+18 today" pill, in both status colours.
        let today = PracticePoints.dayKey(.now)
        for letter in "ABCDEabc" {
            milo.practiceLedger[PracticePoints.ledgerKey(day: today, character: letter)] = PracticePoints.full
        }
        for letter in "de" {
            milo.practiceLedger[PracticePoints.ledgerKey(day: today, character: letter)] = PracticePoints.partial
        }
        context.insert(milo)

        let ada = UserProfile(name: "Ada")
        ada.setup = WritingSetup(faceID: "jua", sizeID: "xl", mode: .trace)
        context.insert(ada)

        // Entries, oldest first. Complete entries: the whole telling is record.
        let fixtures: [(days: Int, hour: Int, text: String, accuracy: Double)] = [
            (7, 16, "I want to be an astronaut and go all the way to the moon", 0.88),
            (5, 18, "The dog has a cold nose and he pushed it into my hand", 0.66),
            (3, 10, "My tower fell down but I built it again even taller", 0.90),
            (1, 17, "We made pancakes with Grandma and mine was the biggest one", 0.81),
            (0, 16, "I saw a red bird in the yard. It was on the fence by the gate and it sang for a long time", 0.94),
        ]

        for fixture in fixtures {
            let start = Calendar.current.date(byAdding: .day, value: -fixture.days, to: .now) ?? .now
            let session = WritingSession(setup: milo.setup, startedAt: start, transcript: fixture.text)
            session.author = milo
            session.endedAt = start.addingTimeInterval(600)
            session.tracedAt = start
            session.accuracy = fixture.accuracy
            session.stars = ScoringEngine.stars(forAccuracy: fixture.accuracy)
            session.points = seededPoints(text: fixture.text, accuracy: fixture.accuracy,
                                          stars: session.stars)
            let page = synthesisePage(text: fixture.text, setup: milo.setup,
                                      accuracy: fixture.accuracy, width: width)
            session.canvasWidth = width
            session.canvasHeight = page.height
            session.strokeArchive = try? StrokeArchive.encode(page.strokes)
            session.thumbnailData = thumbnail(for: page.strokes, setup: milo.setup)
            context.insert(session)
        }

        // An entry with spoken words still waiting. Under v2.5 the record holds only what
        // was written; the rest of the telling sits in the spoken buffer.
        let unfinishedStart = Calendar.current.date(byAdding: .hour, value: -2, to: .now) ?? .now
        let unfinished = WritingSession(
            setup: milo.setup,
            startedAt: unfinishedStart,
            transcript: unfinishedRecord,
            spokenBuffer: unfinishedSpoken
        )
        unfinished.author = milo
        unfinished.tracedAt = unfinishedStart
        unfinished.accuracy = 0.91
        unfinished.stars = 3
        unfinished.points = seededPoints(text: unfinishedRecord, accuracy: 0.91, stars: 3)
        // The ink covers the record only, but it is laid out against the whole page —
        // the spoken paragraph beneath changes nothing above it, and the editor lays the
        // page out the same way when it restores.
        let page = synthesisePage(text: unfinishedPageText, setup: milo.setup, accuracy: 0.91,
                                  width: width, upTo: unfinishedRecord.count)
        unfinished.canvasWidth = width
        unfinished.canvasHeight = page.height
        unfinished.strokeArchive = try? StrokeArchive.encode(page.strokes)
        unfinished.thumbnailData = thumbnail(for: page.strokes, setup: milo.setup)
        context.insert(unfinished)
    }

    /// The journal list's thumbnail, as `TracingCanvasView.thumbnail(width:)` draws it
    /// when an entry is finished: the ink's bounds on paper, graphite, 320 pt wide. Seeded
    /// entries never pass through a finish, so the harness draws theirs the same way.
    @MainActor
    static func thumbnail(for strokes: [TracingStroke], setup: WritingSetup,
                          width: CGFloat = 320) -> Data? {
        guard let first = strokes.first else { return nil }
        var ink = first.bounds()
        for stroke in strokes.dropFirst() { ink = ink.union(stroke.bounds()) }
        ink = ink.insetBy(dx: -8, dy: -8)
        guard ink.width > 0, ink.height > 0 else { return nil }
        let scale = width / ink.width
        let size = CGSize(width: width, height: min(ink.height * scale, width * 1.2))
        let widthScale = setup.size.size / 72
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(Tokens.Colour.paper).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let cg = ctx.cgContext
            cg.scaleBy(x: scale, y: scale)
            cg.translateBy(x: -ink.minX, y: -ink.minY)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            cg.setStrokeColor(UIColor(Tokens.Colour.inkNatural).cgColor)
            for stroke in strokes where stroke.points.count > 1 {
                for i in 1..<stroke.points.count {
                    let a = stroke.points[i - 1], b = stroke.points[i]
                    cg.setLineWidth((1.5 + 3.5 * (a.force + b.force) / 2) * widthScale)
                    cg.move(to: a.location)
                    cg.addLine(to: b.location)
                    cg.strokePath()
                }
            }
        }.pngData()
    }

    /// §8.3 (v3.5) — a plausible score for seeded ink: every letter at the fixture's
    /// accuracy, every whole word, most of them in order, then the stars, a five-day
    /// streak and the finish. Not the engine's own reading of the synthesised strokes —
    /// that would drift with the hand's wobble — and a seeded entry keeps this score
    /// until new ink lands on it.
    static func seededPoints(text: String, accuracy: Double, stars: Int) -> Int {
        let words = text.split(whereSeparator: \.isWhitespace)
        let letters = words.reduce(0) { sum, word in sum + word.count }
        let whole = words.filter { word in
            word.filter({ $0.isLetter || $0.isNumber }).count >= ScoringEngine.wordMinimumLetters
        }.count
        let ordered = Int((Double(whole) * accuracy).rounded())
        return Int((Double(letters * ScoringEngine.letterValue) * accuracy).rounded())
            + whole * ScoringEngine.wordBonus + ordered * ScoringEngine.orderBonus
            + stars * ScoringEngine.starValue + ScoringEngine.streakCap * ScoringEngine.streakStep
            + ScoringEngine.sessionBonus
    }

    // MARK: - Stroke dump for automation

    /// `-dumpStrokes YES`: the unfinished fixture's page, synthesised at this device's
    /// surface width, written to `Documents/demo_strokes.json` — every glyph box, and one
    /// point list per stroke tagged with the glyph it belongs to — so a driver outside the
    /// app (the simulator's touch injection) can replay the ink as real pen input on the
    /// writing page. Canvas coordinates: add the status bar and toolbar to get screen points.
    @MainActor
    static func dumpStrokesIfRequested() {
        guard wantsStrokeDump else { return }
        let width = liveCanvasWidth
        let page = synthesisePage(text: unfinishedPageText, setup: fixtureSetup,
                                  accuracy: 0.95, width: width)
        let glyphs: [[String: Any]] = page.layout.glyphBoxes.enumerated().map { index, box in
            ["i": index, "c": String(box.character), "line": box.lineIndex, "word": box.wordIndex,
             "x": box.rect.minX, "y": box.rect.minY, "w": box.rect.width, "h": box.rect.height]
        }
        let strokes: [[String: Any]] = page.strokes.map { stroke in
            let index = stroke.points.first?.letterIndex ?? -1
            let character = index >= 0 && index < page.layout.glyphBoxes.count
                ? String(page.layout.glyphBoxes[index].character) : ""
            return ["i": index, "c": character,
                    "points": stroke.points.map { [$0.location.x, $0.location.y] }]
        }
        let payload: [String: Any] = [
            "width": width, "height": page.height, "text": unfinishedPageText,
            "surfaceInset": Tokens.Layout.surfaceInset, "toolbarHeight": Tokens.Layout.toolbarHeight,
            "baselines": page.layout.baselines,
            "glyphs": glyphs, "strokes": strokes,
        ]
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        else { return }
        try? data.write(to: documents.appendingPathComponent("demo_strokes.json"))
    }

    // MARK: - A plausible child's hand

    /// Plausible child handwriting: every letter written along its taught formation —
    /// the paths the practice sheet demonstrates (`LetterFormations`), in the taught order
    /// and direction — by a hand that wobbles. A slow sideways drift along each stroke, a
    /// little jitter, a letter that comes out a touch bigger or smaller and a touch off
    /// its spot, and a short overshoot where the pen lifts. `accuracy` sets how far the
    /// hand strays. Characters with no formation (punctuation) walk the spine of the
    /// glyph instead. Only ever used to populate the simulator.
    @MainActor
    static func synthesise(text: String, setup: WritingSetup, accuracy: Double,
                           width: CGFloat = 754) -> [TracingStroke] {
        synthesisePage(text: text, setup: setup, accuracy: accuracy, width: width).strokes
    }

    struct SynthesisedPage {
        let strokes: [TracingStroke]
        let layout: MaskRenderer.Layout
        let height: CGFloat
    }

    /// `upTo` limits the ink to the first `upTo` characters of `text` — the written record
    /// of a page whose later paragraphs are still only spoken.
    @MainActor
    static func synthesisePage(text: String, setup: WritingSetup, accuracy: Double,
                               width: CGFloat, upTo: Int? = nil) -> SynthesisedPage {
        let renderer = MaskRenderer()
        let height = max(300, MaskRenderer.contentHeight(text: text, setup: setup,
                                                         width: width - Tokens.Layout.surfaceInset * 2))
        renderer.generate(text: text, setup: setup,
                          canvasSize: CGSize(width: width, height: height), screenScale: 2)
        let fitter = FormationFitter(font: setup.uiFont())
        var rand = Rand(seed: stableHash(text))

        let stray = CGFloat(max(0, min(1, 1 - accuracy)))   // 0 neat … messy
        let size = setup.size.size                            // 72 at Large
        let hand = Hand(wobble: size * (0.012 + stray * 0.14),
                        jitter: size * (0.004 + stray * 0.03),
                        grow: 0.03 + stray * 0.12,
                        nudge: size * (0.01 + stray * 0.05),
                        size: size)

        var strokes: [TracingStroke] = []
        for (index, box) in renderer.layout.glyphBoxes.enumerated() where box.isScorable {
            if let upTo, box.charIndex >= upTo { break }
            guard let formation = LetterFormations.formation(for: box.character) else {
                if let stroke = spineStroke(box: box, index: index, renderer: renderer,
                                            hand: hand, rand: &rand) {
                    strokes.append(stroke)
                }
                continue
            }
            // The whole letter a touch bigger or smaller, and nudged off its spot.
            let fitted = fitter.formationRect(for: box)
            let grow = 1 + rand.signed(hand.grow)
            let rect = CGRect(x: fitted.midX - fitted.width * grow / 2 + rand.signed(hand.nudge),
                              y: fitted.midY - fitted.height * grow / 2 + rand.signed(hand.nudge),
                              width: fitted.width * grow,
                              height: fitted.height * grow)
            for part in formation.strokes {
                let path = FormationFitter.place(part, in: rect)
                let stroke = handStroke(along: path, isDot: part.isDot, index: index,
                                        renderer: renderer, hand: hand, rand: &rand)
                if stroke.points.count > 1 { strokes.append(stroke) }
            }
        }
        return SynthesisedPage(strokes: strokes, layout: renderer.layout, height: height)
    }

    /// How far the synthesised hand strays, in points.
    private struct Hand {
        let wobble: CGFloat   // amplitude of the slow sideways drift along a stroke
        let jitter: CGFloat   // point-to-point noise
        let grow: CGFloat     // ± fraction of letter size
        let nudge: CGFloat    // ± offset of the whole letter
        let size: CGFloat     // glyph point size
    }

    /// One pen-down-to-pen-up gesture along `path`: resampled every couple of points so
    /// it renders as a line, pushed sideways by a slow wave plus jitter, and carried a
    /// little past the taught end the way a pen overshoots before it lifts.
    @MainActor
    private static func handStroke(along path: [CGPoint], isDot: Bool, index: Int,
                                   renderer: MaskRenderer, hand: Hand, rand: inout Rand) -> TracingStroke {
        var stroke = TracingStroke()
        func add(_ p: CGPoint, force: CGFloat) {
            stroke.append(StrokePoint(location: p, force: min(1, max(0.15, force)),
                                      isInside: renderer.isInsideLetter(point: p, tolerance: 3),
                                      letterIndex: index))
        }

        if isDot, let centre = path.first {
            // A dot is a short press — three points in a tiny hook.
            let r = hand.size * 0.02
            let force = 0.5 + rand.next() * 0.3
            add(CGPoint(x: centre.x - r, y: centre.y), force: force)
            add(CGPoint(x: centre.x + rand.signed(r), y: centre.y + r), force: force + 0.1)
            add(CGPoint(x: centre.x + r, y: centre.y - rand.signed(r)), force: force)
            return stroke
        }

        var points = path
        if points.count >= 2 {
            let a = points[points.count - 2], b = points[points.count - 1]
            let length = max(1, hypot(b.x - a.x, b.y - a.y))
            let over = hand.size * (0.01 + rand.next() * 0.03)
            points.append(CGPoint(x: b.x + (b.x - a.x) / length * over,
                                  y: b.y + (b.y - a.y) / length * over))
        }

        let step: CGFloat = 2.5
        var samples: [(point: CGPoint, tangent: CGPoint)] = []
        for i in 0..<max(0, points.count - 1) {
            let a = points[i], b = points[i + 1]
            let length = hypot(b.x - a.x, b.y - a.y)
            guard length > 0 else { continue }
            let t = CGPoint(x: (b.x - a.x) / length, y: (b.y - a.y) / length)
            var d: CGFloat = 0
            while d < length {
                samples.append((CGPoint(x: a.x + t.x * d, y: a.y + t.y * d), t))
                d += step
            }
        }
        if let last = points.last, let tangent = samples.last?.tangent {
            samples.append((last, tangent))
        }

        let phase = rand.next() * .pi * 2
        let wavelength = hand.size * (0.6 + rand.next() * 0.6)
        let baseForce = 0.4 + rand.next() * 0.3
        for (i, sample) in samples.enumerated() {
            let s = CGFloat(i) * step
            let side = hand.wobble * sin(s / wavelength * 2 * .pi + phase) + rand.signed(hand.jitter)
            let normal = CGPoint(x: -sample.tangent.y, y: sample.tangent.x)
            add(CGPoint(x: sample.point.x + normal.x * side, y: sample.point.y + normal.y * side),
                force: baseForce + rand.signed(0.08))
        }
        return stroke
    }

    /// Characters with no formation: walk the vertical centre of ink in each column of
    /// the glyph, as the harness always did.
    @MainActor
    private static func spineStroke(box: MaskRenderer.GlyphBox, index: Int, renderer: MaskRenderer,
                                    hand: Hand, rand: inout Rand) -> TracingStroke? {
        var stroke = TracingStroke()
        let columns = max(4, Int(box.rect.width / 3))
        for column in 0...columns {
            let x = box.rect.minX + box.rect.width * CGFloat(column) / CGFloat(columns)
            var hits: [CGFloat] = []
            var y = box.rect.minY
            while y <= box.rect.maxY {
                if renderer.isInsideLetter(point: CGPoint(x: x, y: y), tolerance: 0) { hits.append(y) }
                y += 2
            }
            guard let first = hits.first, let last = hits.last else { continue }
            let point = CGPoint(x: x + rand.signed(hand.jitter), y: (first + last) / 2 + rand.signed(hand.wobble))
            stroke.append(StrokePoint(location: point,
                                      force: 0.35 + rand.next() * 0.5,
                                      isInside: renderer.isInsideLetter(point: point, tolerance: 3),
                                      letterIndex: index))
        }
        return stroke.points.count > 1 ? stroke : nil
    }

    /// A small deterministic generator, so the same text always draws the same page —
    /// `String.hashValue` is salted per process and would not.
    struct Rand {
        private var state: UInt64
        init(seed: UInt64) { state = seed | 1 }
        mutating func next() -> CGFloat {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat((state >> 33) % 10_000) / 10_000
        }
        mutating func signed(_ scale: CGFloat) -> CGFloat { (next() * 2 - 1) * scale }
    }

    /// FNV-1a over the UTF-8 bytes.
    static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }
}
#endif
