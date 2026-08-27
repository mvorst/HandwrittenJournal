# Handwritten Journal

## Design Document v1.0

---

## 1. Overview

**Handwritten Journal** is an iPad app in which a child speaks a thought, sees it
transcribed, traces over the transcribed words with an Apple Pencil, and keeps the
result forever as a dated journal entry. Every entry can be read two ways: as clean
typed text, or as the child's own handwriting exactly as they traced it. A scoring
and level system tracks handwriting accuracy so improvement is visible over months,
not just within a single session.

It is a journal first and a handwriting exercise second. The tracing engine is ported
from **TraceRight** (`Original Traceright App/`, kept in this repository for reference
only). This document describes only the new app.

**Platform:** iPad (Apple Pencil recommended, finger tracing supported)
**Target OS:** iPadOS 18.0+
**Frameworks:** SwiftUI · SwiftData · Speech · CoreText · CoreGraphics · Swift Charts · CryptoKit · AVFoundation

### 1.1 Project Identity

| Setting | Value |
|---|---|
| App bundle ID | `com.mattvorst.education.journal` |
| Test bundle ID | `com.mattvorst.education.journal.tests` |
| iCloud container (phase 9) | `iCloud.com.mattvorst.education.journal` |
| Product name | `HandwrittenJournal` |
| Display name | Handwritten Journal |
| Deployment target | iPadOS 18.0 |
| Device family | iPad only (`TARGETED_DEVICE_FAMILY = 2`) |
| Swift version | 6.0 |

The reference app shipped under `ai.thebridgeto.*` with development team `NBEPYFWX3J`.
This app uses a personal identifier instead; the signing team is confirmed when the
Xcode project is created.

---

## 2. What Is Different From TraceRight

TraceRight is a single-player practice game: dictate, trace, score, discard. Handwritten
Journal keeps the tracing engine and the scoring loop, and adds four things:

| # | Change | Consequence |
|---|--------|-------------|
| 1 | **Traces are persisted** | Stroke data is archived per attempt and re-rendered on demand — an entry is readable years later |
| 2 | **Multiple user profiles** | Name, photo, optional PIN; progress, badges and journal are all per-profile |
| 3 | **A journal to browse** | Chronological list, entry detail, typed ↔ handwritten toggle, attempt history |
| 4 | **Progress over time** | Charts answering "is he actually getting better?", level-aware so the comparison is honest |

Deliberately carried over unchanged: the CoreText mask renderer, per-point inside/outside
classification, green/red live ink, the 10-level shrinking-font ladder, stars, points,
streaks and badges.

Deliberately dropped: the cosmetic rewards store (points now serve progression only,
not a shop). It can return later without a model change.

---

## 3. User Flow

```
                          ┌──────────────────┐
   launch ───────────────▶│  Profile Picker  │◀──── "Switch user"
                          └────────┬─────────┘
                                   │ (PIN pad if the profile has one)
                                   ▼
                          ┌──────────────────┐
                ┌────────▶│  Journal Home    │◀────────────┐
                │         └────────┬─────────┘             │
                │                  │ "New Entry"           │
                │                  ▼                       │
                │         ┌──────────────────┐             │
                │         │   Dictation      │             │
                │         │  + edit transcript│            │
                │         └────────┬─────────┘             │
                │                  ▼                       │
                │         ┌──────────────────┐             │
                │         │   Tracing        │             │
                │         └────────┬─────────┘             │
                │                  ▼                       │
                │         ┌──────────────────┐             │
                │         │   Reveal         │             │
                │         │ (guide fades out)│             │
                │         └────────┬─────────┘             │
                │                  ▼                       │
                │         ┌──────────────────┐             │
                │         │   Results        │──"Trace again"──┐
                │         └────────┬─────────┘             │   │
                │                  ▼                       │   │
                │         ┌──────────────────┐             │   │
                └─────────│  Journal List    │─────────────┘   │
                          └────────┬─────────┘                 │
                                   ▼                           │
                          ┌──────────────────┐                 │
                          │  Entry Detail    │─────────────────┘
                          │ Typed ↔ Written  │
                          └──────────────────┘
```

---

## 4. Screen Specifications

### 4.1 Profile Picker (launch screen)

```
┌────────────────────────────────────────────────────────────────┐
│                                                        [⚙]     │
│                    Handwritten Journal                         │
│                     Who's writing today?                       │
│                                                                │
│      ╭───────╮      ╭───────╮      ╭───────╮     ╭───────╮    │
│      │ photo │      │ photo │      │ photo │     │   +   │    │
│      ╰───────╯      ╰───────╯      ╰───────╯     ╰───────╯    │
│        Milo           Ada            Dad          Add someone  │
│         🔒                             🔒                       │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

- Circular avatars, ~160pt, in a horizontally centered grid; name below, small lock
  glyph if the profile has a PIN.
- Tapping a profile with no PIN enters it immediately. With a PIN, a 4-digit pad slides
  up; a wrong PIN shakes the dots, no lockout, no error copy beyond "Try again".
- Long-press a profile → **Edit profile** (parent gate required for Delete only).
- The gear opens app-wide settings (appearance, about, iCloud toggle).
- The last-used profile is remembered and highlighted, but never auto-entered — choosing
  a person is the deliberate first act of the app.

### 4.2 Profile Setup / Edit

```
┌────────────────────────────────────────────────────────────────┐
│  [Cancel]              New Profile                    [Save]   │
│                                                                │
│                        ╭─────────╮                             │
│                        │  photo  │   [ 📷 Take Photo ]         │
│                        ╰─────────╯   [ 🖼 Choose Photo ]       │
│                                                                │
│   Name        ┌──────────────────────────────────────┐         │
│               │  Milo                                │         │
│               └──────────────────────────────────────┘         │
│                                                                │
│   Secret PIN  ( ) No PIN                                       │
│               (•) Use a 4-digit PIN     • • • •   [Change]     │
│                                                                │
│   Starting level   ◀  Level 1  ▶     (parent-only, default 1)  │
│                                                                │
│                        [ Delete Profile ]  ← parent gate       │
└────────────────────────────────────────────────────────────────┘
```

- **Photo:** front-facing camera sheet (`AVCapturePhotoOutput`) with a circular mask and
  a 3-2-1 countdown, or PhotosPicker. Result is center-cropped square, downscaled to
  512×512, JPEG q0.8 (~40 KB), stored in the model as external-storage `Data`.
- **Name:** 1–20 characters, trimmed.
- **PIN:** 4 digits, entered twice. Stored as `SHA256(salt || pin)` with a per-profile
  random 16-byte salt (CryptoKit). This is not security — it keeps a sibling out of a
  sibling's journal. Documented as such in Settings.
- **Starting level** lets a parent skip a competent writer past level 1.

### 4.3 Journal Home

```
┌────────────────────────────────────────────────────────────────┐
│  ╭──╮ Milo                                    [📈]  [⚙]        │
│  ╰──╯ 🔥 5-day streak                                          │
│                                                                │
│   ┌────────────────────────────────────────────────────────┐   │
│   │  LEVEL 3   ████████████░░░░░░  15 / 27 stars           │   │
│   └────────────────────────────────────────────────────────┘   │
│                                                                │
│                  ┌──────────────────────┐                      │
│                  │    ✎  New Entry      │                      │
│                  └──────────────────────┘                      │
│                                                                │
│   Recent ─────────────────────────────────────── [See all ▸]   │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│   │ ~~~~~~~~ │ │ ~~~~~~~~ │ │ ~~~~~~~~ │ │ ~~~~~~~~ │          │
│   │ Mar 4    │ │ Mar 3    │ │ Mar 1    │ │ Feb 27   │          │
│   │ ★★★      │ │ ★★☆      │ │ ★★★      │ │ ★☆☆      │          │
│   └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│                                                                │
│   Badges ──────────────────────────────────────────────        │
│   [🏆] [🎯] [🔥] [░░] [░░] [░░] [░░] [░░]  ▸                  │
│                                                                │
│   ╭──╮ Switch user                                             │
└────────────────────────────────────────────────────────────────┘
```

Recent-entry cards show the **handwriting thumbnail**, not the typed text — the journal
should look like a journal at a glance.

### 4.4 Dictation

Identical to TraceRight's dictation screen (`SFSpeechRecognizer`, on-device, `en-US`,
live partial results, pulsing mic, 200-character cap, keyboard fallback) with one
addition:

**Transcript confirmation step.** After "Done", the recognized text appears in an
editable field rendered in the guide font, with a caption *"Is that right? Tap to fix
it."* Speech recognition is unreliable for six-year-olds, and tracing a mis-heard
sentence is demoralizing. Buttons: **Try Again** (re-record), **Write It** (proceed).

The entry is persisted at this point as a **draft** (see §5.2), so a sentence can be
queued and traced later.

### 4.5 Tracing

Unchanged from TraceRight, plus the entry date in the title bar.

```
┌────────────────────────────────────────────────────────────────┐
│  Level 3   ·  Mar 4              [Undo] [Clear]      [Done ✓]  │
├────────────────────────────────────────────────────────────────┤
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│   I   s a w   a   r e d   b i r d                             │
│ ───────────────────────────────────────────────────────────    │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│   i n   t h e   y a r d                                        │
│ ───────────────────────────────────────────────────────────    │
├────────────────────────────────────────────────────────────────┤
│  Live accuracy: 78%                                            │
└────────────────────────────────────────────────────────────────┘
```

Green inside the letters, red outside, in real time. `Clear` resets the ink without
counting an attempt. `Done` ends capture and moves to Reveal.

### 4.6 Reveal

Guide text fades over 0.5 s leaving only the child's ink. The primary button reads
**"Save to My Journal"** rather than "See My Score" — saving is the point; the score is
what happens next. Scoring, badge checks, streak update and persistence all run on tap.

### 4.7 Results

```
┌────────────────────────────────────────────────────────────────┐
│                      Great job, Milo!                          │
│                          ★ ★ ☆                                 │
│                     ╭─────────────╮                            │
│                     │     78%     │                            │
│                     │  Accuracy   │                            │
│                     ╰─────────────╯                            │
│              + 190 points   ·   Best yet at Level 3 ✨          │
│                                                                │
│           🏆  NEW BADGE: "Sharp Shooter"                       │
│                                                                │
│   [Trace Again]     [New Entry]     [See My Journal]           │
└────────────────────────────────────────────────────────────────┘
```

"Best yet at Level N" appears when the attempt beats the profile's previous best
accuracy at the same level — the most motivating comparison available, and honest
because it is level-matched.

**Trace Again** returns to Tracing with the same text and appends a *new attempt* to the
same entry; it never overwrites.

### 4.8 Journal List

```
┌────────────────────────────────────────────────────────────────┐
│  [← Home]        My Journal          [🔍]  [📅]  [Filter ▾]    │
├────────────────────────────────────────────────────────────────┤
│  TO WRITE (2)                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  "Tomorrow we go to the museum"          [ Write it ▸ ]  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  MARCH 2026                                                    │
│  ┌────────┐  Mar 4                                     ★★★    │
│  │~~~~~~~~│  "I saw a red bird in the yard"                    │
│  │~~~~~~~~│  3 tracings · best 94% · Level 3                   │
│  └────────┘                                                    │
│  ┌────────┐  Mar 3                                     ★★☆    │
│  │~~~~~~~~│  "We made pancakes with Grandma"                   │
│  │~~~~~~~~│  1 tracing · 81% · Level 3                         │
│  └────────┘                                                    │
│                                                                │
│  FEBRUARY 2026                                                 │
│  ...                                                           │
└────────────────────────────────────────────────────────────────┘
```

- Sectioned by month, newest first, with the handwriting thumbnail as the leading visual.
- **Search** matches the transcript text.
- **Calendar view** (📅) shows a month grid with a dot on every day that has an entry —
  the classic journal affordance, and a visible streak record.
- **Filter** by star rating or level.
- Swipe-to-delete requires the parent gate.

### 4.9 Entry Detail — the toggle

This is the heart of the app.

```
┌────────────────────────────────────────────────────────────────┐
│  [← Journal]      Wednesday, March 4              [⋯]          │
│                                                                │
│              ╭─────────────┬──────────────────╮                │
│              │    Typed    │   Handwritten    │  ← segmented   │
│              ╰─────────────┴──────────────────╯                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                                                          │  │
│  │   I saw a red bird in the yard                           │  │
│  │                                                          │  │
│  │   ── or, flipped ──                                      │  │
│  │                                                          │  │
│  │   ✍ (his actual strokes, re-rendered)                    │  │
│  │                                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│   ◀  Tracing 3 of 3  ·  Mar 4, 4:12 PM  ·  ★★★ 94%  ▶         │
│   [ Show accuracy colors ]                                     │
│                                                                │
│   [ Trace This Again ]        [ Share ]                        │
└────────────────────────────────────────────────────────────────┘
```

- **Typed** renders the transcript on the same ruled-paper background, in the guide font
  at the entry's level — so the two states are visually comparable, not one plain and
  one pretty.
- **Handwritten** renders the archived strokes on the same paper. Default ink is
  **natural** (graphite `#2C2C2E`), because a journal should read like handwriting.
- **Show accuracy colors** re-renders the same strokes green/red. The inside/outside flag
  is stored per point, so both renderings are free — no re-scoring, no re-analysis.
- Switching states uses a horizontal 3-D flip (`rotation3DEffect`, 0.35 s), which reads
  to a child as "turning the page over". Reduce Motion replaces it with a cross-fade.
- **Attempt pager** appears only when the entry has more than one tracing. Stepping
  through them is the single most direct view of improvement on identical text.
- **⋯ menu:** Rename entry · Export as PNG/PDF · Delete (parent gate).
- **Share** exports the handwritten rendering as a PNG or a one-page PDF with the date
  and typed text as a caption.

### 4.10 Progress

```
┌────────────────────────────────────────────────────────────────┐
│  [← Home]              Milo's Progress          [30d|90d|All]  │
│                                                                │
│  Accuracy over time                                            │
│  100% ┤                                          ╭─╮           │
│       │                    ╭──╮        ╭────╮   ╱   ╲          │
│   75% ┤        ╭───╮      ╱    ╲──────╱      ╲─╯     ╲         │
│       │   ╭───╯     ╲────╯                            ╲        │
│   50% ┤──╯                                                     │
│       └──┬──────────┬──────────┬──────────┬──────────┬──       │
│          Jan       Feb        Mar        Apr        May        │
│            ▲L2        ▲L3                   ▲L4                │
│          (level changes marked — accuracy dips are expected)   │
│                                                                │
│  Per level        Best     Average    Tracings                 │
│  ───────────────────────────────────────────────               │
│  Level 1          97%        88%         31                    │
│  Level 2          95%        84%         44                    │
│  Level 3          94%        79%         18   ← current        │
│                                                                │
│  Entries written: 62      Days journaled: 47                   │
│  Longest streak: 11 days  Current: 5 days                      │
└────────────────────────────────────────────────────────────────┘
```

**The level caveat is the most important design decision on this screen.** Raw accuracy
drops every time the level advances, because the letters get smaller and thinner. A naive
"accuracy over time" line would tell a child they are getting worse at exactly the moment
they earned a promotion. Therefore:

1. Level-change dates are marked on the time axis.
2. The line is a 5-attempt rolling average (single attempts are too noisy to read).
3. The **per-level table is the honest comparison** and gets equal visual weight.
4. Trend copy is computed within the current level only: *"At Level 3, your last 5
   tracings averaged 79% — up from 71%."*

Built with Swift Charts.

### 4.11 Settings

Per profile: name, photo, PIN, left-handed layout, sound, haptics, guide lines,
finger tracing allowed, colorblind ink scheme, reset progress (parent gate).

App-wide: iCloud sync toggle (see §8), about, and a plain-language note that PINs are a
courtesy lock, not security.

---

## 5. Data Model

SwiftData, authored to CloudKit's constraints from day one (§8).

### 5.1 UserProfile

```swift
@Model final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now
    var isParent: Bool = false

    // Photo — external storage so it syncs as a CKAsset later
    @Attribute(.externalStorage) var avatarImageData: Data?

    // PIN — courtesy lock only
    var pinSalt: Data?
    var pinHash: Data?

    // Progress
    var currentLevel: Int = 1
    var startingLevel: Int = 1
    var totalStars: Int = 0
    var totalPoints: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastWroteOn: Date?
    var totalAttempts: Int = 0
    var threeStarCount: Int = 0
    var perfectCount: Int = 0
    var earnedBadgeIDs: [String] = []

    // Preferences
    var isLeftHanded: Bool = false
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var guideLinesEnabled: Bool = true
    var allowFingerTracing: Bool = false
    var colorBlindMode: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.author)
    var entries: [JournalEntry]?

    init(name: String = "") { self.name = name }
}
```

### 5.2 JournalEntry

```swift
enum EntryState: Int, Codable { case draft = 0, written = 1 }

@Model final class JournalEntry {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var text: String = ""            // confirmed transcript — what gets traced
    var rawTranscript: String = ""   // what the recognizer originally heard
    var customTitle: String?         // nil ⇒ derive from text
    var stateRaw: Int = EntryState.draft.rawValue
    var author: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \TraceAttempt.entry)
    var attempts: [TraceAttempt]?
}
```

An entry is created at transcript confirmation in the `draft` state and promoted to
`written` on its first saved attempt. Drafts surface in the "To write" section of the
journal list, which lets a parent queue sentences ahead of time. *(Optional — the
feature can be dropped without touching the model; drafts would simply be deleted on
abandon.)*

### 5.3 TraceAttempt

```swift
@Model final class TraceAttempt {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var level: Int = 1
    var accuracy: Double = 0
    var coverage: Double = 0
    var stars: Int = 0
    var points: Int = 0

    // Geometry the strokes were captured at, for faithful replay
    var canvasWidth: Double = 0
    var canvasHeight: Double = 0

    @Attribute(.externalStorage) var strokeArchive: Data?   // §6
    @Attribute(.externalStorage) var thumbnailData: Data?   // ~600pt PNG for lists

    var entry: JournalEntry?
}
```

Storing `level` plus `canvasWidth/Height` plus the entry's `text` means the *exact*
guide layout can be reproduced at any time — the mask renderer is deterministic given
those inputs. That keeps a future "ink over guide" review state, or a re-score under a
revised algorithm, available without a migration.

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

**Measured expectation:** 6,000 points → 60 KB raw → ~18–24 KB compressed. A child
writing daily for five years produces on the order of 40 MB of ink. That is a viable
keepsake and a viable iCloud payload.

### 6.2 Replay

```swift
enum StrokeArchive {
    static func encode(_ strokes: [TracingStroke]) throws -> Data
    static func decode(_ data: Data) throws -> [TracingStroke]
}
```

Rendering an archived attempt into a view of a different size uses an aspect-fit
transform derived from the stored `canvasWidth/Height`, so a trace captured in landscape
on a 12.9" iPad reads correctly in a portrait list row on an iPad mini. Aspect ratio is
preserved; the drawing is letterboxed rather than stretched, because stretched
handwriting looks wrong immediately.

`CustomStrokeRenderer` gains an ink-mode parameter:

```swift
enum InkMode { case natural, accuracy }
```

`.natural` draws every segment in graphite; `.accuracy` draws green/red from the stored
`inside` flag. Live tracing always uses `.accuracy`; journal review defaults to
`.natural`.

---

## 7. Tracing Engine (ported)

Carried over from TraceRight essentially as-is. Summarised here so this document stands
alone; see the reference project for the working implementation.

1. **Mask generation** — `MaskRenderer` lays the transcript out with `CTFramesetter` at
   the current level's font size/weight, draws it white-on-black into an 8-bit grayscale
   `CGContext` at screen scale, and keeps the raw pixel buffer.
2. **Guide rendering** — `GuideTextView` draws the *same* attributed string through the
   *same* framesetter into the visible layer, guaranteeing pixel alignment with the mask,
   plus ruled baselines, dashed x-height and descender lines.
3. **Input capture** — a transparent `UIView` overlay handles `touchesBegan/Moved/Ended`
   directly (not PencilKit), reading coalesced touches for full-rate sampling and
   `touch.force` for stroke width. On device it filters to `touch.type == .pencil`
   unless the profile allows finger tracing; in the simulator it accepts any touch.
4. **Classification** — each sampled point is tested against the mask with a circular
   tolerance radius that shrinks from 4 px at level 1 to 0 px at level 8+.
5. **Rendering** — `StrokeRenderView` redraws the accumulated strokes each frame through
   `CustomStrokeRenderer`.

Changes required for the journal:

- `TracingViewModel` gains `strokeArchive()` and a thumbnail renderer for save.
- `CustomStrokeRenderer.render` takes `InkMode` and an optional fit transform.
- A `GuideTextRenderer` is factored out of `GuideTextView` so the Entry Detail "Typed"
  state can reuse the identical layout offscreen.

---

## 8. Scoring, Levels and Badges

Unchanged from TraceRight, now scoped per profile.

**Stars** — 3 at ≥90% accuracy, 2 at ≥70%, 1 at ≥50%, 0 below, with encouraging copy
personalised by name at every tier.

**Points** — `round(accuracy×100) + stars×25 + streak×5 + level×10`.

**Levels** — the same 10-rung ladder from 96 pt Black down to 24 pt Thin, gated on
cumulative stars (0/6/15/27/42/60/82/108/138/172).

**Streak** — one saved tracing on a calendar day extends it; a missed day resets to 1.
`longestStreak` is new and never resets, so a broken streak does not erase the record
of the good one.

**Badges** — the accuracy, streak, level and volume sets carry over, with volume badges
renamed to journal language (*First Entry*, *Ten Days of Thoughts*, *A Hundred Pages*,
*Year of Words*). Badge unlock logic is unchanged.

---

## 9. iCloud Readiness

v1 ships **local only**. The models are nevertheless authored to CloudKit's rules so the
switch is a configuration change, not a migration:

- Every non-optional property has a default value.
- No `@Attribute(.unique)` anywhere. Identity is a `UUID` the app manages, deduplicated
  in application code if sync is enabled later.
- Every relationship is optional and has an explicit inverse.
- No `.deny` delete rules.
- Large binaries (`avatarImageData`, `strokeArchive`, `thumbnailData`) use
  `.externalStorage`, which CloudKit carries as `CKAsset`.

Enabling sync later means: add the iCloud capability with container
`iCloud.com.mattvorst.education.journal`, add the background-modes entitlement, and
change the model configuration from `.none` to `.private(container)`. The Settings toggle
is present in v1, disabled, with the caption "Coming soon".

**Family semantics to note when it is enabled:** the CloudKit private database is scoped
to one Apple Account. All profiles on the device sync to that account's devices — which
is what a family iPad wants — rather than each child syncing to their own account.

---

## 10. Privacy and Permissions

| Permission | Purpose | Info.plist key |
|---|---|---|
| Microphone | Dictation | `NSMicrophoneUsageDescription` |
| Speech Recognition | Transcription | `NSSpeechRecognitionUsageDescription` |
| Camera | Profile photo | `NSCameraUsageDescription` |
| Photo Library (read) | Choosing a profile photo | `NSPhotoLibraryUsageDescription` |

- Speech recognition is forced on-device (`requiresOnDeviceRecognition = true`). No audio
  and no transcript leaves the device.
- Per this design, **audio is not retained** — only the recognized text. The recognition
  buffer is discarded when dictation ends.
- No analytics, no network calls, no third-party SDKs.
- Usage strings are written for a parent reading them on a child's device.

---

## 11. Visual Design

### 11.1 Palette

| Role | Colour | Hex |
|---|---|---|
| Paper background | Warm off-white | `#FAF8F5` |
| Natural ink (journal review) | Graphite | `#2C2C2E` |
| Inside stroke (accuracy mode) | Green | `#34C759` |
| Outside stroke (accuracy mode) | Red | `#FF3B30` |
| Colorblind inside / outside | Blue / Orange | `#007AFF` / `#FF9500` |
| Guide text | Black 80% | `#000000` |
| Ruled lines | Light grey | `#E5E5EA` |
| Primary action | Blue | `#007AFF` |
| Stars earned / unearned | Gold / Grey | `#FFD700` / `#D1D1D6` |

### 11.2 Typography

- Guide and journal text: **Jua** (bundled, as in TraceRight), falling back to SF Pro
  Rounded at the level's weight.
- UI chrome: SF Pro Rounded.
- The same font is used for typed and handwritten states so the toggle compares like
  with like.

### 11.3 Motion

Page-flip for the typed/handwritten toggle; guide fade on reveal; star bounce; badge
spring with a particle burst; confetti on level-up; flame flicker on the streak. Every
one of these is gated behind `accessibilityReduceMotion`.

---

## 12. Accessibility

- VoiceOver labels throughout. The Entry Detail handwritten state announces the
  transcript text plus "handwritten by {name} on {date}, {stars} stars".
- Dynamic Type for all UI chrome. Guide text is level-controlled and deliberately exempt.
- Colorblind ink scheme (blue/orange) and an optional dashed texture for outside strokes,
  so inside/outside never depends on hue alone.
- Haptic pulse when a stroke leaves the letter — a non-visual accuracy channel.
- Left-handed layout mirrors toolbars away from the writing hand.

---

## 13. File Structure

`Original Traceright App/` is untouched reference. The new app is a sibling:

```
HandwrittenJournal/
├── HandwrittenJournal.xcodeproj
├── HandwrittenJournal/
│   ├── App/
│   │   ├── HandwrittenJournalApp.swift      # entry point, ModelContainer
│   │   ├── RootView.swift                   # profile gate → app
│   │   ├── AppRoute.swift                   # navigation state
│   │   └── AppConstants.swift
│   ├── Models/
│   │   ├── UserProfile.swift
│   │   ├── JournalEntry.swift
│   │   ├── TraceAttempt.swift
│   │   ├── TracingSession.swift             # in-memory capture
│   │   ├── Level.swift
│   │   └── Badge.swift
│   ├── Services/
│   │   ├── MaskRenderer.swift               # ported
│   │   ├── StrokeColorizer.swift            # ported
│   │   ├── CustomStrokeRenderer.swift       # ported + InkMode
│   │   ├── GuideTextRenderer.swift          # factored out for reuse
│   │   ├── StrokeArchive.swift              # NEW — binary codec §6
│   │   ├── ThumbnailRenderer.swift          # NEW
│   │   ├── ScoringEngine.swift              # ported
│   │   ├── BadgeEngine.swift                # ported
│   │   ├── StatsEngine.swift                # NEW — trends, per-level rollups
│   │   ├── SpeechRecognitionService.swift   # ported
│   │   ├── PINService.swift                 # NEW — salt + SHA256
│   │   ├── ParentGate.swift                 # NEW
│   │   ├── ExportService.swift              # NEW — PNG / PDF
│   │   ├── HapticsService.swift             # ported
│   │   └── AudioService.swift               # ported
│   ├── ViewModels/
│   │   ├── ProfileStore.swift               # active profile, switching
│   │   ├── DictationViewModel.swift
│   │   ├── TracingViewModel.swift
│   │   └── JournalViewModel.swift
│   ├── Views/
│   │   ├── Profiles/  ProfilePickerView · ProfileEditorView · PINPadView · AvatarCaptureView
│   │   ├── Journal/   JournalHomeView · JournalListView · JournalCalendarView ·
│   │   │              EntryDetailView · TypedPageView · HandwrittenPageView · AttemptPagerView
│   │   ├── Write/     DictationView · TranscriptConfirmView · TracingView ·
│   │   │              TracingCanvasRepresentable · RevealView · ResultsView
│   │   ├── Progress/  ProgressView · AccuracyChartView · PerLevelTableView
│   │   ├── SettingsView.swift
│   │   └── Components/ StarRatingView · BadgeView · BadgeShowcaseView ·
│   │                   ProgressRingView · StreakView · LevelProgressView ·
│   │                   NotebookPaperView · EntryThumbnailView
│   ├── Utilities/ Extensions.swift
│   └── Resources/ Fonts (Jua) · Sounds · Assets.xcassets
└── HandwrittenJournalTests/
    ├── StrokeArchiveTests.swift       # round-trip, fuzz, corruption, version
    ├── ScoringEngineTests.swift
    ├── MaskRendererTests.swift
    ├── StrokeColorizerTests.swift
    ├── BadgeEngineTests.swift
    ├── StatsEngineTests.swift
    ├── PINServiceTests.swift
    └── PersistenceTests.swift         # in-memory ModelContainer, cascade deletes
```

---

## 14. Testing Strategy

The engine ports with its existing tests. New coverage focuses on the parts where a bug
silently destroys a keepsake:

- **`StrokeArchiveTests`** — encode/decode round-trip fidelity to within float
  tolerance; empty strokes; single-point strokes; 50,000-point stress; truncated and
  corrupted blobs must throw rather than crash; a v1 blob must still decode after any
  future format change.
- **`PersistenceTests`** — an in-memory `ModelContainer` verifying cascade deletes
  (deleting a profile removes its entries and attempts, and orphans no external files),
  draft promotion, and that a re-trace appends rather than replaces.
- **`StatsEngineTests`** — rolling averages, per-level rollups, streak arithmetic across
  month boundaries, DST, and timezone changes.
- **`PINServiceTests`** — salt uniqueness, verification, and that no PIN is recoverable
  from the stored model.

---

## 15. Development Phases

| Phase | Scope |
|---|---|
| **0 — Wireframes** | Every screen in §4 drawn and signed off before any code is written. Wireframes are the gate on development, not a parallel activity. |
| **1 — Foundation** | Xcode project, models, in-memory container, `StrokeArchive` + tests. Nothing visible yet, everything else depends on it. |
| **2 — Tracing engine port** | Mask renderer, guide renderer, input overlay, colorizer, custom stroke renderer with `InkMode`. Verified against a hard-coded sentence. |
| **3 — Profiles** | Picker, editor, avatar capture, PIN, parent gate, `ProfileStore`, per-profile scoping. |
| **4 — Write loop** | Dictation, transcript confirmation, tracing, reveal, save. First end-to-end path that produces a persisted entry. |
| **5 — Journal** | Home, list, calendar, entry detail with the typed ↔ handwritten toggle, attempt pager, thumbnails, drafts. |
| **6 — Scoring & progression** | Scoring engine, levels, badges, streaks, results screen, level-up celebration. |
| **7 — Progress** | `StatsEngine`, charts, per-level table, level-aware trend copy. |
| **8 — Polish** | Settings, sound, haptics, export/share, accessibility audit, Reduce Motion, left-handed layout, empty states. |
| **9 — iCloud** | Flip the container to `.private`, dedupe pass, multi-device testing. Separate release. |

---

## 16. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Speech recognition misreads a child's voice | High — tracing a wrong sentence is demoralising | Transcript confirmation step (§4.4) with easy re-record and keyboard fallback |
| Accuracy appears to *drop* after a level-up, reading as regression | High — undermines the whole motivation | Level-marked charts, per-level comparison table, trend copy scoped to the current level (§4.10) |
| Stroke archive corruption loses irreplaceable entries | High | Versioned format, defensive decode, thumbnail retained separately so the entry still *shows* even if replay fails |
| Ink replay looks wrong on a differently-sized canvas | Medium | Store capture geometry, aspect-fit replay, never stretch |
| Storage growth over years | Medium | Compact binary + LZFSE, ~20 KB/attempt; ~40 MB for five daily years |
| CloudKit constraints discovered late | Medium | Models authored to CloudKit rules from day one (§9) |
| Simulator has no Apple Pencil | Low | Finger input accepted in the simulator unconditionally, and on device behind a per-profile setting |

---

## 17. Deliberately Out of Scope for v1

- iCloud sync (models are ready; the switch is phase 9)
- Retaining the original voice audio
- Handwriting recognition of the child's own free writing (no guide)
- Cursive mode and stroke-order guidance
- Cosmetic rewards store
- Sharing between profiles, or any multi-device collaboration
- iPhone layout

---

*Document version: 1.1*
*Last updated: 2026-08-27*
*Status: approved for wireframing. Development begins after wireframe sign-off (Phase 0).*
