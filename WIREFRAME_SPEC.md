# Handwritten Journal — Wireframe Specification

## Penpot handoff, v2.6

Companion to `DESIGN_DOCUMENT.md`. That document decides *what the app does*; this one
decides *what it measures*, so full-fidelity wireframes can be built in Penpot without
inventing numbers. Every value here is a decision, not a suggestion — if a number is
wrong, change it here and the code will follow, because `AppConstants.swift` is generated
from §5–§9 of this file.

**What changed in v2.0** (see `PENPOT_HANDOFF.md` §2 for the full rationale):

- **Levels are gone.** Glyph size is a per-profile **setting**, not something earned.
- **Font is a per-profile setting** too, chosen from a curated list (§7.2).
- **Portrait only.** The landscape-first decision in v1 §3 is reversed.
- **Writing is a session that grows.** Speak → confirm → trace → the sentence joins the
  page above → speak again. Results summarise the session.
- **Accuracy colours are always on while writing** and never on in the journal.
- **Copy mode** (writing on a line beneath the words) is named but not built.
- **The parent gate is removed.**

**What changed in v2.1:**

- **An eraser tool.** The child rubs out a patch and re-traces it in place (§11.7).
- **Accuracy is graded per letter.** A letter with no ink scores 0%, which makes
  "trace half of it and tap Done" score about 50% instead of 95% (§11.4).
- **Latest tracing only.** Attempt history is gone; re-tracing replaces. Frame 17 retired.
- **The child's voice is kept**, recorded before transcription and playable from the
  journal (§10.6, `DESIGN_DOCUMENT.md` §5.3).
- **Whole-journal export** — the book, not just a page (frame 43).
- **Permission and limit states** are drawn (frames 40, 41, 42).

**What changed in v2.2 — long-form dictation:**

- **The child speaks for up to five minutes**, not one sentence. The transcript is split
  into sentences and traced one at a time (§11.9).
- **The 200-character cap is replaced by a size-aware fit rule.** A traceable piece must fit
  the writing surface, and at Extra Large that is only ~56 characters (§11.9).
- **A review screen** between speaking and writing: the sentence list, editable, splittable,
  joinable (frame 22).
- **A queue** — "Sentence 3 of 8" — runs through the writing screens.
- **Drafts are gone as an entity.** An unfinished session *is* the draft.

**What changed in v2.3 — one continuous page:**

- **The transcript is not split.** It is laid out as one scrolling page and the child works
  down it (§11.9). No splitter, no fit rule, no review list, no sentence queue.
- **Progress is words**, not pieces — a bar at the foot of the page.
- **Scrolling and the pen** are separated by touch count, with a button that scrolls
  without any gesture (§11.6).
- Retired with it: `Row / Sentence review`, `Queue chip`, `Writing so far` panel, and
  frames 22's review list and 23's split/join controls.

**What changed in v2.4 — the page is the whole screen:**

- **The writing-so-far panel is gone.** Finished lines are not copied into a separate
  panel; they stay exactly where they were written and simply stop being guide text. The
  page above the child's hand *is* the record (§11.11).
- **Three line states on one page** — graded (their ink, guide removed), in hand (guide
  plus live accuracy colours), and untraced (guide alone).
- **Tap a graded line to write it again** (§11.12). This is the only re-trace mechanism;
  there is no attempt history behind it, so the new tracing replaces the old.
- **New dictation appends to the current page** rather than starting a new one. The page
  scrolls to the first new word.
- **One entry, one result.** Results and Entry Detail report the whole entry — one
  accuracy, one word count, one recording. Per-sentence rows are retired.

**What changed in v2.5 — one screen, and nothing is real until it's written:**

- **Speaking, checking, fixing and writing are one screen.** The session-start, recording
  and check-what-I-said screens are gone as screens. The mic lives in the footer (and
  centre-page while the page is empty), dictation lands on the page live, and fixing a
  misheard word happens in place with the keyboard (§11.13). Frames 20, 21, 22 and 42 now
  name *states of the page*, not screens.
- **Text is spoken until it is written.** The third line state changes meaning: what used
  to be "untraced guide text" is now **spoken** text — pale, cool (`spoken-text`, §5.3),
  editable, and **not part of the record**. Only the line in hand carries true guide text.
- **Finishing a line is what commits its words.** The child finishes a line by tapping the
  check at its end or by tapping the next line to take it in hand (§11.11). That is the
  settle moment (§11.10) and the moment the line's text joins the record. Nothing settles
  automatically any more.
- **The record is the child's hand, by construction.** The journal, search, exports and
  every word count read only written text. An "unfinished entry" is an entry with spoken
  words still waiting — the record itself is always fully written.

**What changed in v2.6 — free row selection, and the pencil never scrolls:**

- **The end-of-line check is gone**, and with it the whole commit gesture. **Any row can
  be selected by tapping it, at any time** — traced rows included (§11.11). When the
  selected row's last letter gets ink, the next untraced row is selected automatically;
  the taps are for going back, skipping, or fixing, not for going forward.
- **Traced rows keep faint letterforms under the ink** (`guide-faint`, §5.3) instead of
  losing the guide entirely — three legible tiers: faint grey under graphite, black under
  accuracy colours, light grey waiting.
- **The record is derived, never declared.** It is the unbroken run of fully-traced rows
  from the top of the page, recomputed from the ink itself — it grows as rows fill and
  shrinks if a record row's ink is cleared (§11.11).
- **The pencil never scrolls** — pen touches are excluded from the scroll gesture
  outright, so a pen on the page is always ink (§11.6).
- The re-trace chip of §11.12 is retired: fixing a traced row is just tapping it.

---

## 1. How To Use This Document

1. Build the **Foundations** page first (§5–§9). Everything else is assembled from it.
2. Build the **component library** (§10) as Penpot components, so a change to a button
   propagates to every frame.
3. Lay out frames from the inventory in §12.
4. Where §13 gives coordinates, use them. Where it does not, follow the grid rules in §6
   and use judgement.
5. §15 is the technique note for drawing believable child handwriting in a vector tool —
   read it before attempting any frame that shows ink.

---

## 2. Penpot File Structure

One Penpot file: **`Wireframes`**.

| Page | Contents |
|---|---|
| `00 · Foundations` | Color tokens, type scale, spacing ruler, elevation samples, icon sheet |
| `01 · Components` | Every component in §10, one per board, with all variants |
| `02 · Profiles` | Frames 1–7 |
| `03 · Journal` | Frames 9–19 |
| `04 · Write` | Frames 20–30, 36 |
| `05 · Progress & Settings` | Frames 31–34, 38, 39 |
| `99 · Scratch` | Anything in progress; never referenced by development |

**Board naming:** `NN — Screen Name — state`, e.g. `04 — PIN Pad — wrong PIN`. The leading
number is the frame number from §12 and must not be reused. Development references frames
by number.

**Retired numbers — do not reuse:**

| # | Was | Why |
|---|---|---|
| 8 | Parent Gate — math challenge | Removed in v2.0 |
| 16 | Entry Detail — accuracy colours | The journal is always natural ink now (§11.5) |
| 35 | Level-up celebration | Levels removed |
| 17 | Sentence attempts | Only the latest tracing is kept (v2.1) |

---

## 3. Artboards and Orientation

**The app is portrait only.** v1 designed landscape first, on the argument that a wider
writing line is better for a child. The v2 writing screen stacks the page-so-far above the
active line, which is a vertical composition; and a child holding an iPad to write holds it
like a notebook. Portrait wins on both counts.

| | Size (pt) | Use |
|---|---|---|
| **Primary artboard** | **834 × 1194** | iPad Pro 11" portrait. Design every frame at this size. |
| Narrow check | 744 × 1133 | iPad mini portrait. Do not draw; verify the primary layout does not break. |
| Wide check | 1032 × 1376 | iPad Pro 13" portrait. Do not draw; verify. |

Design in **points, at 1×**. Penpot pixels map 1:1 to iOS points. Export at 2× and 3× only
for image assets, never for layout reference.

**Safe areas.** Reserve 24 pt at the bottom for the home indicator and 0 pt at the sides.
Nothing tappable may enter that band — i.e. nothing below **y 1170**.

---

## 4. Interaction Constants

| Constant | Value | Note |
|---|---|---|
| Minimum tap target | 44 × 44 | Apple HIG floor. Child-facing primary actions are much larger. |
| Child primary action | ≥ 280 × 64 | Deliberately oversized; a six-year-old is the user. |
| Standard transition | 0.30 s ease-in-out | |
| Page-flip (typed ↔ handwritten) | 0.35 s | `rotation3DEffect`, y-axis |
| Guide fade on reveal | 0.50 s | |
| Line settle (guide fades, ink turns natural, in place) | 0.45 s | See §11.10 |
| Spring (badges, stars) | response 0.4, damping 0.7 | |

---

## 5. Color Tokens

Create these as Penpot library colors with exactly these names. Development uses the same
names in `AppConstants.swift`.

### 5.1 Surfaces

| Token | Hex | Use |
|---|---|---|
| `paper` | `#FAF8F5` | App background, the writing surface |
| `paper-sunk` | `#F1EEE9` | Card wells, keypad keys, inset panels |
| `paper-raised` | `#FFFFFF` | Cards that float above `paper` |
| `overlay-scrim` | `#000000` @ 40% | Behind modals and sheets |

### 5.2 Ink

| Token | Hex | Use |
|---|---|---|
| `ink-natural` | `#2C2C2E` | **Default journal handwriting.** Graphite, not black. |
| `ink-inside` | `#34C759` | Stroke inside the letter (while writing) |
| `ink-outside` | `#FF3B30` | Stroke outside the letter (while writing) |
| `ink-inside-cb` | `#007AFF` | Colorblind scheme, inside |
| `ink-outside-cb` | `#FF9500` | Colorblind scheme, outside |

### 5.3 Guide layer

| Token | Hex | Use |
|---|---|---|
| `guide-text` | `#000000` @ 80% | The letters being traced — **only the line in hand** (§11.11) |
| `spoken-text` | `#5B6B8C` @ 42% | Dictated words waiting to be written. Deliberately cooler as well as lighter than `guide-text`, so "not yet real" reads at a glance and survives a squint |
| `guide-faint` | `#000000` @ 15% | The letterforms left under a traced row's ink — legible enough to read, faint enough that the ink is unmistakably the text now (v2.6) |
| `rule-line` | `#E5E5EA` | Baselines, ascender and descender rules |

### 5.4 Text

| Token | Hex | Use |
|---|---|---|
| `text-primary` | `#1C1C1E` | Headings, body |
| `text-secondary` | `#6C6C70` | Captions, metadata, subtitles |
| `text-on-action` | `#FFFFFF` | Label on a filled button |

### 5.5 Semantic

| Token | Hex | Use |
|---|---|---|
| `action` | `#007AFF` | Primary buttons, selected states, links |
| `action-pressed` | `#0060D0` | Pressed state of `action` |
| `action-disabled` | `#B4D5FA` | Disabled fill |
| `star-on` | `#FFD700` | Earned star |
| `star-off` | `#D1D1D6` | Unearned star, unearned badge |
| `streak-flame` | `#FF9500` | Flame glyph and streak count |
| `success` | `#34C759` | Positive deltas on Progress |
| `danger` | `#FF3B30` | Delete, reset, negative deltas |
| `divider` | `#E5E5EA` | Hairline separators |

**Dark mode is out of scope for v1.** The app is a paper journal and stays light.

---

## 6. Grid and Spacing

**Base unit: 8 pt.** Every spacing value is a multiple of 8, except the 4 pt micro-step.

| Step | Value | Typical use |
|---|---|---|
| `space-1` | 4 | Icon-to-label, tight pairs |
| `space-2` | 8 | Within a component |
| `space-3` | 12 | Between related lines of text |
| `space-4` | 16 | Between components in a group |
| `space-5` | 24 | **Screen outer margin**, between groups |
| `space-6` | 32 | Inside cards and sheets |
| `space-7` | 40 | **Writing surface inset (see §11)** |
| `space-8` | 56 | Between major sections |
| `space-9` | 72 | Above a screen's primary action |

**Screen margin:** 24 pt left/right. **Content width: 834 − 48 = 786 pt.**

**The writing surface is the exception at 40 pt** — that value comes from the ported engine
and must not change without a code change. **Surface width: 834 − 80 = 754 pt.**

**Columns:** 6-column grid, 786 pt wide, 24 pt gutters → 111 pt columns. Use it for the
Journal, Progress and Settings screens. The Profile Picker, Write and Results screens are
centered compositions and ignore the column grid.

---

## 7. Typography

### 7.1 UI chrome

**SF Pro Rounded** for all UI chrome. Free from Apple; Penpot needs it installed locally or
uploaded as a custom font. *(The built file substitutes **Nunito** — see `PENPOT_HANDOFF.md`
§2.1. Sizes and weights match, so swapping back is one pass.)*

| Style | Size | Weight | Line height | Use |
|---|---|---|---|---|
| `display` | 44 | Bold | 52 | Greeting, celebration copy |
| `title-1` | 34 | Bold | 41 | Screen titles |
| `title-2` | 28 | Semibold | 34 | Section headers |
| `headline` | 22 | Semibold | 28 | Card titles, profile names |
| `body` | 18 | Regular | 24 | Body copy, settings rows |
| `body-em` | 18 | Semibold | 24 | Emphasised body |
| `caption` | 15 | Regular | 20 | Metadata, dates |
| `caption-sm` | 13 | Regular | 18 | Chart axis labels |
| `button` | 24 | Bold | 28 | Primary button label |
| `button-sm` | 18 | Semibold | 22 | Secondary and toolbar buttons |
| `numeral-xl` | 60 | Bold | 68 | Accuracy percentage in the ring |
| `numeral-l` | 34 | Bold | 41 | Points, streak count |

### 7.2 The journal face — a per-profile setting

The face used for guide text and journal content is **chosen in Settings** from a curated
list. It is not a free font picker: every candidate must have **thick strokes, open
counters and an unambiguous single-story `a`**, or a beginner cannot stay inside the
letterform and the mask renderer has nothing useful to work with.

| Key | Family | Weight | Why it is on the list |
|---|---|---|---|
| `jua` | Jua | 400 | Rounded and heavy. **Default.** |
| `andika` | Andika | 700 | Drawn by SIL specifically for beginning readers. |
| `baloo` | Baloo 2 | 700 | Very open letters, thick strokes. |
| `sniglet` | Sniglet | 800 | The thickest — easiest to stay inside. |
| `comic` | Comic Neue | 700 | Looks like classroom printing. |

Adding a face to this list is a **product decision, not a preference**: it must be
vetted against the mask renderer first.

### 7.3 The journal size — a per-profile setting

Five named steps. Default **Large**. There is no automatic progression; a grown-up moves
the child down a size when tracing is comfortable (Progress suggests when — §13.5).

| Key | Label | Size | Line spacing | Lines in a 530 pt surface |
|---|---|---|---|---|
| `xl` | Extra Large | 96 | 120 | 4 |
| `l` | **Large** | **72** | **96** | **5** |
| `m` | Medium | 56 | 72 | 6 |
| `s` | Small | 42 | 56 | 8 |
| `xs` | Extra Small | 30 | 40 | 12 |

**Draw all journal frames at Jua / Large.** Draw one Extra Large and one Extra Small
variant of the writing frame so the extremes are validated (frames 26, 27).

**Line spacing is a floor, not a promise.** Every face carries its own line advance —
ascent, descent and built-in leading — and two of the five bundled faces need more room
than the table asks for. Andika at Large advances 116 pt, not 96. The page is measured with
the real face and uses whichever is larger, so an Andika page is simply taller; the ruled
lines follow the measured baselines rather than the table, so the letters always sit on
them. **Never size a page from the table alone** — a page measured short does not scroll,
it silently drops its last line, and the child cannot write what is not there.

### 7.4 Review scale

**Retired in v2.4.** There is no review panel: a finished line stays at writing size, in
place, and only changes colour and loses its guide. The one place handwriting is redrawn
smaller is the `Thumbnail` component (§10.6), which sizes its own em to ~10% of the
thumbnail width. Stroke widths scale with glyph size in every case (§11.5).

---

## 8. Elevation, Radii and Strokes

| Token | Value |
|---|---|
| `radius-chip` | 8 |
| `radius-button` | 14 |
| `radius-card` | 20 |
| `radius-sheet` | 28 |
| `radius-pill` | height ÷ 2 |
| `radius-avatar` | full circle |
| `shadow-card` | 0 y, 8 blur, `#000000` @ 6% |
| `shadow-raised` | 0 y, 24 blur, `#000000` @ 10% |
| `shadow-modal` | 0 y, 48 blur, `#000000` @ 18% |
| `stroke-hairline` | 1 pt, `divider` |
| `stroke-emphasis` | 2 pt |
| `stroke-selected` | 3 pt, `action` |

---

## 9. Iconography

SF Symbols, weight **Medium**. Penpot has no SF Symbols support — the built file draws
geometric equivalents onto an icon sheet on `00 · Foundations`, named after their symbol
counterparts. Replace them with real SF Symbol SVG exports before final sign-off.

Required set: `mic.fill`, `keyboard`, `arrow.uturn.backward`, `trash`, `checkmark`,
`chevron.left`, `chevron.right`, `gearshape.fill`, `chart.line.uptrend.xyaxis`,
`magnifyingglass`, `calendar`, `line.3.horizontal.decrease.circle`, `square.and.arrow.up`,
`ellipsis.circle`, `camera.fill`, `photo.on.rectangle`, `lock.fill`, `flame.fill`,
`star.fill`, `star`, `pencil.line`, `person.crop.circle.badge.plus`, `xmark`,
`arrow.triangle.2.circlepath`, `plus`, `eraser.fill`, `speaker.wave.2.fill`.

---

## 10. Component Library

Build each as a Penpot component with the listed variants.

### 10.1 Buttons

| Component | Size | Fill | Text | Radius |
|---|---|---|---|---|
| `Button / Primary` | h 64, min w 280 | `action` | `button`, `text-on-action` | 14 |
| `Button / Primary / Pressed` | same | `action-pressed` | same | 14 |
| `Button / Primary / Disabled` | same | `action-disabled` | same | 14 |
| `Button / Secondary` | h 56, min w 220 | none, 2 pt `action` stroke | `button-sm`, `action` | 14 |
| `Button / Text` | h 44 | none | `button-sm`, `action` | — |
| `Button / Destructive` | h 56, min w 220 | none, 2 pt `danger` stroke | `button-sm`, `danger` | 14 |
| `Button / Toolbar` | 44 × 44 | none | icon 24, `action` | — |

Primary button icon, when present, is 28 pt, leading, 12 pt from the label.

### 10.2 Avatars

| Component | Diameter | Ring | Shadow |
|---|---|---|---|
| `Avatar / XL` | 160 | 4 pt `paper-raised` | `shadow-card` |
| `Avatar / L` | 140 | 4 pt `paper-raised` | `shadow-card` |
| `Avatar / M` | 56 | 2 pt `paper-raised` | none |
| `Avatar / S` | 36 | none | none |
| `Avatar / No photo` | any | as above | initial letter at 42% of diameter, `text-secondary` |
| `Avatar / Empty` (add tile) | any | 2 pt dashed `star-off` | none — `person.crop.circle.badge.plus` at 40% |

A profile without a photo shows **its initial**, not the add-tile treatment; the two must
not look alike.

**Lock badge:** 32 pt circle, `paper-raised` fill, `shadow-card`, `lock.fill` at 16 pt in
`text-secondary`. Anchored at 45° bottom-right, overlapping the ring by 4 pt. `XL` and `L` only.

### 10.3 PIN entry

| Element | Spec |
|---|---|
| Dot, empty | 20 circle, 2 pt `star-off` stroke, no fill |
| Dot, filled | 20 circle, `action` fill |
| Dot spacing | 24 pt between centres → 4 dots span 92 pt |
| Keypad key | 88 circle, `paper-sunk` fill, numeral `title-1` in `text-primary` |
| Keypad grid | 3 × 4, 24 pt gutters → 312 × 424 |
| Delete key | bottom-right, `xmark` at 28 pt, no fill |
| Wrong-PIN state | dots shift to 2 pt `danger` stroke, horizontal shake ±12 pt, 0.4 s |

### 10.4 Stars

| Component | Glyph size | Gap |
|---|---|---|
| `Stars / Results` | 44 | 16 |
| `Stars / Row` | 28 | 8 |
| `Stars / Compact` | 20 | 6 |

Earned `star.fill` in `star-on`; unearned `star.fill` in `star-off` — never the outline
variant, so the silhouette stays constant.

Stars rate **one tracing**. They no longer accumulate toward anything.

### 10.5 Progress indicators

| Component | Spec |
|---|---|
| `Ring / Results` | 220 outer diameter, 18 pt stroke, `paper-sunk` track, `action` progress, round cap, starts at 12 o'clock clockwise. `numeral-xl` centred with `caption` label 8 pt below. Shows the **session** accuracy. |
| `Ring / Compact` | 120 outer, 12 pt stroke, same construction |
| `Button / Toolbar / Active` | 44 × 44, `action` fill, `radius` 12, icon in `text-on-action`. Used for the eraser while it is selected. |
| `Segmented` | h 44, `radius-pill`, `paper-sunk` track, selected segment `paper-raised` inset 3 pt with `shadow-card`. Used for Typed/Handwritten, Trace/Copy, and the 30d/90d/All range. |

`Bar / Level` and `Pager / Attempt` are both **retired** — there is no ladder and no
attempt history.

### 10.6 Journal and writing surfaces

| Component | Spec |
|---|---|
| `Row / Session` (**the main screen's journal list**) | h 132, full content width, `paper-raised`, `radius-card`, `shadow-card`, 16 pt padding. Thumbnail 160 × 100 `radius-chip` leading; then date + time `body-em`, the opening words of the entry in `body` truncated to one line, metadata `caption` in `text-secondary` reading *"N words · NN% · Font Size"* — the entry's per-letter accuracy over the words the child actually started; `Stars / Row` trailing, vertically centred. |
| `Card / Entry stats` (entry detail) | Full content width × 96, `paper-sunk`, `radius-card`. Accuracy `numeral-l` with "accuracy" `caption` beneath at 28 pt in; `Stars / Compact`; word count `body-em` with a one-line note `caption` beneath; `speaker.wave.2.fill` 24 pt + "Hear what I said" `body-em` in `action` trailing. **One row per entry** — `Row / Sentence` is retired, and with it the per-sentence playback. |
| `Writing progress` | Full width of the footer. `paper-sunk` capsule track 8 pt tall, `action` fill to `wordsWritten / totalWords`, caption "15 of 48 words" beneath in `text-secondary`. Replaces the sentence queue. In the footer it is 190 pt wide, not full width — the accuracy hint sits to its left. |
| `Level meter` | 420 × 40 (280 wide in the listening bar). 5 pt bars, 5 pt gaps, `action`, with the tail in `star-off`. Purely decorative in the wireframe; a real implementation reads the input level. |
| `Mic / Footer` | 64 pt circle, `action` fill, `mic.fill` 28 pt in `text-on-action`. Muted state (listening finished at the cap): `paper-sunk` fill, `text-secondary` glyph. Drawn large — 176 pt — in the centre of an empty page (frame 20). |
| `Listening bar` | Replaces the footer while recording: `Level meter` 280 wide leading, elapsed `numeral-l` over "of 5:00" `caption`, `Button / Primary` "I'm done talking" 260 × 64 trailing. |
| ~~`End-of-line check`~~ | **Retired in v2.6** — finishing is automatic (the row fills) and selection is free (any row, any tap). Do not reuse. |
| `Word being fixed` | A spoken word under edit: rounded rect at `radius-chip`, `action` stroke 2 pt over a 10% `action` tint, caret trailing, keyboard up (frame 22). |
| `Thumbnail` | Aspect 5:3, `paper` fill, 1 pt `divider` stroke, handwriting in `ink-natural` at ~10% of the thumbnail width per em. **Never accuracy colours.** |
| `Toggle / TypedHandwritten` | 420 × 56, `radius-pill`, `paper-sunk` track. Two 210 pt segments. Selected: `paper-raised` inset 4 pt, `shadow-card`, `button-sm` in `text-primary`. Unselected `button-sm` in `text-secondary`. |
| `Cell / Calendar` | 88 × 88. Day numeral `body` centred. Entry dot 8 pt in `action`, 8 pt below the numeral. Today: 2 pt `action` ring. |
| `Font option` | Full content width × 176, `radius-card`. Selected: `paper-raised`, `shadow-card`, 3 pt `action` stroke, `checkmark` 24 pt trailing. Unselected: `paper-sunk`. Name `headline`, reason `caption`, then a live preview of the sample line at 46 / 60 on one ruled line. |
| `Size option` | Full content width, height = size × 1.5 + 56. Same selected treatment. Label `body-em`, "NN pt" `caption` trailing, then a live preview at the real size. |

### 10.7 Badges

`Badge / Tile`: 88 circle + label below. Earned — `paper-raised` fill, `shadow-card`, icon
40 pt in `star-on`, label `caption` in `text-primary`. Unearned — `paper-sunk` fill, no
shadow, icon 40 pt in `star-off`, label `caption` in `text-secondary`. Label wraps to two
lines maximum, centred, 88 pt wide. The home strip uses 64 pt tiles with **no labels**.

Badges no longer reference levels. `DESIGN_DOCUMENT.md` §8 owns the list.

### 10.8 Chrome

| Component | Spec |
|---|---|
| `Toolbar` | h 72, `paper` fill, 1 pt `divider` bottom edge. Leading back button, centred `title-1` title, trailing actions 16 pt apart. |
| `Sheet / Modal` | width to content, `radius-sheet`, `paper-raised`, `shadow-modal`, centred, on `overlay-scrim` |
| `Sheet / PIN pad` | 700 × 800 |
| `Menu / Overflow` | 324 wide, rows h 60, `radius` 16, `paper-raised`, `shadow-modal`, hairline between rows inset 20 pt |
| `Row / Setting` | h 64, full width, label `body` leading, control trailing, 1 pt `divider` bottom inset 16 pt leading |
| `Keyboard` | h 316, `paper-sunk`, 1 pt `divider` top edge. Four rows, key h 62, gap 10, row gap 12, keys `paper-raised` with `radius` 8 and `shadow-card`; modifier keys `star-off`. |
| `Empty state` | Icon 72 pt in `star-off`, `title-2` heading 24 pt below, `body` explanation in `text-secondary` 12 pt below, optional `Button / Primary` 32 pt below. Vertically centred in its area. |

`Sheet / Parent gate` is **retired**.

---

## 11. The Writing Surface

The single most important spec in this document. It must match the ported engine exactly,
because the guide text and the mask bitmap are generated from these numbers.

### 11.1 Geometry (portrait, 834 × 1194)

The page is the screen. There is no second surface and no panel — one scrolling page runs
edge to edge between the toolbar and the footer.

```
  0       24  40                                   794 810  834
  ├────────┼───┼─────────────────────────────────────┼───┼───┤
  │  I'm finished   Wednesday, March 4    ◆  ↺  🗑          │  y 0
  ├──────────────────────────────────────────────────────────┤  y 72
  │ ┌──────────────────────────────────────────────────────┐ │
  │ │                                                      │ │
  │ │            THE PAGE   834 × 958   (scrolls)          │ │
  │ │                                                      │ │
  │ │   graded lines · the line in hand · untraced guide   │ │
  │ │                 text inset 40 either side            │ │
  │ │                                                      │ │
  │ └──────────────────────────────────────────────────────┘ │  y 1030
  │  So far: 88%      [███░░░░]  15 of 48 words   ⌄  [Done]  │
  ├──────────────────────────────────────────────────────────┤  y 1170
  │                  Home indicator  24                      │
  └──────────────────────────────────────────────────────────┘  y 1194
```

| Value | Number |
|---|---|
| Left / right text inset | **40 pt** (engine constant — do not change) |
| Text width | 754 pt |
| Page top edge | y = 72 |
| Page height (viewport) | 958 pt |
| Page top padding, first baseline offset | `space-7` = 40 pt |
| Page fill | `paper` |
| Footer | y = 1030, 1 pt `divider` hairline along its top edge |

**Page height is content height, not viewport height.** The page view is as tall as the
transcript needs at the current face and size, and the scroll view shows a 958 pt window
onto it. At Extra Small a 48-word entry is shorter than the window; at Extra Large it is
roughly three windows tall. Ruled lines fill the whole window even where there is no text
yet, because more dictation can always be appended (§11.11).

**Footer contents**, left to right: live accuracy `body` with a one-line hint in `caption`
beneath it (250 pt wide, never wider or it collides with the bar); `Writing progress`
(§10.6) centred at x = 310, 190 pt wide; the scroll chevron `Button / Toolbar` at x = 530;
`Button / Primary` "Done ✓" 220 × 64 trailing.

### 11.2 Ruled lines

Per line, three horizontal rules span the full surface width in `rule-line` at 1 pt:

1. **Ascender line** — dashed, 6 on / 4 off, at `baseline − 0.72 em`
2. **Baseline** — solid, at the text baseline
3. **Descender line** — dashed, 6 on / 4 off, at `baseline + 0.21 em`

Only the baseline is solid. This is deliberate: the child aims for the solid line.

**Ruled lines fill the whole surface**, not just the lines that carry text — it is a page,
not a caption. Toggled off entirely when the profile's "guide lines" setting is off.

### 11.3 Capacity

**There is no capacity limit.** The 200-character cap and the v2.2 size-aware fit rule are
both retired: a page that scrolls has nothing to overflow. The only bound is the
five-minute dictation cap (§11.9), and that bounds talking, not writing.

Capacity still matters for *layout* — at Extra Large roughly 56 characters fit a line, at
Extra Small roughly 150 — so the page must always be measured with the real face at the
real size before it is drawn. A character count will not do: the five bundled faces differ
by up to 40% in advance width.

### 11.4 Accuracy is graded per letter

The mask is built **per glyph**, not per line. Each letter gets its own accuracy — the
proportion of the child's points inside *that* letter — and the entry score is the mean
across every letter that counts.

**A letter with no ink scores 0%.** This is the whole point: it makes an unfinished entry
score like an unfinished entry. Under the old line-wide measure, a child who carefully
traced four letters and tapped Done scored ~95%; now they score ~20%.

**Scoring is word-aware, because the page is now longer than the sitting.** A child who
writes 32 of 48 words has not failed the last 16 — they have not reached them. So words
the child never started are **not scored at all**, while letters skipped inside a word they
did start score zero. The result reads *"32 of 48 words · 78%"*: the count carries how far
they got, the percentage carries how well they did on the way.

Coverage as a separate metric is **retired** — per-letter grading subsumes it.

**Live and final are different numbers, deliberately.**

| | What it counts |
|---|---|
| **Live**, on the writing screen | Only letters the child has started. Reads *"So far: 78%"*, with a hint below: *"16 letters still to go"*. |
| **Final**, at Done | Every letter of every **started** word, unstarted ones at 0%. Words never reached are excluded. |

If the live readout applied the zero penalty it would start at 0% and crawl upward for the
whole entry, which feels like failing continuously. The hint carries the warning
instead, and the Reveal screen says plainly whether anything was left unfinished.

### 11.5 Ink

**While writing, ink is always drawn in `ink-inside` / `ink-outside` per segment.** There is
no toggle. **In the journal, ink is always `ink-natural`.** There is no toggle there either.
The two readings are different products of the same stored strokes (`DESIGN_DOCUMENT.md` §6).

Stroke width varies with pencil pressure between **1.5 pt and 5.0 pt at Large**, round cap,
round join, and **scales linearly with glyph size** (`size / 72`). Applied literally at
review or thumbnail scale the quoted range produces illegible blobs.

### 11.6 Scrolling

**The pencil never scrolls.** Pen touches are excluded from the scroll gesture outright —
a pen on the page is always ink, and a pen stroke can never be misread as a pan (v2.6).
Everything else:

- Journal, list, settings and progress screens scroll normally.
- **Fingers scroll the writing page**: one finger when finger tracing is off; two fingers
  when it is on (one finger is ink then — the Notes / Procreate split). Because two
  fingers is a lot to ask of a five-year-old holding a pencil, **a chevron button at the
  foot of the page scrolls with no gesture at all** — that is the primary mechanism.
- Finger *taps* still reach the page in every mode — taps select rows (§11.11); only drags
  scroll.
- **The Entry Detail page scrolls too.** A long entry is never truncated.

### 11.9 Long-form dictation, on the page

The child talks for as long as they like, up to **five minutes**, and the words land on the
page *as they say them* — in the journal face, on the ruled lines, in `spoken-text`. The
page is the live transcript; there is no separate recording screen and no review screen.
While listening, the footer becomes the **listening bar** (§13.3): level meter, elapsed of
5:00, and *I'm done talking*.

There is no splitter and no fit rule. Page height is measured with the real face at the
real size (§7.3's floor rule) — the five bundled faces differ by up to 40% in advance
width, so a character count will not do.

**Five minutes is far more than a child will write in one sitting, and that is fine.**
Stopping part-way must be completely unremarkable: *I'm finished* is always in the toolbar,
the word-progress bar shows what is written, and an entry with spoken words still waiting
is the first thing on Journal Home and the top section of the journal list. No warning
language anywhere. At the cap, recording stops itself and a warm **banner** slides over the
top of the page (frame 42) — not a screen.

### 11.7 The eraser

A third tool beside Undo and Clear. Selected, the toolbar button fills `action` with a
12 pt radius and the pointer becomes a **72 pt dashed circle** in `text-secondary` over a
`paper-sunk` fill at 70% — the child can see exactly what is about to disappear.

Erasing removes every sampled point inside the circle and **re-scores the letters it
touched**. It is not undo: undo removes a whole stroke in order, the eraser removes a
region regardless of when it was drawn. Both exist because a child who wanders outside one
letter should not have to redraw the four before it.

Clear still wipes the whole page's ink. Nothing is scored until Done.

### 11.10 The settle animation

**A row settles where it was written — when selection leaves it.** Whether the child
finished its last letter (auto-advance) or tapped away, the departing row cross-fades over
0.45 s (§4): letterforms from black down to `guide-faint`, ink from accuracy colours to
`ink-natural`. Selecting a traced row runs the same transition in reverse — its ink comes
back up in accuracy colours for fixing. Nothing moves, shrinks, or travels: the row the
child was writing simply becomes a row they have written, and the page above their hand
fills up in their own handwriting.

This replaces the v2 rise-into-the-panel animation, and it is a better version of the same
emotional beat — the child sees the finished page grow in place rather than watching a copy
of their work fly somewhere else. Reduce Motion replaces the cross-fade with a hard swap.

### 11.11 The page in three row states, and when text becomes real

At any moment every row of the page is in exactly one of three states.

| State | Letters | Ink | Part of the record |
|---|---|---|---|
| **Traced** — has ink, not selected | `guide-faint` | `ink-natural` | See below |
| **Selected** — the row being written | `guide-text`, black | `ink-inside` / `ink-outside` | — |
| **Untraced** — waiting, not selected | `spoken-text`, editable | None | **No** |

The faint letterforms left under a traced row's ink keep the row legible as *text* while
the ink reads unmistakably as the child's own; the pale untraced tier below keeps the
boundary between "mine" and "not yet mine" visible at a glance.

**Any row can be selected by tapping it, at any time.** A traced row, the row after next,
the last row of the page — one tap. Selecting a traced row brings its ink back up in
accuracy colours for fixing; leaving any row settles it (§11.10). A pen that starts moving
on an unselected row selects it and begins the stroke in the same gesture — writing
somewhere *is* selecting it. Selecting a row also stops the mic if it is listening.

**Nothing needs a tap to move forward.** When the selected row's last letter gets ink, the
next untraced row is selected automatically. The taps are for going back, skipping ahead,
or fixing — the ordinary flow is speak, then write straight down the page.

**The record is derived, never declared.** What the journal, search, exports and every
word count read is the **unbroken run of fully-traced rows from the top of the page** —
recomputed from the ink itself. It grows as rows fill, runs through gaps only once they
are filled, and shrinks if a record row's ink is erased or cleared. A row traced out of
order is the child's work and is scored (§11.4), but the record — the story so far, in
order — waits for the rows before it.

**Untraced text is editable; traced text is not.** Holding a finger on an untraced word
opens it for fixing in place (§11.13) — provided no traced row sits below it, because an
edit must never reflow a row out from under its ink. Ink is attributed only to the
selected row, so a stray wobble can never put ink on a word the child has not reached.

**New dictation appends to this page** as untraced text after the last existing word — the
word total goes up and the page scrolls to the new words. An entry is a day's page,
however many times the child spoke to fill it.

### 11.12 Fixing a row you already wrote

**Tap it.** The row comes back selected — black letterforms, its ink in accuracy colours —
and the pen, the eraser, undo and clear all work on it exactly as they did the first time.
Tap another row (or finish the entry) and it settles again. There is no band, no chip and
no confirmation: re-selection *is* the feature, and the v2.5 "Write this line again" chip
is retired.

**Undo, clear and the eraser are scoped to the selected row.** The rest of the page's ink
— the record's ink included — is unreachable by every tool. Only the latest tracing is
kept (v2.1): redoing letters overwrites, and the entry's accuracy is recomputed from what
is on the page now. A child who goes back over a row they rushed sees their percentage go
up, which is the entire reason the feature exists.

### 11.13 One screen

Speaking, seeing, fixing and writing all happen on the page. There is no other surface.

- **The mic** is a 64 pt round `action` button in the footer, always available — tapping it
  mid-entry is how "saying more" works. While the page is empty it is *also* drawn large in
  the centre with the invitation (frame 20); same control, bigger target when there is
  nothing else to aim at.
- **Listening** replaces the footer with the listening bar and streams the words onto the
  page in `spoken-text` as they are recognised, caret at the end (frame 21). The reassurance
  line — *"Nothing goes in your journal until you write it."* — sits centred above the bar.
- **Fixing a word**: holding a finger on an untraced word draws a 2 pt `action` box over
  it with a 10% tint, raises the keyboard over the footer, and edits it in place (frame
  22). A tap selects the row (§11.11); the hold opens the word. The line reflows within
  the untraced region; traced rows cannot move because edits cannot reach them. There is
  no bulk review step — the child fixes what they notice, when they notice it.
- **Typing instead** is the same path with no mic: *Type it instead* puts the caret at the
  end of the spoken text and the keyboard types onto the page.
- **The five-minute cap** is a banner over the top of the page (frame 42), not a screen.

What died to make this: the session-start screen, the recording screen with its separate
transcript panel, and the check-what-I-said screen. Each existed to show the child text
somewhere other than where they would write it.

---

## 12. Frame Inventory

35 frames, all portrait 834 × 1194.

### `02 · Profiles`

| # | Frame | Notes |
|---|---|---|
| 1 | Profile Picker — populated | 3 profiles + add tile; two lock badges; Ada has no photo; each shows its font · size |
| 2 | Profile Picker — first launch, empty | Add tile with empty-state copy |
| 3 | PIN Pad — entering | 2 of 4 dots filled |
| 4 | PIN Pad — wrong PIN | Danger dots mid-shake |
| 5 | Profile Editor — new, empty | Empty avatar, empty name, "No PIN", Font/Size/Mode rows |
| 6 | Profile Editor — existing, with photo | Populated, PIN set, Delete visible |
| 7 | Avatar Capture — live camera | Circular mask, countdown "3" |

### `03 · Journal`

| # | Frame | Notes |
|---|---|---|
| 9 | Journal Home — populated | **The main screen**: New Entry, then badges, then every entry newest first as `Row / Session`. No resume card, no "Your writing" card. |
| 10 | Journal Home — empty | New profile, no sessions, no streak, badges grey |
| 12 | Journal Home — search active | Query "grandma", 2 results, keyboard up. Search lives in this screen's toolbar. |
| 13 | Journal Calendar | March grid, dots on written days |
| 14 | Entry Detail — Typed | A session page; toggle on "Typed" |
| 15 | Entry Detail — Handwritten | Same page in `ink-natural`; one `Card / Entry stats` beneath |
| 18 | Entry Detail — overflow menu open | Edit / Hear what I said / Share as PDF / Rename / Delete |
| 19 | Export preview — one entry | Scope selector, one PDF page, the entry as one continuous flow |
| 43 | Export preview — the whole journal | The book: 38 pages, fanned stack, size and options |

### `04 · Write`

Every frame here is a **state of the same screen** (§11.13).

| # | Frame | Notes |
|---|---|---|
| 20 | Write — the page, nothing said yet | Empty rules, centre mic invitation, "Type it instead"; Done disabled |
| 21 | Write — the page, listening | Words land as `spoken-text` live, caret at the end; listening bar footer |
| 22 | Write — fixing a word I misheard | One spoken word boxed in `action`, keyboard over the footer |
| 24 | Write — everything said, nothing written yet | Whole telling as untraced text; "Tap a line to write it" |
| 25 | Write — the page, part written | 3 traced (faint + graphite), 1 selected at 55%, untraced below; 15 of 48 |
| 26 | Write — the page at Extra Large | 96 pt; fewer words per line, a much taller page |
| 27 | Write — the page at Extra Small | 30 pt; the whole 48-word entry fits one window |
| 29 | Results — the whole entry written, 3 stars | 91%, everything said was written, +224 points |
| 30 | Results — stopped part way, 2 stars + new badge | 78%, 32 words written, 16 still spoken, +183 points |
| 40 | Write — microphone access | Child-legible explainer shown *before* the iOS prompt |
| 41 | Write — microphone unavailable | Denied or unsupported; typing onto the page becomes the primary path |
| 42 | Write — recording stopped at five minutes | A banner over the page, said warmly; 112 words ≈ 20 minutes of writing |
| 44 | Write — tapping a traced row to fix it | Row 2 re-selected: black letterforms, its ink back in accuracy colours |
| 45 | Write — more said, added to the page | Scrolled; 10 written lines above, new spoken text below, 48 of 58 words |
| 46 | Write — no guide lines | §16 variant: ruled lines off |
| 47 | Write — colourblind ink | §16 variant: `ink-inside-cb` / `ink-outside-cb` |
| 48 | Write — left-handed layout | §16 variant: toolbar and footer actions mirrored |

Frames 23, 28 and 36 are **retired**: 23 was the splitter, 28 the ink-only reveal (the page
now reveals a line at a time, in place, §11.10) and 36 the append screen, which frames 25
and 45 cover between them. Frames 20, 21, 22 and 42 keep their numbers but are **no longer
screens** — they are states of the page (v2.5).

**§16 variants** are frames 46–48, built as states of frame 25.

### `05 · Progress & Settings`

| # | Frame | Notes |
|---|---|---|
| 31 | Progress — by mode and font | Chart with two setting-change markers, per-setting table |
| 32 | Progress — insufficient data | Fewer than 5 tracings at one setting; empty state |
| 33 | Settings — profile | Profile, Writing (font/size/mode + toggles), Feedback, Danger zone |
| 34 | Settings — app | iCloud row disabled, About, two plain-language notes |
| 38 | Settings — font picker | Five curated faces, live previews, selected state |
| 39 | Settings — font size picker | Five sizes, live previews, the "ready to move down" nudge |

---

## 13. Key Screen Layouts

Coordinates are portrait, 834 × 1194, measured from the top-left. Screens not listed here
follow the grid rules in §6.

### 13.1 Frame 1 — Profile Picker

| Element | x | y | Size |
|---|---|---|---|
| Title "Handwritten Journal", `title-1`, centred | — | 120 | — |
| Subtitle "Who's writing today?", `headline`, `text-secondary`, centred | — | 172 | — |
| Settings gear, `Button / Toolbar` | 766 | 32 | 44 × 44 |
| Avatar grid, 2 × 2, `Avatar / XL`, 96 pt gaps | 191 | 320 | 416 × 500 |
| Names, `headline`, centred, 180 pt below each avatar | — | — | — |
| Font · size, `caption`, `text-secondary`, 212 pt below each avatar | — | — | — |

Row pitch is 340 pt. The selected profile carries a 3 pt `action` ring inset −10 pt.

### 13.2 Frame 9 — Journal Home

| Element | x | y | Size |
|---|---|---|---|
| `Avatar / M` (tap to switch user) | 24 | 32 | 56 |
| Switch-user badge, `arrow.triangle.2.circlepath` 14 pt | 64 | 72 | 22 |
| Name, `display` | 96 | 30 | — |
| Streak, flame 20 pt + `body` in `streak-flame` | 96 | 82 | — |
| Progress button, `Button / Toolbar` | 706 | 36 | 44 |
| Settings button, `Button / Toolbar` | 766 | 36 | 44 |
| "Your writing" card, `paper-sunk`, `radius-card` | 24 | 150 | 786 × 96 |
| — "YOUR WRITING" `caption`; "Jua · Large · Trace" `headline`; "Change ›" trailing | | | |
| `Button / Primary` "✎ New Entry" | 257 | 290 | 320 × 72 |
| "Recent" `title-2` · "See all ›" trailing | 24 | 404 | — |
| Session cards, 3 then 2, `Card / Session`, 24 pt gaps | centred | 456 / 716 | 200 × 240 |
| "Badges" `title-2` | 24 | 980 | — |
| Badge strip: 64 pt circles, 20 pt gaps, no labels | centred | 1030 | 652 × 64 |

### 13.3 Frame 25 — Write, the page part written *(the defining screen of v2.5)*

| Element | x | y | Size |
|---|---|---|---|
| `Toolbar` — "I'm finished" leading, date centred, eraser + undo + clear trailing at 60 pt pitch | 0 | 0 | 834 × 72 |
| The page, `paper`, full bleed, scrolls | 0 | 72 | 834 × 958 |
| — traced rows, `ink-natural` over `guide-faint` letterforms | 40 | 112 | 754 wide |
| — the selected row, `guide-text` (black) with accuracy ink over it | 40 | — | 754 wide |
| — untraced rows, `spoken-text` only | 40 | — | 754 wide |
| Footer hairline, 1 pt `divider` | 0 | 1030 | 834 × 1 |
| `Mic / Footer` (§10.6) | 24 | 1060 | 64 × 64 |
| "So far: 88%" `body`, hint `caption` beneath, 218 pt wide | 108 | 1062 | 218 |
| `Writing progress` (§10.6) with "15 of 48 words" | 340 | 1074 | 166 |
| `Button / Toolbar` `chevron.down` — scrolls a line with no gesture | 530 | 1060 | 44 × 44 |
| `Button / Primary` "Done ✓" | 590 | 1060 | 220 × 64 |

Frames 24, 26, 27 and 44–48 are the same layout with a different page state, size or
variant; only the page contents and the footer numbers change.

**Frame 20** (nothing said yet) hides the progress numbers, disables Done, and adds the
centre invitation: `Mic / Footer` at 176 pt centred at y ≈ 512, "Tell me about your day,
Milo" `title-1`, a two-line `body` caption, and "Type it instead" as a text button.

**Frame 21** (listening) swaps the footer for the `Listening bar` (§10.6) and centres
*"Nothing goes in your journal until you write it."* in `caption` just above it.

**Frame 22** (fixing a word) draws the `Word being fixed` treatment and the keyboard over
the bottom 320 pt; the footer is behind it.

**Frame 42** (the cap) lays a 660 × 116 `paper-raised` banner over the page at y = 100 —
muted mic well, "That's a whole lot of story!" `headline`, one `body` line beneath — and
mutes the footer mic.

**Frame 44** shows a traced row re-selected: row 2 back in black letterforms with its ink
in accuracy colours, the traced rows around it faint-grey under graphite. No band, no chip
— selection is its own affordance.

### 13.4 Frames 14 / 15 — Entry Detail

| Element | x | y | Size |
|---|---|---|---|
| `Toolbar` — back leading, "Wednesday, March 4" centred `title-1`, `ellipsis.circle` trailing | 0 | 0 | 834 × 72 |
| `Toggle / TypedHandwritten`, centred | 207 | 96 | 420 × 56 |
| Page surface, `paper`, 1 pt `divider`, `radius-card`, scrolls | 24 | 176 | 786 × 620 |
| — the entry flows continuously, 32 pt inner padding, ruled; scrollbar when it overflows | | | |
| "How it went" `body-em` + rule | 24 | 820 | — |
| `Card / Entry stats` (§10.6) | 24 | 858 | 786 × 96 |
| "Jua · Large · Trace" `caption` trailing | 24 | 976 | — |
| `Button / Primary` "Edit" | 137 | 1070 | 268 × 64 |
| `Button / Secondary` "Share" | 429 | 1074 | 268 × 56 |

Frames 14 and 15 must be **pixel-identical apart from the page surface contents and the
selected toggle segment**.

### 13.5 Frame 39 — Font size picker

The nudge at the foot of this screen is the only thing that replaces level progression:

> *"Milo has been above 90% for two weeks — Small might be ready to try."*

Shown in `caption` / `action` when the current setting's rolling average has been ≥ 90% for
14 days and a smaller size exists. It is a suggestion to a grown-up, never an automatic
change and never a reward.

---

## 14. Sample Content

Use these fixtures verbatim across every frame.

**Profiles**

| Name | PIN | Font | Size | Streak | Notes |
|---|---|---|---|---|---|
| Milo | yes | Jua | Large | 5 days | The primary subject of every populated frame |
| Ada | no | Andika | Extra Large | 0 | Younger sibling; **no photo** — shows her initial |
| Dad | yes | Comic Neue | Extra Small | 0 | Parent profile |

**Entries** (Milo) — one entry is one day's page, however many times the child spoke to fill it

| Date | Time | Words | Accuracy | Stars |
|---|---|---|---|---|
| Mar 4 | 4:12 PM | 48 of 48 — *"Today we went to the park…"* | 91% | ★★★ |
| Mar 3 | 5:40 PM | 29 of 29 — *"We made pancakes with Grandma…"* | 81% | ★★☆ |
| Mar 1 | 10:05 AM | 39 of 39 — *"My tower fell down but I built it again…"* | 90% | ★★★ |
| Feb 27 | 6:20 PM | 23 of 23 — *"The dog has a cold nose…"* | 66% | ★☆☆ |
| Feb 25 | 4:48 PM | 25 of 25 — *"I want to be an astronaut…"* | 88% | ★★☆ |

**The canonical transcript** — used on every Write and Results frame, and on Entry Detail
and the one-entry export. 48 words; **10 lines at Jua Large**, 7 at Medium, 5 at Extra
Small, 21 at Extra Large:

> Today we went to the park and I saw a big dog. The dog wanted to play with me and we
> threw a ball for it until it got tired. Then we had ice cream on the way home and Dad let
> me have chocolate sauce on mine.

Frame 21 has the first **22 words** of it on the page mid-dictation, caret after "threw a".
Frame 22 has the whole telling spoken with **"park" (line 2, word 1) being fixed**.
Frame 25 has **3 lines written, the 4th in hand at 55%** with the check outlined, the rest
spoken; 15 of 48 words, live 88%.
Frame 44 has 4 lines written with **line 1 selected**, 20 of 48 words, live 91%.
Frame 45 appends a second dictation: 10 lines written, new spoken text below, **48 of 58
words** — the frame that shows an entry growing.

**A long-form dictation at the cap** (frames 21, 42) — five minutes, 112 words:

> Today we went to the park and I saw a big dog. It was brown and white and it had a little
> silver bell that jingled when it ran across the grass. The dog wanted to play with me. We
> threw a ball for it. Then we had ice cream on the way home. Dad let me have chocolate. I
> want to go back tomorrow. We saw a squirrel too and it ran up a tree really fast and then
> it looked at us from a branch and Mum said it was probably looking for nuts to bury for
> the winter.

There is no splitter and no fit rule, so this fixture no longer exercises anything except
the page's height: at Large it is 23 lines, about two and a half windows.

**An unfinished entry** (frames 9 variant, 11) — Mar 4, 5:30 PM, 32 of 48 words, next up
*"until it got tired."*

**Frame 12 only:** an older result for the query "grandma" — Jan 18, 3:15 PM, "Grandma read
me a story", 22 words, 85%, Jua Extra Large.

**Canonical Results numbers.** Frame 29 (finished): 48 of 48 words, accuracy 91, 3 stars,
91 + 75 star bonus + 25 streak + 30 session = **224 points** (rounded to 224). Frame 30
(stopped part way): 32 of 48 words, accuracy 78, 2 stars, 78 + 50 + 25 + 30 = **183
points**.

---

## 15. Drawing Convincing Handwriting

Several frames live or die on whether the ink looks like a seven-year-old traced it. A
clean vector path will not do.

**Method.** Set the target line in the profile's face at the frame's size on a locked
layer at 30% opacity. Draw over it with Penpot's freehand path tool in a single gesture per
letter stroke, following the letterform but permitting real error: overshoot the baseline,
round off the corners, let the second half of a long word drift upward. Then delete the
guide layer (writing frames keep it; journal frames do not).

**Rules that make it read as authentic:**

- **Vary the width.** 1.5–5.0 pt at Large, scaled by `size / 72`. Constant width is the
  strongest tell that ink is fake.
- **Break at natural pen lifts** — between letters, and at the crossbar of *t* and the dot
  of *i*. A whole word in one unbroken path is wrong.
- **Put the errors where children actually make them:** exits from *a* and *o* overshoot,
  descenders on *g*, *y*, *p* fall short, and the letters at the end of a line lean.
- **Colour by geometry, not by taste.** A segment is `ink-outside` only where it genuinely
  sits outside the traced letterform. Roughly 20–25% red at 78%, under 10% at 94%.
- **Graded lines and the line in hand must read differently at a glance.** A graded line
  is `ink-natural` with no guide beneath it; the line in hand is guide plus red-and-green.
  If a reviewer has to look twice to tell which is which, the page has failed (§11.11).
- **If you change the face, re-measure.** Each face has a different advance width; ink drawn
  for Jua will not sit on Andika. The built file calibrates against the real face
  (`PENPOT_HANDOFF.md` §3).
- **Thumbnails** are the same artwork at ~10% of the thumbnail width per em, in
  `ink-natural`, never in accuracy colours.

---

## 16. States and Edge Cases Checklist

- [ ] First launch — no profiles exist (frame 2)
- [ ] New profile — no sessions, no streak, all badges grey (frame 10)
- [ ] Wrong PIN (frame 4)
- [ ] Profile with no photo — initial-letter avatar, distinct from the add tile (frame 1)
- [ ] An entry stopped part-way — a normal row reading "N words · not written yet"; opening it and tapping Edit carries on
- [ ] Recording stopped at the five-minute cap — banner over the page (frame 42)
- [ ] The page with nothing said yet — empty rules, centre mic (frame 20)
- [ ] Listening — words landing on the page live (frame 21)
- [ ] A spoken word being fixed in place, keyboard up (frame 22)
- [ ] Everything said, nothing written — all spoken text (frame 24)
- [ ] The page part written — traced above, one row selected, untraced below (frame 25)
- [ ] A traced row re-selected for fixing (frame 44)
- [ ] More dictation appended to an existing page (frame 45)
- [ ] An entry long enough to scroll both the writing page and Entry Detail (frames 25, 45, 14, 15)
- [ ] Search with results (frame 12)
- [ ] Eraser selected, mid-correction (frame 25 variant)
- [ ] Microphone not yet granted (frame 40) and refused (frame 41)
- [ ] Whole-journal export (frame 43)
- [ ] Progress with fewer than 5 tracings at one setting (frame 32)
- [ ] Guide lines toggled off (frame 46)
- [ ] Colourblind ink scheme (frame 47)
- [ ] Left-handed layout — toolbar and footer actions mirrored (frame 48)
- [ ] Extra Large and Extra Small size extremes (frames 26, 27)

Not required for v1 wireframes: dark mode, iPhone, landscape, offline or error states, Copy
mode, and any iCloud sync UI beyond the disabled row in frame 34.

---

## 17. Handoff Back To Development

When the frames are ready, I need:

1. **The Penpot file** (or `.penpot` export).
2. **A list of anything you changed** from §5–§11 — see `PENPOT_HANDOFF.md`.
3. **PNG exports at 2×** of every frame. All boards carry a 2× export preset, so
   `Export all` produces them in one action.

Development then starts at Phase 1 in `DESIGN_DOCUMENT.md` §15.

---

*Document version: 2.6*
*Last updated: 2026-08-27*
*Companion to DESIGN_DOCUMENT.md v2.6*
