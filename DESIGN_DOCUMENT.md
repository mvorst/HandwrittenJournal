# Handwritten Journal

## Design Document v2.2

An iPad journal for a child who is learning to write. The child says a sentence, the app
transcribes it, the child traces it in their own hand, and the traced sentence joins the
page. Do that a few times and there is a page. Do it for a year and there is a journal in
the child's own handwriting.

Companion: `WIREFRAME_SPEC.md` v2.0 (measurements, tokens, frame inventory).
Build notes: `PENPOT_HANDOFF.md`.

---

## 0. What Changed in v2.0

v1 was a tracing *game* with a level ladder. v2 is a *journal* with a writing setting. The
differences are structural, not cosmetic:

| v1 | v2 | Why |
|---|---|---|
| Levels 1–10 drive glyph size; earned with stars | **Font size is a setting** | Progression made shrinking text a reward. It is a difficulty dial, and a grown-up should turn it. |
| One typeface (Jua) | **Font is a setting**, from a curated list of five | Different children read different letterforms more easily; Andika exists for exactly this. |
| Landscape first | **Portrait only** | The writing screen stacks page-above-line. A child holds an iPad like a notebook. |
| One sentence = one entry | **A session holds many sentences** | Writing is a sitting, not a sentence. The page grows while you watch. |
| "Show accuracy colours" toggle | **Always on while writing, never on in the journal** | Two different jobs. Neither needs a switch. |
| Parent gate (7 × 8 = ?) | **Removed** | See §10.3 — this is a real loss, recorded honestly. |
| — | **Copy mode named, not built** | Writing on a line beneath the words. See §7.4 for why it is not a small change. |

Retired frame numbers: 8, 16, 35.

## 0.1 What Changed in v2.1

| Was | Now | Why |
|---|---|---|
| Accuracy measured across the whole sentence | **Graded per letter; an untraced letter scores 0%** | "Trace four letters, tap Done" scored ~95%. Now it scores ~20%. Coverage as a separate metric is retired — this subsumes it. |
| Undo and Clear only | **An eraser** | A child who wanders outside one letter should not have to redraw the four before it. |
| Every attempt kept forever | **Latest tracing only** | Re-tracing replaces. Simpler model, simpler journal, no "which one do we show?" question. |
| Voice discarded after transcription | **Voice recorded and kept** | The sentence in their handwriting *and* their five-year-old voice. You cannot record 2026 retroactively. |
| Export one entry | **Export the whole journal** | The book is what the five years are for. |
| Permission failures undrawn | **Drawn** (frames 40–42) | |

Considered and rejected: read-aloud playback of journal text (the child using this app can
read), stroke replay animation, and writing prompts — this is a journal, not a teacher.

## 0.2 What Changed in v2.2

**The child now speaks for up to five minutes, not one sentence.**

| Was | Now |
|---|---|
| Speak one sentence → confirm → trace → speak again | **Speak freely → review the sentence list → trace them one at a time** |
| 200-character cap | **A size-aware fit rule** — a piece must fit the writing surface, which at Extra Large is only ~56 characters (§7.5) |
| `Draft` as its own model | **An unfinished session is the draft.** The `Draft` entity is deleted |
| — | A **review screen** (edit / split / join), a **queue** through the writing screens, and a **resume card** on Home |

**Why this is better.** A five-year-old telling you about their day does not stop at
sentence boundaries. Forcing them to speak one sentence, wait, trace it, then remember what
they were going to say next is cognitively hostile — it interleaves composing and
transcribing, which are different jobs. Speaking freely and then writing is what a scribe
does, and it is what a child does when they dictate to a parent.

**What it costs.** Five minutes of speech is roughly fourteen sentences, which is twenty
minutes of tracing — far past a five-year-old's appetite. The design answer is not to
shorten the recording but to make **stopping part-way completely unremarkable**: see §4.4.

---

## 1. Overview

### 1.1 Project Identity

**Handwritten Journal.** A single-purpose, offline, no-account iPad app. One household,
several profiles, one journal each.

The premise: handwriting practice is dull, and journalling is not. If the sentence a child
practises is a sentence they wanted to say, practice stops being practice. The artefact —
a growing book in their own hand — is the reward, and it is a real one.

**Who it is for.** Children roughly 5–8 who can speak in sentences and are learning to
form letters. A grown-up sets up the profile and picks the font and size; after that the
child drives.

**What it is not.** Not a curriculum, not a reading app, not social, not online. There is
no account, no server, and no way for anything to leave the iPad except a PDF the child's
grown-up chooses to share.

---

## 2. What Is Different From TraceRight

TraceRight (in `Original Traceright App/`) is the working tracing engine this is built on.
Ported essentially unchanged: mask generation, stroke colouring, scoring, haptics, the
dictation screen.

What is new:

- **The sentence comes from the child.** TraceRight supplied words; here the child speaks.
- **Everything is kept.** TraceRight scored and discarded. Here every stroke is archived
  and every attempt is replayable forever (§6).
- **The page is the point.** TraceRight ended at a score. Here the score is a footnote and
  the accumulating journal is the product.
- **Profiles.** TraceRight was single-player.
- **No levels.** TraceRight's ladder is replaced by a font-size setting (§0).

---

## 3. User Flow

```
Profile Picker ──(PIN if set)──▶ Journal Home
                                     │
                          ┌──────────┴───────────┐
                          ▼                      ▼
                     New Entry               My Journal ──▶ Entry Detail
                          │                                       │
                          ▼                                       └──▶ Export (entry or book)
              ┌──── WRITING SESSION ────────────────┐
              │                                     │
              │   Speak ──▶ Confirm ──▶ Trace       │
              │     ▲                      │        │
              │     │                      ▼        │
              │     └───── Reveal ◀── sentence      │
              │           "write another"  settles  │
              │              │            into the  │
              │              │            page      │
              │        "I'm finished"               │
              └──────────────┼──────────────────────┘
                             ▼
                     Results (this session)
                             │
                   ┌─────────┴──────────┐
                   ▼                    ▼
              Write more          See My Journal
```

**The loop is the design.** Speak → confirm → trace → the sentence shrinks and rises into
the page above → speak again. The child watches their page fill up in real time. Everything
else in the app is in service of that loop.

A session ends when the child taps "I'm finished". Results summarise **only what was added
in that session** — not lifetime totals, which would make each sitting feel smaller than
the last.

---

## 4. Screen Specifications

All screens are portrait, 834 × 1194. See `WIREFRAME_SPEC.md` §13 for coordinates.

### 4.1 Profile Picker (launch screen)

Circular avatars in a 2 × 2 grid, name below, then the profile's font and size in
`caption`. A small lock glyph if the profile has a PIN. A profile with no photo shows its
**initial**, not the dashed add-tile treatment — the two must not look alike.

Tapping a profile with no PIN enters it immediately. With a PIN, a 4-digit pad slides up; a
wrong PIN shakes the dots, no lockout, no error copy beyond "Try again". Long-press → Edit
profile. The gear opens app-wide settings.

The last-used profile is highlighted but never auto-entered — choosing a person is the
deliberate first act of the app.

### 4.2 Profile Setup / Edit

Photo (front camera with a circular mask and 3-2-1 countdown, or PhotosPicker; centre-
cropped to 512 × 512, JPEG q0.8), name (1–20 characters), optional 4-digit PIN, and the
three writing settings:

| Setting | Values | Default |
|---|---|---|
| **Font** | Jua · Andika · Baloo 2 · Sniglet · Comic Neue | Jua |
| **Font size** | Extra Large · Large · Medium · Small · Extra Small | Large |
| **Mode** | Trace · *Copy (coming later)* | Trace |

Each opens its own picker with **live previews at the real size in the real face** (frames
38, 39) — a grown-up cannot pick a font sensibly from a name alone.

Delete Profile is destructive and marked "Grown-ups only". **It is not gated** — see §10.3.

### 4.3 Journal Home

```
┌────────────────────────────────────┐
│  ╭──╮↻ Milo              [📈] [⚙]  │
│  ╰──╯ 🔥 5-day streak              │
│                                    │
│  ┌──────────────────────────────┐  │
│  │ YOUR WRITING                 │  │
│  │ Jua · Large · Trace  Change ›│  │
│  └──────────────────────────────┘  │
│                                    │
│        ┌──────────────────┐        │
│        │  ✎  New Entry    │        │
│        └──────────────────┘        │
│                                    │
│  Recent ─────────────  [See all ›] │
│  ┌────┐ ┌────┐ ┌────┐              │
│  │~~~~│ │~~~~│ │~~~~│              │
│  │Mar4│ │Mar3│ │Mar1│              │
│  │★★★+1│ │★★☆│ │★★★│              │
│  └────┘ └────┘ └────┘              │
│      ┌────┐ ┌────┐                 │
│      │~~~~│ │~~~~│                 │
│      └────┘ └────┘                 │
│                                    │
│  Badges ─────────────────────────  │
│  [🏆][🎯][🔥][░][░][░][░][░]       │
└────────────────────────────────────┘
```

**When a session is unfinished, a resume card takes the primary slot** — the next sentence
in quotes, a progress bar, *"3 of 8 written · said at 5:30 PM"*, and **Keep writing** as the
primary action with *Start something new instead* below it. This is the single most
important piece of the long-form design: without it, speaking for four minutes and writing
three sentences feels like failing.

The **"Your writing" card** replaces v1's level card. It states the three settings in
plain words and opens Settings. It is informational, not a progress bar — nothing here is
being filled up.

Session cards show the **handwriting thumbnail** of the first sentence, not typed text, and
a `+N` chip when the session holds more than one. The journal should look like a journal at
a glance.

### 4.4 Writing a session

One screen, four states, all sharing the same frame (`WIREFRAME_SPEC.md` §11.1):

```
┌────────────────────────────────────┐
│  Close        Wednesday, March 4   │  ← toolbar
│  Your writing so far               │
│  ┌──────────────────────────────┐  │
│  │ I saw a red bird in the yard │  │  ← accepted, natural ink,
│  │                              │  │    half size, SCROLLS
│  └──────────────────────────────┘  │
│  Now trace this      Jua · Large   │
│ ┌────────────────────────────────┐ │
│ │ It was on the fence by         │ │  ← guide + live ink,
│ │ the gate                       │ │    accuracy colours,
│ └────────────────────────────────┘ │    does NOT scroll
│  Live accuracy: 88%    [ Done ✓ ]  │
└────────────────────────────────────┘
```

**Speak** — `SFSpeechRecognizer`, on-device, `en-US`, live partial results. The child talks
for **as long as they like, up to five minutes**: a big mic, an elapsed timer, an input
level meter, and the transcript accumulating in a scrolling panel beneath. Nothing is
committed until they tap *I'm done talking*. **The audio is recorded and kept** (§5.3).

At the five-minute cap recording stops itself and the copy stays warm — *"That's a whole lot
of story! I stopped listening so we can start writing."* The cap exists because the
recogniser drifts on long takes, not to hurry the child.

**Review** — the transcript is split into sentences (§7.5) and shown as a numbered list. Any
row can be edited, deleted, split at the cursor, or joined to the next. A sentence too long
for the current size is labelled *"written in 2 parts"* rather than treated as an error.
The screen states the workload plainly — *"8 pieces to write"* — and says outright: *"You
don't have to write them all today."*

Microphone permission is preceded by a **child-legible explainer** (frame 40) so the first
thing a five-year-old sees is not an adult system dialog. If permission is refused or
recognition is unavailable, the keyboard becomes the primary path (frame 41) — the app
never dead-ends. The accepted page stays visible above the mic, so the
child can see what they are adding to.

**Confirm** — the transcript appears in the profile's face on ruled paper with the caption
*"Is that right? Tap to fix it."* Speech recognition is unreliable for six-year-olds, and
tracing a mis-heard sentence is demoralising. Buttons: **Try Again** (re-record), **Write
It** (proceed). The sentence is saved as a draft at this point, so it can be queued and
traced later.

**Trace** — the pieces are worked through in order, with a **"Sentence 3 of 8" queue chip**
on every writing screen. Guide text and ruled lines in the profile's face and size. Ink is drawn in
green/red per segment **always**; there is no toggle, because during writing the colours
*are* the feedback.

Three tools in the toolbar:

| Tool | Does |
|---|---|
| **Eraser** | Rubs out every point inside a 72 pt circle and re-scores the letters it touched. Selected state fills the button. |
| **Undo** | Removes the last whole stroke, in order. |
| **Clear** | Wipes the sentence. Nothing is scored until Done. |

The eraser and undo are not redundant: undo is chronological, the eraser is spatial. A
child who overshoots the *a* in a ten-letter word wants to fix the *a*, not unwind
everything after it.

The readout beneath reads **"So far: 78%"** with **"16 letters still to go"** below it — see
§8.1 for why the live number and the final number are not the same.

**Reveal** — the guide fades over 0.5 s leaving only the child's ink, then the sentence
shrinks to half size and rises into the page above over 0.45 s. **This animation is the
emotional core of the app** and is worth building carefully.

The final score appears here, with the per-letter penalty applied and stated plainly —
*"Every letter was finished — nice work."* or *"2 letters were not finished."* Three ways
out: *Next sentence*, *Try that again* (replaces this tracing), and ***Finish for now — 5
saved for later***.

**Stopping part-way must be unremarkable.** A child who writes three of eight has done a
good day's work, and the app must not imply otherwise. The exit is on every screen, the
count of what is saved is always in the label, and the unfinished session is the *first*
thing on Journal Home the next time they open the app (§4.3). No warning, no "are you
sure", no lost-progress language.

### 4.5 Results

Summarises the session only:

```
        Great job, Milo!
     You added 2 sentences today
            ★ ★ ★
         ╭───────────╮
         │    91%    │
         │  Accuracy │
         ╰───────────╯
          + 224 points
   Best yet with Jua at Large ✨

  This session ────────────────────
  "I saw a red bird in the yard" ★★★ 94%
  "It was on the fence by the gate" ★★☆ 88%
            Jua · Large · Trace

     🏆 NEW BADGE: Sharp Shooter

        [ Write more ]
        [ See My Journal ]
```

"Best yet with *font* at *size*" replaces v1's "Best yet at Level N". The comparison must
be **setting-matched** or it is dishonest: 88% at Extra Large is not better than 84% at
Small.

### 4.6 Journal List

Sectioned by month, newest first. **Each row is a session**, showing the first sentence's
thumbnail, date and time, the first sentence quoted, and metadata reading *"2 sentences ·
91% · Jua Large"* — the session's mean accuracy.

**Unfinished sessions sit in a "Still to write" section at the top**, with a progress bar,
the next sentence quoted and a *Keep writing ›* button. There is no separate drafts
concept: a draft is simply a session with sentences left untraced.

Search matches transcript text. Calendar view shows a month grid with a dot on every day
that has a session. Filter by star rating, font or size.

### 4.7 Entry Detail — the toggle

Still the heart of the app, now showing a **session page** rather than a single sentence:

- **Typed** renders every sentence in the session on ruled paper in the profile's face — so
  the two states are visually comparable, not one plain and one pretty.
- **Handwritten** renders the archived strokes on the same paper in **natural graphite**,
  always. A journal should read like handwriting, not like a marked-up test.
- Switching uses a horizontal 3-D flip (0.35 s), which reads to a child as "turning the
  page over". Reduce Motion replaces it with a cross-fade.
- Below the page, one row per sentence: text, **"Hear it"** (plays the recording the child
  made when they said it), stars, accuracy. There is no attempt count and nothing to drill
  into — only the latest tracing is kept.
- **The page scrolls.** A long session overflows the surface; the journal is not truncated.
- **⋯ menu:** Rename · Export as PNG/PDF · Delete.
- **Trace This Again** replaces the stored tracing. The confirmation copy must say so:
  *"This will replace what you wrote."*

### 4.8 Export

Two scopes from the same screen:

- **One entry** — a single PDF page: the handwriting, the date, the typed words as a caption.
- **The whole journal** — one page per session, oldest first, with a cover carrying the
  child's name, the date range and the totals. ~38 pages and ~6 MB for a first year.

Toggles for *include the typed words* and *include accuracy scores* — a grandparent wants
the handwriting, not the marking. Rendered entirely on device.

The book is the reason the app keeps five years of ink. Do not leave it to v2.

### 4.9 Progress

```
  Accuracy over time          [30d|90d|All]
  100% ┤                          ╭──╮
   75% ┤   ╭──╮      ╭───╮   ╭───╯
   50% ┤──╯     ╲───╯     ╲─╯
       └──┬────────┬────────┬────────
         Dec      Jan      Feb
              ▲Large    ▲Andika

  By mode and font
  Setting              Mode   Best  Avg  Sentences
  Jua · Extra Large    Trace   97%  88%   31
✓ Jua · Large          Trace   94%  84%   38
  Andika · Large       Trace   91%  80%   12
  Comic Neue · Medium  Trace   88%  76%    7
```

**The caveat that mattered in v1 still matters, for the same reason.** Raw accuracy drops
every time the font or size changes, because the letters get harder. A naive line would
tell a child they are getting worse at the moment a grown-up made the task harder.
Therefore:

1. Font- and size-change dates are marked on the time axis.
2. The line is a 5-sentence rolling average.
3. **The per-setting table is the honest comparison** and gets equal visual weight.
4. Trend copy is computed within the current setting only.

Mode is a column now and will be a meaningful axis once Copy mode exists. With one mode and
a handful of settings the table is short; it must only list rows that have data, or it
becomes a wall of zeros.

**The one thing that replaces progression** lives on the font-size picker: when the current
setting's rolling average has been ≥ 90% for 14 days and a smaller size exists, a line
appears — *"Milo has been above 90% for two weeks — Small might be ready to try."* It is a
suggestion to a grown-up. It never changes anything by itself.

### 4.10 Settings

Per profile: name, photo, PIN, **font, font size, mode**, guide lines, finger tracing,
left-handed layout, sound, haptics, colorblind ink scheme, reset progress.

App-wide: iCloud sync (disabled, "Coming soon"), about, and two plain-language notes — one
saying PINs are a courtesy lock, one saying destructive actions are not gated.

---

## 5. Data Model

SwiftData, authored to CloudKit's constraints from day one (§9).

### 5.1 UserProfile

```swift
enum WritingMode: Int, Codable { case trace = 0, copy = 1 }

@Model final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now

    @Attribute(.externalStorage) var avatarImageData: Data?
    var pinSalt: Data?
    var pinHash: Data?

    // Writing settings — these replace v1's level ladder
    var fontKey: String = "jua"          // see WIREFRAME_SPEC §7.2
    var sizeKey: String = "l"            // see WIREFRAME_SPEC §7.3
    var modeRaw: Int = WritingMode.trace.rawValue

    // Progress (no levels)
    var totalStars: Int = 0
    var totalPoints: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastWroteOn: Date?
    var totalSentences: Int = 0
    var totalTracings: Int = 0
    var earnedBadgeIDs: [String] = []

    // Preferences
    var isLeftHanded: Bool = false
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var guideLinesEnabled: Bool = true
    var allowFingerTracing: Bool = false
    var colorBlindMode: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \WritingSession.author)
    var sessions: [WritingSession]?

}
```

### 5.2 WritingSession

```swift
@Model final class WritingSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    var customTitle: String?

    // Captured at session start so a later settings change never rewrites history
    var fontKey: String = "jua"
    var sizeKey: String = "l"
    var modeRaw: Int = WritingMode.trace.rawValue

    // What the child said, before it was split (§7.5)
    var rawTranscript: String = ""
    var spokenDuration: Double = 0        // seconds, ≤ 300

    var author: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \Sentence.session)
    var sentences: [Sentence]?
}
```

A session is **one sitting**. It opens when the child taps New Entry and closes when they
tap "I'm finished" (or the app is backgrounded for more than 30 minutes). Two sittings on
one day are two sessions, which is why the journal list shows a time alongside the date.

Denormalising font/size/mode onto the session — rather than reading it from the profile —
is deliberate. Progress compares like with like, and a child who moves from Large to Medium
must not have their old sessions silently relabelled.

### 5.3 Sentence

There is no separate attempt entity. **Only the latest tracing is kept**, so it lives
directly on the sentence.

```swift
@Model final class Sentence {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var order: Int = 0               // position within the session
    var text: String = ""            // confirmed transcript — what gets traced
    var rawTranscript: String = ""   // what the recognizer originally heard

    // This sentence's slice of the session recording (§10.4)
    @Attribute(.externalStorage) var audioData: Data?     // AAC, ~30 KB
    var audioDuration: Double = 0

    // Where the splitter put it (§7.5)
    var partIndex: Int = 0                // 0 unless one spoken sentence needed several pieces
    var partCount: Int = 1

    // The latest — and only — tracing
    var tracedAt: Date?
    var accuracy: Double = 0         // mean of letterAccuracies, §8.1
    var stars: Int = 0
    var points: Int = 0
    var letterAccuracies: [Double] = []   // one per glyph in `text`, 0…1
    var unfinishedLetters: Int = 0

    // Geometry the strokes were captured at, for faithful replay
    var canvasWidth: Double = 0
    var canvasHeight: Double = 0
    @Attribute(.externalStorage) var strokeArchive: Data?   // §6
    @Attribute(.externalStorage) var thumbnailData: Data?

    var session: WritingSession?
}
```

`letterAccuracies` is kept rather than recomputed because the mask is expensive to rebuild
and because it is the only durable record of *which* letters a child struggles with. It is
a small array — one double per character.

**Re-tracing overwrites.** `TraceAttempt` from v2.0 is deleted; there is no history table
and no migration to write, because nothing has shipped.

### 5.4 There is no Draft entity

A draft is **a session with untraced sentences**. `Sentence.tracedAt == nil` is the whole
test. The journal's "Still to write" section lists sessions where any sentence is untraced,
and `WritingSession.isComplete` is a computed `sentences.allSatisfy { $0.tracedAt != nil }`.

This falls out of long-form dictation: speaking produces N sentences at once, and the child
writes as many as they feel like. Anything left over is, by definition, a draft.

### 5.5 Reproducing a tracing

The session carries font, size and mode; the sentence carries `text` and the canvas
dimensions. Together those reproduce the *exact* guide layout at any time — the mask
renderer is deterministic given those inputs. That keeps an "ink over guide" review state,
or a re-score under a revised algorithm, available without a migration.

Progress reads font/size/mode from the **session**, so a settings change never relabels
history. Index `WritingSession.fontKey`, `sizeKey` and `modeRaw`.

---

## 6. Stroke Persistence

Strokes are archived as a compact binary blob, not JSON. A two-line sentence traced by a
child runs 3,000–8,000 sample points; JSON would be roughly 400 KB per attempt, which is
unacceptable when the goal is to keep every attempt forever and eventually sync it.

### 6.1 Format `HJST` v1

```
Header (8 bytes)
  magic        4  "HJST"
  version      1  0x01
  flags        1  reserved (0)
  strokeCount  2  UInt16, little-endian

Per stroke
  pointCount   2  UInt16
  points[]     10 bytes each:
     x         4  Float32   canvas coordinates
     y         4  Float32
     force     1  UInt8     force × 255, clamped
     inside    1  UInt8     0 = outside letter, 1 = inside
```

The blob is then compressed with `Compression` / LZFSE.

**Measured expectation:** 6,000 points → 60 KB raw → ~18–24 KB compressed. One archive per
sentence, not per attempt. A child writing daily for five years produces on the order of
15 MB of ink, plus roughly 25 MB of voice at ~200 KB per sentence. Both are viable
keepsakes and viable iCloud payloads.

**The eraser edits the archive.** Erasing removes points from the in-memory stroke set
before encoding; a stroke that loses its middle becomes two strokes. Nothing is written
until Done, so the archive is always the finished state.

**The `inside` flag is trace-specific.** It records whether a point fell inside the guide
letterform. Copy mode has no letterform under the pen, so the flag is meaningless there —
see §7.4. Reserve `flags` bit 0 to mean "no per-point inside data" before shipping, so a
Copy-mode archive is not misread as an all-outside trace.

### 6.2 Replay

```swift
enum StrokeArchive {
    static func encode(_ strokes: [TracingStroke]) throws -> Data
    static func decode(_ data: Data) throws -> [TracingStroke]
}
```

Rendering an archived attempt into a view of a different size uses an aspect-fit transform
derived from the stored `canvasWidth/Height`. Aspect ratio is preserved; the drawing is
letterboxed rather than stretched, because stretched handwriting looks wrong immediately.

`CustomStrokeRenderer` takes an ink mode:

```swift
enum InkMode { case natural, accuracy }
```

**Live writing always uses `.accuracy`. Journal review always uses `.natural`.** Neither is
user-switchable. Thumbnails are always `.natural`.

---

## 7. Tracing Engine (ported)

Carried over from TraceRight essentially as-is.

1. **Mask generation** — `MaskRenderer` lays the transcript out with `CTFramesetter` in the
   profile's **face at the profile's size**, draws it white-on-black into an 8-bit
   grayscale `CGContext` at screen scale, and keeps the raw pixel buffer.
2. **Guide rendering** — `GuideTextView` draws the *same* attributed string, so the mask and
   the visible guide cannot drift.
3. **Stroke colouring** — each sampled point is tested against the mask; `inside` is stored
   per point and drives both live colour and any later re-render.
4. **Scoring** — see §8.1. The mask is built **per glyph**, so every letter is scored
   independently and an untouched letter scores zero. Coverage as a separate metric is
   retired; per-letter grading already catches the child who traces one perfect letter.

**What per-glyph masks require.** `CTLine` exposes glyph runs and per-glyph bounding boxes;
render each glyph into its own mask region and keep an index from character position to
region. This is the one substantive change to the ported engine, and it is worth doing
properly — it is also what makes "which letters does this child struggle with" answerable
later.

### 7.1 What the font setting changes

The mask is generated from the chosen face. **A face must be vetted before it goes on the
list**: thin strokes give the child almost no tolerance, and a two-story `a` teaches a
letterform they are not being taught at school. `WIREFRAME_SPEC.md` §7.2 holds the current
list and the reason each face is on it. Adding one is a product decision, not a preference.

### 7.2 What the size setting changes

Font size and line spacing, from the table in `WIREFRAME_SPEC.md` §7.3. Nothing else. The
40 pt surface inset, the ruled-line construction and the 200-character cap are constant.

### 7.3 Stroke width

1.5–5.0 pt at Large, scaled linearly by `size / 72`. The quoted range is a Large-size
figure; applied literally at review or thumbnail scale it produces blobs.

### 7.4 Splitting a transcript into traceable pieces

The child speaks for up to five minutes; the writing surface holds one sentence. Between
those two facts sits the splitter.

**In order of preference:**

1. **Punctuation** from the recogniser (`addsPunctuation = true`). Reliable for adults,
   patchy for a five-year-old who says "and then and then".
2. **Pause detection** — gaps over ~700 ms between `SFTranscriptionSegment.timestamp`
   values. This is the one that actually works on children.
3. **The fit rule**, applied last and always: a piece must fit the writing surface.

**The fit rule is size-dependent and it bites.** Measured against the 754 pt surface:

| Size | pt | Lines | Fits |
|---|---|---|---|
| Extra Large | 96 | 3 | **~56 characters** |
| Large | 72 | 4 | ~99 |
| Medium | 56 | 6 | ~192 |
| Small | 42 | 8 | ~341 |
| Extra Small | 30 | 11 | ~658 |

At Extra Large an ordinary spoken sentence will not fit. The overflow is broken at the last
word boundary that fits and becomes a second `Sentence` with `partIndex = 1`; the review
screen labels it *"written in 2 parts"* rather than treating it as a problem.

**Measure with real font metrics, not character counts.** The five faces differ by up to
40% in advance width — Sniglet is 1.4× Jua. Lay the candidate out with `CTFramesetter` in
the profile's actual face and size and ask how many lines it takes.

**Re-tracing at a larger size may no longer fit.** A sentence written at Small and
re-traced at Extra Large can overflow. Split it again at that point; the journal keeps the
sentence text, which is the durable thing.

### 7.5 Copy mode — a warning before it is scheduled

Copy mode asks the child to write on a **blank ruled line beneath** the words rather than
over them. It is a natural next step pedagogically and it looks like a small change. It is
not.

**Tracing has ground truth; copying does not.** Accuracy today means "what fraction of the
child's points fell inside the letterform". In Copy mode there is no letterform under the
pen — the target is somewhere else on the screen. The current scoring algorithm cannot
produce a number, and neither can a translated version of it: a child's copy is a different
size, a different slant, and differently spaced from the model.

Scoring Copy mode needs a different class of algorithm — per-letter segmentation followed
by shape matching (Procrustes distance, elastic matching, or a small on-device classifier).
That is weeks of work and a different accuracy scale, not a mode flag.

**Recommended sequencing:**

1. Ship Trace mode. Let the data accumulate.
2. Add Copy mode **without a score first** — a blank line, the model above, and the child's
   ink kept in the journal. Genuinely useful, and honest.
3. Add Copy scoring only when there is an algorithm worth trusting, and give it its **own
   scale** with its own name. Do not put a Copy percentage in the same column as a Trace
   percentage; they will not mean the same thing.

The data model is ready for this: `modeRaw` is already on the session and the attempt, and
Progress already breaks down by mode.

---

## 8. Scoring, Streaks and Badges

### 8.1 Accuracy is per letter

```
letterAccuracy(i) = pointsInsideGlyph(i) / pointsAttemptedOnGlyph(i)
                    (0 if the child never touched glyph i)

sentenceAccuracy  = mean(letterAccuracy) over every glyph, spaces excluded
```

A letter with no ink scores **0%**. That single rule is what makes the number honest: it
turns "traced four letters of twenty-eight and tapped Done" from ~95% into ~14%.

**Live and final differ on purpose.**

| | Denominator |
|---|---|
| **Live** — shown while writing as *"So far: NN%"* | Only letters the child has started |
| **Final** — computed at Done | Every letter, unstarted ones at 0% |

If the live figure applied the penalty it would begin at 0% and crawl upward for the whole
sentence, which reads as continuous failure. The unfinished count is surfaced separately —
*"16 letters still to go"* — so the child is warned without being scored down in real time.

Reveal states the outcome plainly: *"Every letter was finished"* or *"2 letters were not
finished."*

### 8.2 Stars

| Accuracy | Stars |
|---|---|
| ≥ 90% | ★★★ |
| ≥ 75% | ★★☆ |
| ≥ 60% | ★☆☆ |
| < 60% | ☆☆☆ |

Stars rate **one tracing**. They no longer accumulate toward anything, because there is no
longer anything to accumulate toward.

### 8.3 Points

```
points = round(accuracy)
       + stars × 25
       + min(currentStreak, 5) × 5
       + 30                        // session completion bonus
```

Worked from `WIREFRAME_SPEC.md` §14: 78 + 50 + 25 + 30 = **183**; 94 + 75 + 25 + 30 = **224**.

Points are a running total with no ceiling and nothing to spend them on. They exist because
a number that only goes up is quietly motivating, and because nothing is gated behind them.

### 8.4 Streaks

A streak counts consecutive **days** with at least one completed session. Missing a day
resets it. `longestStreak` is kept forever.

### 8.5 Badges

None reference levels.

| ID | Name | Earned when |
|---|---|---|
| `first_entry` | First Entry | First traced sentence |
| `sharp_shooter` | Sharp Shooter | Any tracing at 90% or better |
| `streak_5` | 5-Day Streak | Streak reaches 5 |
| `ten_sessions` | Ten Sessions | 10 completed sessions |
| `perfect_week` | Perfect Week | Wrote on 7 consecutive days |
| `hundred_sentences` | 100 Sentences | 100 sentences traced |
| `every_font` | Every Font | At least one tracing in each of the five faces |
| `neat_writer` | Neat Writer | Five consecutive sentences at 85% or better |

`every_font` exists partly to make a child try Andika, which many of them read more easily
than they read Jua.

---

## 9. iCloud Readiness

Not built in v1, but the model is authored so it can be switched on without a migration:
every property has a default, every relationship is optional, and every large blob is
`.externalStorage` so it maps to a `CKAsset`. `NSPersistentCloudKitContainer` semantics are
assumed throughout. Settings carries a disabled "iCloud Sync — Coming soon" row so the
intent is visible.

---

## 10. Privacy and Permissions

### 10.1 What leaves the device

Nothing, unless a grown-up taps Share. Speech recognition is on-device
(`requiresOnDeviceRecognition = true`). There is no analytics SDK, no crash reporter, no
network code at all in v1.

### 10.2 Permissions

Microphone and speech recognition, preceded by a **child-legible explainer screen**
(frame 40) before the iOS dialog appears — the system prompt is written for adults. Camera,
requested only when Take Photo is tapped. Photo library, via `PhotosPicker`, which needs no
permission prompt. Every permission has a working fallback: refusing the microphone leaves
the keyboard, refusing the camera leaves the photo library and the initial-letter avatar.

### 10.4 The child's voice

The whole session is recorded before it is transcribed. **The master recording is then
sliced into per-sentence clips** using the recogniser's segment timestamps, the clips are
kept (`Sentence.audioData`, AAC mono, ~30 KB each), and the master is discarded.

That last step matters. A five-minute master at 32 kbps is ~1.2 MB; kept daily for five
years that is over 2 GB. Per-sentence clips for the same period come to roughly 250 MB, and
they are what the interface actually needs — *"Hear it"* sits on a sentence, not on a
session. If keeping the raw telling ever seems worth it, make it an explicit setting with
the size stated, not a default.

This is the most sensitive data the app holds, and it is worth being explicit about:

- It **never leaves the iPad**. There is no network code.
- It is covered by the same courtesy-lock caveat as everything else (§10.3): a PIN is not
  encryption.
- Deleting a sentence deletes its recording. Deleting a profile deletes all of them.
- The explainer screen says so in words a child can read: *"Your voice stays on this iPad."*

The reason to keep it is simple and it is not a feature request from the child: in three
years, the sentence in their handwriting *paired with* their five-year-old voice saying it
is the artefact. You cannot record 2026 retroactively — capture from day one even if
playback UI comes later.

### 10.3 PINs and the missing parent gate — read this

**A profile PIN is a courtesy lock, not security.** It is `SHA256(salt ‖ pin)` with a
per-profile 16-byte random salt. It keeps a sibling out of a sibling's journal. It will not
stop a determined adult, and nothing on disk is encrypted beyond iOS file protection. This
is stated in plain language in Settings.

**The parent gate was removed in v2.0.** In v1, Delete Profile and Reset Progress sat behind
a small multiplication question. Those actions are now reachable by anyone holding the
iPad, including the six-year-old whose sibling's journal is one tap away.

The actions are labelled "Grown-ups only" and Settings says plainly that they are not
gated. That is honest, but honesty is not a control. **Recommendation: put a gate back
before shipping** — it does not have to be arithmetic. A press-and-hold for three seconds,
or a "type DELETE" confirmation, would stop a young child without the puzzle feeling like a
puzzle. This is recorded as an accepted risk, not as a solved problem (§16).

---

## 11. Visual Design

### 11.1 Palette

See `WIREFRAME_SPEC.md` §5. Paper, graphite, one blue, and green/red reserved exclusively
for accuracy. Light only; the app is a paper journal.

### 11.2 Typography

UI chrome in SF Pro Rounded. Journal content in the profile's chosen face at the profile's
chosen size (`WIREFRAME_SPEC.md` §7.2–7.3). Accepted sentences render at half size in the
writing-so-far panel.

### 11.3 Motion

| Moment | Motion |
|---|---|
| Standard transition | 0.30 s ease-in-out |
| Typed ↔ Handwritten | 0.35 s 3-D flip, y-axis |
| Guide fade on reveal | 0.50 s |
| **Sentence settles into the page** | **0.45 s shrink-and-rise, then scroll to bottom** |
| Badges, stars | spring, response 0.4, damping 0.7 |

Reduce Motion replaces the flip and the settle with cross-fades.

---

## 12. Accessibility

- Dynamic Type for all UI chrome. Journal content is fixed at the chosen size — it is the
  subject of the exercise, not chrome.
- VoiceOver labels on every control; the journal page reads its transcript, not its strokes.
- Colorblind ink scheme swaps green/red for blue/orange, per profile.
- Finger tracing is a per-profile toggle for children without a stylus.
- Left-handed layout mirrors the toolbar actions so a hand does not cover the writing.
- Minimum tap target 44 × 44; child-facing primary actions at least 280 × 64.

---

## 13. File Structure

```
HandwrittenJournal/
  App/            HandwrittenJournalApp, ContentView, NavigationState, AppConstants
  Models/         UserProfile, WritingSession, Sentence, Badge
  Services/       MaskRenderer (per-glyph), StrokeColorizer, ScoringEngine, BadgeEngine,
                  StrokeArchive, StrokeEraser, SpeechRecognitionService,
                  TranscriptSplitter, VoiceRecorder, AudioSlicer, AudioService,
                  HapticsService, PDFBookBuilder
  ViewModels/     ProfileViewModel, SessionViewModel, DictationViewModel,
                  TracingViewModel, ProgressViewModel
  Views/          ProfilePickerView, ProfileEditorView, PinPadView, AvatarCaptureView,
                  JournalHomeView, JournalListView, CalendarView, EntryDetailView,
                  ExportView, JournalBookExportView,
                  WriteSessionView (dictate → review → trace → reveal),
                  SentenceReviewView, SentenceEditView,
                  ResultsView, ProgressView, SettingsView, FontPickerView, SizePickerView
    Components/   WritingSoFarPanel, WritingSurface, RuledLinesView, EraserCursor,
                  QueueChip, LevelMeter, StarRatingView, ProgressRingView, BadgeView,
                  StreakView, SessionCard, SessionRow, UnfinishedRow, SentenceRow,
                  SentenceReviewRow, AudioPlayButton
  Resources/      Fonts (Jua, Andika, Baloo2, Sniglet, ComicNeue), Assets
```

`AppConstants.swift` is generated from `WIREFRAME_SPEC.md` §5–§9 and should not be
hand-edited.

---

## 14. Testing Strategy

Ported from TraceRight: `ScoringEngineTests`, `MaskRendererTests`, `StrokeColorizerTests`,
`BadgeEngineTests`. `LevelTests` is **deleted** — there are no levels.

New:

- `StrokeArchiveTests` — round-trip fidelity, size expectations, corrupt-blob handling.
- `SessionTests` — append ordering, session close on background, resuming an unfinished
  session at the right sentence.
- `TranscriptSplitterTests` — the important one alongside per-letter scoring. Punctuation,
  pause and fit paths; a sentence that needs three parts; the same transcript splitting
  differently at Extra Large and Extra Small; word boundaries never broken mid-word;
  measurement uses the profile's real face.
- `MaskRendererFontTests` — the mask matches the visible guide for **every face on the
  list**, at every size. This is the test that catches a badly chosen font.
- `PerLetterScoringTests` — the important one. An untouched glyph scores 0; a sentence with
  four of twenty-eight letters traced scores near 14%, not near 95%; the live figure
  excludes unstarted letters while the final figure includes them; spaces are not scored.
- `EraserTests` — points inside the circle are removed, a stroke split in the middle becomes
  two strokes, and the touched letters are re-scored while the others are untouched.
- `ProgressBreakdownTests` — per-setting aggregation, and that a settings change does not
  relabel old sessions.

---

## 15. Development Phases

| Phase | Contents |
|---|---|
| **1** | Profiles, PIN, SwiftData model, Journal Home shell |
| **2** | Long-form dictation → split → review → trace → reveal, Trace mode only. The splitter, the eraser and per-letter scoring all land here — none of them are polish. |
| **3** | **The append loop**: writing-so-far panel, settle animation, the sentence queue, resuming an unfinished session, Results |
| **4** | Journal list, calendar, Entry Detail with the typed/handwritten flip |
| **5** | Stroke archive, thumbnails, voice capture and playback |
| **6** | Font and size pickers, per-glyph masks, mask verification across faces |
| **7** | Progress, badges, streaks |
| **8** | Export — single page **and the whole-journal book** — Settings polish, accessibility pass |

Phase 3 is the one that makes it this app rather than TraceRight with a database. Do not
defer it.

---

## 16. Risks

| Risk | Mitigation |
|---|---|
| **Copy mode is not a mode flag** (§7.4) | Ship it unscored first, or budget for a real matching algorithm |
| **Destructive actions are ungated** (§10.3) | Accepted for now; recommend a hold-to-confirm before shipping |
| Speech recognition on young voices | Confirmation step, editable transcript, keyboard fallback |
| A chosen font traces badly | Curated list only, plus `MaskRendererFontTests` |
| **Per-glyph masks are a real engine change** | Budget for it in phase 2; `CTLine` glyph runs give the bounding boxes |
| **Latest-only means a bad re-trace destroys a good one** | "Trace This Again" must say *"This will replace what you wrote"* |
| **Five minutes of speech is ~20 minutes of tracing** | Stopping part-way is the easy path: exit on every screen, resume card first on Home, no warning language |
| **The splitter is the least testable part of the app** | `TranscriptSplitterTests` with real child-speech transcripts, not adult ones |
| **The review screen asks a five-year-old to do editorial work** | It is forgiving by default — every row is already correct-enough to trace; edit/split/join are for a grown-up who wants them |
| Voice recordings are the most sensitive data here | On-device only, deleted with the sentence, stated plainly in child-legible copy (§10.4) |
| Scroll gesture vs. pencil stroke | Writing surface never scrolls; only the read-only panel does |
| Stroke archive growth | Measured at ~20 KB/attempt; 40 MB over five years |
| A child changes their own font/size constantly | Settings are per profile and reachable; accepted — the Progress table stays honest either way |

---

## 17. Deliberately Out of Scope for v1

- Copy mode scoring (§7.4)
- Levels, unlocks, or any earned progression
- Landscape
- iPhone
- Dark mode
- Accounts, sharing between devices, anything social
- iCloud sync beyond a disabled row
- Cursive
- Languages other than English
- Attempt history — only the latest tracing is kept, by decision
- Stroke replay animation
- Read-aloud of journal text — the child using this app can read
- Writing prompts or suggestions — this is a journal, not a teacher

---

## 18. Companion Documents

- `WIREFRAME_SPEC.md` v2.2 — measurements, tokens, component library, frame inventory
- `PENPOT_HANDOFF.md` — what the built Penpot file does differently and why
- `Original Traceright App/` — the working tracing engine this is ported from

---

*Document version: 2.2*
*Last updated: 2026-08-27*
