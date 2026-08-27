# Handwritten Journal — Wireframe Specification

## Penpot handoff, v2.2

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
| Sentence settle (traced line rises into the page above) | 0.45 s | See §11.6 |
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
| `guide-text` | `#000000` @ 80% | The letters being traced |
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

### 7.4 Review scale

Accepted sentences shown in the **writing-so-far** panel render at **0.5 ×** the writing
size and line spacing, in `ink-natural`. At Large that is 36 / 48. Stroke widths scale with
it (§11.4).

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
| `Card / Session` (home) | 200 × 240, `radius-card`, `paper-raised`, `shadow-card`. Thumbnail 200 × 140 filling the top with the top corners rounded; date `caption`; `Stars / Compact`. When the session holds more than one sentence, a `+N` chip: 42 × 24, `radius-pill`, `paper-sunk`, `caption-sm` in `text-secondary`. |
| `Row / Session` (list) | h 132, full content width, `paper-raised`, `radius-card`, `shadow-card`, 16 pt padding. Thumbnail 160 × 100 `radius-chip` leading; then date + time `body-em`, first sentence `body` truncated to one line, metadata `caption` in `text-secondary` reading *"N sentences · NN% · Font Size"* — the session's mean accuracy, since there is only one tracing per sentence; `Stars / Row` trailing, vertically centred. |
| `Row / Sentence` (entry detail) | h 64, `paper-sunk`, `radius-chip`, 12 pt apart. Text `body` leading; `speaker.wave.2.fill` 22 pt + "Hear it" `caption` in `action`; `Stars / Compact`; accuracy `body-em` trailing. **No attempt count and no chevron** — there is nothing to drill into. |
| `Row / Unfinished` | A session the child stopped part-way. Same frame, 2 pt dashed `star-off` stroke instead of shadow. Thumbnail of the first written sentence; date + time; *Next: "…"*; a progress bar with "3 of 8 written"; trailing `Button / Secondary` labelled "Keep writing ›". |
| `Row / Sentence review` | h 76, `paper-sunk`, `radius-chip`. 28 pt number disc, text, an optional "written in N parts" chip in `paper-raised`, then `pencil.line` and `xmark` trailing. |
| `Queue chip` | 260 × 30, `radius-pill`. `paper-sunk` track, `action` fill at 25% opacity to the proportion done, label "Sentence N of M" in `caption` / `text-primary` centred across the **whole** chip — not across the fill, or it wraps. |
| `Level meter` | 420 × 40. 5 pt bars, 5 pt gaps, `action`, with the tail in `star-off`. Purely decorative in the wireframe; a real implementation reads the input level. |
| `Thumbnail` | Aspect 5:3, `paper` fill, 1 pt `divider` stroke, handwriting in `ink-natural` at ~10% of the thumbnail width per em. **Never accuracy colours.** |
| `Writing so far` | The live journal page on every writing screen. `paper` fill, 1 pt `divider`, `radius-card`, 24 pt padding. Accepted sentences flow continuously at the review scale (§7.4) over ruled lines, newest last. Scrollbar 4 pt on the right inset 14 pt. Empty state: two centred lines of `body` / `caption` in `text-secondary`. |
| `Toggle / TypedHandwritten` | 420 × 56, `radius-pill`, `paper-sunk` track. Two 210 pt segments. Selected: `paper-raised` inset 4 pt, `shadow-card`, `button-sm` in `text-primary`. Unselected `button-sm` in `text-secondary`. |
| `Cell / Calendar` | 88 × 88. Day numeral `body` centred. Entry dot 8 pt in `action`, 8 pt below the numeral. Today: 2 pt `action` ring. |
| `Font option` | Full content width × 176, `radius-card`. Selected: `paper-raised`, `shadow-card`, 3 pt `action` stroke, `checkmark` 24 pt trailing. Unselected: `paper-sunk`. Name `headline`, reason `caption`, then a live preview of the sample sentence at 46 / 60 on one ruled line. |
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

```
  0       24  40                                   794 810  834
  ├────────┼───┼─────────────────────────────────────┼───┼───┤
  │                 Toolbar  h 72                            │  y 0
  ├──────────────────────────────────────────────────────────┤  y 72
  │   "Your writing so far"                                  │  y 92
  │   ┌──────────────────────────────────────────────────┐   │
  │   │        WRITING SO FAR   786 × 300  (scrolls)     │   │  y 124
  │   └──────────────────────────────────────────────────┘   │  y 424
  │   "Now trace this"                    Jua · Large        │  y 448
  │ ┌────────────────────────────────────────────────────┐   │
  │ │           WRITING SURFACE  754 × 530               │   │  y 480
  │ │              (does NOT scroll)                     │   │
  │ └────────────────────────────────────────────────────┘   │  y 1010
  │   Live accuracy: 78%                    [  Done ✓  ]     │  y 1040
  ├──────────────────────────────────────────────────────────┤  y 1170
  │                  Home indicator  24                      │
  └──────────────────────────────────────────────────────────┘  y 1194
```

| Value | Number |
|---|---|
| Left / right inset | **40 pt** (engine constant — do not change) |
| Surface width | 754 pt |
| Top edge | y = 480 |
| Surface height | 530 pt |
| Fill | `paper` |
| Writing-so-far panel | 786 × 300 at (24, 124), 24 pt padding, `radius-card` |

### 11.2 Ruled lines

Per line, three horizontal rules span the full surface width in `rule-line` at 1 pt:

1. **Ascender line** — dashed, 6 on / 4 off, at `baseline − 0.72 em`
2. **Baseline** — solid, at the text baseline
3. **Descender line** — dashed, 6 on / 4 off, at `baseline + 0.21 em`

Only the baseline is solid. This is deliberate: the child aims for the solid line.

**Ruled lines fill the whole surface**, not just the lines that carry text — it is a page,
not a caption. Toggled off entirely when the profile's "guide lines" setting is off.

### 11.3 Capacity

The 200-character transcript cap keeps any one sentence inside the surface at every size —
see §7.3. Text is **never** scrolled during tracing.

### 11.4 Accuracy is graded per letter

The mask is built **per glyph**, not per sentence. Each letter gets its own accuracy — the
proportion of the child's points inside *that* letter — and the sentence score is the mean
across every letter in it.

**A letter with no ink scores 0%.** This is the whole point: it makes an unfinished
sentence score like an unfinished sentence. Under the old sentence-wide measure, a child
who carefully traced four letters and tapped Done scored ~95%; now they score ~20%.

Coverage as a separate metric is **retired** — per-letter grading subsumes it.

**Live and final are different numbers, deliberately.**

| | What it counts |
|---|---|
| **Live**, on the writing screen | Only letters the child has started. Reads *"So far: 78%"*, with a hint below: *"16 letters still to go"*. |
| **Final**, at Done | Every letter, unstarted ones at 0%. |

If the live readout applied the zero penalty it would start at 0% and crawl upward for the
whole sentence, which feels like failing continuously. The hint carries the warning
instead, and the Reveal screen says plainly whether anything was left unfinished.

### 11.5 Ink

**While writing, ink is always drawn in `ink-inside` / `ink-outside` per segment.** There is
no toggle. **In the journal, ink is always `ink-natural`.** There is no toggle there either.
The two readings are different products of the same stored strokes (`DESIGN_DOCUMENT.md` §6).

Stroke width varies with pencil pressure between **1.5 pt and 5.0 pt at Large**, round cap,
round join, and **scales linearly with glyph size** (`size / 72`). Applied literally at
review or thumbnail scale the quoted range produces illegible blobs.

### 11.6 Scrolling

A scroll gesture and a pencil stroke are hard to tell apart, and finger tracing makes it
worse. Therefore:

- **The writing-so-far panel scrolls.** It is read-only, so a drag inside it is unambiguous.
- **The active writing surface never scrolls.** It is sized to fit one sentence.
- Journal, list, settings and progress screens scroll normally.
- If a surface ever must scroll during writing, it takes **two fingers** — one finger is
  always ink.
- **The Entry Detail page surface scrolls.** A long session overflows 560 pt; the scrollbar
  is drawn on frames 14, 15 and 18.

### 11.9 Long-form dictation and the fit rule

The child talks for as long as they like, up to **five minutes**. Nothing is written down
until they tap *I'm done talking*. The transcript is then split into **traceable pieces**.

**Splitting, in order of preference:**

1. **Punctuation** from the recogniser (`addsPunctuation`). Reliable for adults, patchy for
   a five-year-old who says "and then and then".
2. **Pauses** — `SFTranscriptionSegment.timestamp` gaps over ~700 ms.
3. **The fit rule**, always applied last: a piece must fit the writing surface. Anything
   longer is broken at the last word boundary that fits, and becomes two pieces.

**The fit rule is size-dependent and it bites.** Measured against the 754 pt surface:

| Size | pt | Lines | Chars/line | Fits |
|---|---|---|---|---|
| Extra Large | 96 | 3 | 18 | **~56** |
| Large | 72 | 4 | 24 | ~99 |
| Medium | 56 | 6 | 32 | ~192 |
| Small | 42 | 8 | 42 | ~341 |
| Extra Small | 30 | 11 | 59 | ~658 |

At Extra Large a perfectly ordinary spoken sentence will not fit and *must* split. Do not
treat the split as an error state — the review screen labels it plainly ("written in
2 parts") and moves on.

The splitter must measure with the **real font metrics** at the profile's size, not a
character count — the five faces differ by up to 40% in width (`PENPOT_HANDOFF.md` §3).

**Five minutes is far more than a child will write.** Forty seconds of talking produced
eight pieces in the fixture; five minutes produces around fourteen, which is 20+ minutes of
tracing. The cap exists because the recogniser drifts on long takes, not to hurry the
child. **Stopping part-way must be the easy, obvious, unpunished path** — every writing
screen carries "Finish for now", the count of what is saved is always visible, and an
unfinished session is the first thing on Journal Home (frame 9 variant) and the top section
of the journal list.

### 11.7 The eraser

A third tool beside Undo and Clear. Selected, the toolbar button fills `action` with a
12 pt radius and the pointer becomes a **72 pt dashed circle** in `text-secondary` over a
`paper-sunk` fill at 70% — the child can see exactly what is about to disappear.

Erasing removes every sampled point inside the circle and **re-scores the letters it
touched**. It is not undo: undo removes a whole stroke in order, the eraser removes a
region regardless of when it was drawn. Both exist because a child who wanders outside one
letter should not have to redraw the four before it.

Clear still wipes the sentence. Nothing is scored until Done.

### 11.10 The settle animation

When `Done` is tapped: the guide fades over 0.5 s (§4), then the ink shrinks to the review
scale and rises into the writing-so-far panel over 0.45 s, and the panel scrolls to the
bottom. This is the moment the child sees their page grow, and it is the emotional core of
the writing loop. Reduce Motion replaces it with a cross-fade.

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
| 9 | Journal Home — populated | "Your writing" card replaces the level card; 5 session cards |
| 9 | Journal Home — unfinished session waiting | The resume card takes the primary slot; "3 of 8 written" |
| 10 | Journal Home — empty | New profile, no sessions, no streak, badges grey |
| 11 | Journal List — populated | "Still to write" section (unfinished sessions) + two month sections |
| 12 | Journal List — search active | Query "grandma", 2 results, keyboard up |
| 13 | Journal Calendar | March grid, dots on written days |
| 14 | Entry Detail — Typed | A session page; toggle on "Typed" |
| 15 | Entry Detail — Handwritten | Same page in `ink-natural`; per-sentence rows with "Hear it" |
| 18 | Entry Detail — overflow menu open | Rename / Export / Delete |
| 19 | Export preview — one entry | Scope selector, one PDF page |
| 43 | Export preview — the whole journal | The book: 38 pages, fanned stack, size and options |

### `04 · Write`

| # | Frame | Notes |
|---|---|---|
| 20 | Write — session start | Empty writing-so-far panel, large mic, "Tell me about your day" |
| 21 | Write — recording | Long form: elapsed timer, level meter, scrolling live transcript |
| 22 | Write — review sentences | The list of 7, one flagged as needing 2 parts, edit and delete |
| 23 | Write — editing a sentence | Field focused, keyboard up, Split / Join / Delete |
| 24 | Write — tracing, first sentence | Guide text, ruled lines, no ink; queue chip "Sentence 1 of 8" |
| 25 | Write — tracing, in progress | ~40% traced, live accuracy colours, "So far: 78%" |
| 25 | Write — eraser active | Eraser selected, dashed cursor over the ink it will remove |
| 26 | Write — tracing, Extra Large font | 96 pt, two lines |
| 27 | Write — tracing, Extra Small font | 30 pt, a long sentence |
| 28 | Write — reveal, ink only | Guide gone, "Write another sentence" / "I'm finished" |
| 29 | Results — one sentence, 2 stars | Session summary, 78%, +183 points |
| 30 | Results — two sentences, 3 stars + new badge | 91% session average, +224 points |
| 36 | Write — tracing, third of eight | Two finished sentences above, the third being traced |
| 40 | Write — microphone access | Child-legible explainer shown *before* the iOS prompt |
| 41 | Write — microphone unavailable | Denied or unsupported; the keyboard becomes the primary path |
| 42 | Write — recording stopped at five minutes | Auto-stopped at the cap; 14 sentences ≈ 20 minutes of writing, said warmly |

**§16 variants** live on this page too, named as states of frames 24 and 25.

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

### 13.3 Frame 36 — Write, appending *(the defining screen of v2)*

| Element | x | y | Size |
|---|---|---|---|
| `Toolbar` — "Close" leading, date centred, eraser + undo + clear trailing at 52 pt pitch | 0 | 0 | 834 × 72 |
| "Your writing so far" `body-em` `text-secondary` | 24 | 92 | — |
| `Writing so far` panel | 24 | 124 | 786 × 300 |
| "Now trace this" `body-em` · "Jua · Large" `caption` trailing | 24 | 448 | — |
| Writing surface (§11) | 40 | 480 | 754 × 530 |
| "So far: 88%" `body`, with "14 letters still to go" `caption` beneath | 24 | 1030 | — |
| `Button / Primary` "Done ✓" | 530 | 1040 | 280 × 64 |

### 13.4 Frames 14 / 15 — Entry Detail

| Element | x | y | Size |
|---|---|---|---|
| `Toolbar` — back leading, "Wednesday, March 4" centred `title-1`, `ellipsis.circle` trailing | 0 | 0 | 834 × 72 |
| `Toggle / TypedHandwritten`, centred | 207 | 96 | 420 × 56 |
| Page surface, `paper`, 1 pt `divider`, `radius-card` | 24 | 176 | 786 × 560 |
| — the session's sentences flow continuously, 32 pt inner padding, ruled | | | |
| "Sentences" `body-em` · "Jua · Large · Trace" `caption` trailing | 24 | 760 | — |
| Sentence rows, `Row / Sentence`, 12 pt apart | 24 | 794 | 786 × 64 |
| — text · "Hear it" · `Stars / Compact` · "NN%" | | | |
| `Button / Secondary` "Trace This Again" | 137 | 1074 | 268 × 56 |
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

**Sessions** (Milo) — a session is one sitting and may hold several sentences

| Date | Time | Sentences | Session | Stars |
|---|---|---|---|---|
| Mar 4 | 4:12 PM | "I saw a red bird in the yard" (94%) · "It was on the fence by the gate" (88%) | 91% | ★★★ |
| Mar 3 | 5:40 PM | "We made pancakes with Grandma" (81%) | 81% | ★★☆ |
| Mar 1 | 10:05 AM | "My tower fell down but I built it again" (90%) | 90% | ★★★ |
| Feb 27 | 6:20 PM | "The dog has a cold nose" (66%) | 66% | ★☆☆ |
| Feb 25 | 4:48 PM | "I want to be an astronaut" (88%) | 88% | ★★☆ |

**A long-form dictation** (frame 20–23, 42) — 41 seconds, seven sentences, 294 characters:

> Today we went to the park and I saw a big dog. It was brown and white and it had a little
> silver bell that jingled when it ran across the grass. The dog wanted to play with me. We
> threw a ball for it. Then we had ice cream on the way home. Dad let me have chocolate. I
> want to go back tomorrow.

The second sentence is 96 characters, which does not fit Large (99 is the limit and the
splitter leaves a line spare), so it becomes **two pieces — eight in total**. This is the
fixture that exercises the fit rule.

**An unfinished session** (frames 9 variant, 11) — Mar 4, 5:30 PM, 3 of 8 written, next up
*"We threw a ball for it"*.

**Frame 12 only:** an older result for the query "grandma" — Jan 18, 3:15 PM, "Grandma read
me a story", 85%, Jua Extra Large.

**Canonical Results numbers.** Frame 29: one sentence, accuracy 78, 2 stars, 78 + 50 star
bonus + 25 streak + 30 session = **183 points**. Frame 30: two sentences averaging 91,
3 stars, 94 + 75 + 25 + 30 = **224 points**.

---

## 15. Drawing Convincing Handwriting

Several frames live or die on whether the ink looks like a seven-year-old traced it. A
clean vector path will not do.

**Method.** Set the target sentence in the profile's face at the frame's size on a locked
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
- **Frame 17 must show real improvement.** 61% → 79% → 94% on the same sentence is the
  entire argument for keeping attempt history; make it unmistakable.
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
- [ ] A session stopped part-way — resume card on Home, "Still to write" row in the list
- [ ] A sentence too long for the current size — split into parts (frame 22)
- [ ] Recording stopped at the five-minute cap (frame 42)
- [ ] First sentence of a session — writing-so-far panel empty (frame 24)
- [ ] Appending — panel populated, active sentence below (frame 36)
- [ ] Session with more than one sentence — `+N` chip, multi-sentence page (frames 9, 15)
- [ ] Search with results (frame 12)
- [ ] Eraser selected, mid-correction (frame 25 variant)
- [ ] Microphone not yet granted (frame 40) and refused (frame 41)
- [ ] Transcript at the 200-character cap (frame 42)
- [ ] A session long enough to scroll the Entry Detail page (frames 14, 15)
- [ ] Whole-journal export (frame 43)
- [ ] Progress with fewer than 5 tracings at one setting (frame 32)
- [ ] Guide lines toggled off — writing variant
- [ ] Colorblind ink scheme — writing variant
- [ ] Left-handed layout — toolbar actions mirrored, writing variant
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

*Document version: 2.2*
*Last updated: 2026-08-27*
*Companion to DESIGN_DOCUMENT.md v2.2*
