#if DEBUG
import SwiftUI
import SwiftData

/// Screenshot and manual-testing harness. DEBUG only — never compiled into a release.
///
///     xcrun simctl launch <device> <bundle-id> -seed YES -screen home
enum DemoData {

    static var wantsSeed: Bool { UserDefaults.standard.bool(forKey: "seed") }
    static var screen: String? { UserDefaults.standard.string(forKey: "screen") }

    static func seedIfNeeded(_ context: ModelContext) {
        guard wantsSeed else { return }
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard existing.isEmpty else { return }

        let milo = UserProfile(name: "Milo")
        milo.setup = WritingSetup(faceID: "jua", sizeID: "l", mode: .trace)
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
            session.points = Int(fixture.accuracy * 100) + session.stars * 25 + 25 + 30
            session.canvasWidth = 754
            session.canvasHeight = 900
            let strokes = synthesise(text: fixture.text, setup: milo.setup, accuracy: fixture.accuracy)
            session.strokeArchive = try? StrokeArchive.encode(strokes)
            context.insert(session)
        }

        // An entry with spoken words still waiting — the resume card and the "Still to
        // write" section. Under v2.5 the record holds only what was written; the rest of
        // the telling sits in the spoken buffer.
        let unfinishedStart = Calendar.current.date(byAdding: .hour, value: -2, to: .now) ?? .now
        let unfinished = WritingSession(
            setup: milo.setup,
            startedAt: unfinishedStart,
            transcript: "Today we went to the park and I saw a big dog.",
            spokenBuffer: "The dog wanted to play with me and we threw a ball for it until it got tired."
        )
        unfinished.author = milo
        unfinished.tracedAt = unfinishedStart
        unfinished.accuracy = 0.91
        unfinished.stars = 3
        unfinished.canvasWidth = 754
        unfinished.canvasHeight = 900
        unfinished.strokeArchive = try? StrokeArchive.encode(
            synthesise(text: "Today we went to the park and I saw a big dog.", setup: milo.setup, accuracy: 0.91)
        )
        context.insert(unfinished)
    }

    /// Plausible child handwriting: walks the *spine* of each rendered glyph — the
    /// vertical centre of ink in each column — and wobbles it. Only ever used to
    /// populate the simulator.
    static func synthesise(text: String, setup: WritingSetup, accuracy: Double) -> [TracingStroke] {
        let renderer = MaskRenderer()
        let width: CGFloat = 754
        let height = MaskRenderer.contentHeight(text: text, setup: setup,
                                                width: width - Tokens.Layout.surfaceInset * 2)
        renderer.generate(text: text, setup: setup,
                          canvasSize: CGSize(width: width, height: max(300, height)), screenScale: 2)

        var seed = UInt64(truncatingIfNeeded: text.hashValue) | 1
        func random() -> CGFloat {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat((seed >> 33) % 1000) / 1000
        }
        let wobble = (1 - accuracy) * 22 + 1.5

        var strokes: [TracingStroke] = []
        for (index, box) in renderer.layout.glyphBoxes.enumerated() where box.isScorable {
            var stroke = TracingStroke()
            let columns = max(6, Int(box.rect.width / 3))
            for column in 0...columns {
                let x = box.rect.minX + box.rect.width * CGFloat(column) / CGFloat(columns)
                // Find the vertical middle of the ink in this column.
                var hits: [CGFloat] = []
                var y = box.rect.minY
                while y <= box.rect.maxY {
                    if renderer.isInsideLetter(point: CGPoint(x: x, y: y), tolerance: 0) { hits.append(y) }
                    y += 2
                }
                guard let first = hits.first, let last = hits.last else { continue }
                let spine = (first + last) / 2
                let point = CGPoint(x: x + (random() - 0.5) * wobble * 0.4,
                                    y: spine + (random() - 0.5) * wobble)
                stroke.append(StrokePoint(location: point,
                                          force: 0.35 + random() * 0.5,
                                          isInside: renderer.isInsideLetter(point: point, tolerance: 3),
                                          letterIndex: index))
            }
            if stroke.points.count > 1 { strokes.append(stroke) }
        }
        return strokes
    }
}
#endif
