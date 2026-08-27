# Handwritten Journal — Wireframe Specification

## Penpot handoff, v1.0

Companion to `DESIGN_DOCUMENT.md`. That document decides *what the app does*; this one
decides *what it measures*, so full-fidelity wireframes can be built in Penpot without
inventing numbers. Every value here is a decision, not a suggestion — if a number is
wrong, change it here and the code will follow, because `AppConstants.swift` is generated
from §5–§9 of this file.

---

## 1. How To Use This Document

1. Build the **Foundations** page first (§5–§9). Everything else is assembled from it.
2. Build the **component library** (§10) as Penpot components, so a change to a button
   propagates to all 35 frames.
3. Lay out frames from the inventory in §12, starting with the eight marked **[MVP]**.
4. Where §13 gives coordinates, use them. Where it does not, follow the grid rules in §6
   and use judgement.
5. §15 is the technique note for drawing believable child handwriting in a vector tool —
   read it before attempting any frame that shows ink.

---

## 2. Penpot File Structure

One Penpot file: **`Handwritten Journal`**.

| Page | Contents |
|---|---|
| `00 · Foundations` | Color tokens, type scale, spacing ruler, elevation samples, icon sheet |
| `01 · Components` | Every component in §10, one per board, with all variants |
| `02 · Profiles` | Frames 1–8 |
| `03 · Journal` | Frames 9–19 |
| `04 · Write` | Frames 20–30 |
| `05 · Progress & Settings` | Frames 31–35 |
| `99 · Scratch` | Anything in progress; never referenced by development |

**Board naming:** `NN — Screen Name — state`, e.g. `04 — PIN Pad — wrong PIN`. The leading
number is the frame number from §12 and must not be reused. Development references frames
by number.

---

## 3. Artboards and Orientation

The app supports both orientations. Design **landscape first** — the tracing surface is
the reason the app exists, and a wider writing line is materially better for a child.

| | Size (pt) | Use |
|---|---|---|
| **Primary artboard** | **1194 × 834** | iPad Pro 11" landscape. Design every frame at this size. |
| Secondary artboard | 834 × 1194 | iPad Pro 11" portrait. Required only for the frames marked *P* in §12. |
| Narrow check | 1133 × 744 | iPad mini landscape. Do not draw; verify the primary layout does not break. |
| Wide check | 1376 × 1032 | iPad Pro 13" landscape. Do not draw; verify. |

Design in **points, at 1×**. Penpot pixels map 1:1 to iOS points. Export at 2× and 3× only
for image assets, never for layout reference.

**Safe areas.** In landscape, reserve 24 pt at the bottom for the home indicator and 0 pt
at the sides. In portrait, reserve 24 pt bottom. Nothing tappable may enter that band.

---

## 4. Interaction Constants

| Constant | Value | Note |
|---|---|---|
| Minimum tap target | 44 × 44 | Apple HIG floor. Child-facing primary actions are much larger. |
| Child primary action | ≥ 280 × 64 | Deliberately oversized; a six-year-old is the user. |
| Standard transition | 0.30 s ease-in-out | |
| Page-flip (typed ↔ handwritten) | 0.35 s | `rotation3DEffect`, y-axis |
| Guide fade on reveal | 0.50 s | |
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
| `ink-inside` | `#34C759` | Stroke inside the letter (accuracy mode) |
| `ink-outside` | `#FF3B30` | Stroke outside the letter (accuracy mode) |
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

**Dark mode is out of scope for v1.** The app is a paper journal and stays light. Do not
build dark variants.

---

## 6. Grid and Spacing

**Base unit: 8 pt.** Every spacing value is a multiple of 8, except the 4 pt micro-step.

| Step | Value | Typical use |
|---|---|---|
| `space-1` | 4 | Icon-to-label, tight pairs |
| `space-2` | 8 | Within a component |
| `space-3` | 12 | Between related lines of text |
| `space-4` | 16 | Between components in a group |
| `space-5` | 24 | Between groups |
| `space-6` | 32 | **Screen outer margin (landscape)** |
| `space-7` | 40 | **Writing surface inset (see §11)** |
| `space-8` | 56 | Between major sections |
| `space-9` | 72 | Above a screen's primary action |

**Screen margins:** 32 pt left/right in landscape, 24 pt in portrait. The writing surface
is the exception at 40 pt — that value comes from the ported engine and must not change
without a code change.

**Content width (landscape):** 1194 − (32 × 2) = **1130 pt**.

**Columns:** 12-column grid, 1130 pt wide, 24 pt gutters → 70.8 pt columns. Use it for the
Journal, Progress and Settings screens. The Profile Picker, Tracing and Results screens are
centered compositions and ignore the column grid.

---

## 7. Typography

Two families:

- **Jua** — the guide text and all journal content, typed or handwritten. Bundled with the
  app (already present in the reference project at
  `Original Traceright App/TraceRight/Resources/Fonts/`). Jua ships one weight; weight
  variation at higher levels comes from the SF Pro Rounded fallback, so **draw guide text
  in Jua and accept a single weight in the wireframes.**
- **SF Pro Rounded** — all UI chrome. Free from Apple; Penpot needs it installed locally or
  uploaded as a custom font to the file.

| Style | Font | Size | Weight | Line height | Use |
|---|---|---|---|---|---|
| `display` | SF Pro Rounded | 44 | Bold | 52 | Greeting, celebration copy |
| `title-1` | SF Pro Rounded | 34 | Bold | 41 | Screen titles |
| `title-2` | SF Pro Rounded | 28 | Semibold | 34 | Section headers |
| `headline` | SF Pro Rounded | 22 | Semibold | 28 | Card titles, profile names |
| `body` | SF Pro Rounded | 18 | Regular | 24 | Body copy, settings rows |
| `body-em` | SF Pro Rounded | 18 | Semibold | 24 | Emphasised body |
| `caption` | SF Pro Rounded | 15 | Regular | 20 | Metadata, dates |
| `caption-sm` | SF Pro Rounded | 13 | Regular | 18 | Chart axis labels |
| `button` | SF Pro Rounded | 24 | Bold | 28 | Primary button label |
| `button-sm` | SF Pro Rounded | 18 | Semibold | 22 | Secondary and toolbar buttons |
| `numeral-xl` | SF Pro Rounded | 60 | Bold | 68 | Accuracy percentage in the ring |
| `numeral-l` | SF Pro Rounded | 34 | Bold | 41 | Points, streak count |
| `journal` | Jua | level-driven | — | level-driven | Guide text and typed entry text |

`journal` sizes come from the level ladder and are not free choices:

| Level | Size | Line spacing |
|---|---|---|
| 1 | 96 | 120 |
| 2 | 84 | 108 |
| 3 | 72 | 96 |
| 4 | 64 | 84 |
| 5 | 56 | 72 |
| 6 | 48 | 64 |
| 7 | 42 | 56 |
| 8 | 36 | 48 |
| 9 | 30 | 40 |
| 10 | 24 | 32 |

**Draw all journal frames at Level 3 (72 / 96).** It is the realistic mid-ladder case and
shows both multi-line wrapping and comfortable letter size. Draw one Level 1 and one
Level 9 variant of the Tracing frame so the extremes are validated.

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

SF Symbols, weight **Medium**, rendered at the sizes in §10.

Penpot has no SF Symbols support. Get them in by opening the **SF Symbols** app on macOS,
selecting a symbol, `File ▸ Export Symbol…`, choosing SVG, and importing that SVG into the
Penpot file. Do this once into an icon sheet on `00 · Foundations` and reuse.

Required set:

| Symbol | Used on |
|---|---|
| `mic.fill` | Dictation |
| `keyboard` | Dictation — type instead |
| `arrow.uturn.backward` | Tracing — undo |
| `trash` | Tracing — clear; destructive rows |
| `checkmark` | Tracing — done; settings selection |
| `chevron.left` / `chevron.right` | Back, attempt pager |
| `gearshape.fill` | Settings |
| `chart.line.uptrend.xyaxis` | Progress |
| `magnifyingglass` | Journal search |
| `calendar` | Journal calendar view |
| `line.3.horizontal.decrease.circle` | Journal filter |
| `square.and.arrow.up` | Share / export |
| `ellipsis.circle` | Entry overflow menu |
| `camera.fill` | Avatar capture |
| `photo.on.rectangle` | Choose photo |
| `lock.fill` | Profile has a PIN |
| `flame.fill` | Streak |
| `star.fill` / `star` | Ratings |
| `pencil.line` | New entry |
| `person.crop.circle.badge.plus` | Add profile |
| `xmark` | Dismiss |
| `arrow.triangle.2.circlepath` | Switch user |

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
| `Avatar / Empty` | any | 2 pt dashed `star-off` | none — shows `person.crop.circle.badge.plus` at 40% of diameter |

**Lock badge:** 32 pt circle, `paper-raised` fill, `shadow-card`, `lock.fill` at 16 pt in
`text-secondary`. Anchored to the avatar's bottom-right at 45°, overlapping the ring by 4 pt.
Only on `Avatar / XL` and `Avatar / L`.

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

### 10.5 Progress indicators

| Component | Spec |
|---|---|
| `Ring / Results` | 220 outer diameter, 18 pt stroke, `paper-sunk` track, `action` progress, round cap, starts at 12 o'clock clockwise. `numeral-xl` centred with `caption` label 8 pt below. |
| `Ring / Home` | 120 outer, 12 pt stroke, same construction |
| `Bar / Level` | h 20, radius-pill, `paper-sunk` track, `action` fill |

### 10.6 Journal surfaces

| Component | Spec |
|---|---|
| `Card / Entry` (home) | 200 × 240, `radius-card`, `paper-raised`, `shadow-card`. Thumbnail 200 × 140 filling the top with the top corners rounded; date `caption`; stars `Stars / Compact`. 12 pt internal padding below the thumbnail. |
| `Row / Entry` (list) | h 132, full content width, `paper-raised`, `radius-card`, `shadow-card`, 16 pt internal padding. Thumbnail 160 × 100 `radius-chip` leading; then a text column — date `body-em`, text snippet `body` truncated to one line, metadata `caption` in `text-secondary`; `Stars / Row` trailing, vertically centred. |
| `Row / Draft` | Same frame, no thumbnail, 2 pt dashed `star-off` stroke instead of shadow, trailing `Button / Secondary` labelled "Write it". |
| `Thumbnail` | Aspect 5:3, `paper` fill, 1 pt `divider` stroke, handwriting rendered in `ink-natural` at ~28% scale. Never show accuracy colors in a thumbnail. |
| `Toggle / TypedHandwritten` | 420 × 56, `radius-pill`, `paper-sunk` track. Two 210 pt segments. Selected segment: `paper-raised` fill inset 4 pt, `radius-pill`, `shadow-card`, label `button-sm` in `text-primary`. Unselected label `button-sm` in `text-secondary`. |
| `Pager / Attempt` | h 44. `chevron.left` 24 pt, centre label `caption` in `text-secondary`, `chevron.right` 24 pt. Chevrons at 40% opacity when at an end. |
| `Cell / Calendar` | 88 × 88. Day numeral `body` centred. Entry dot 8 pt in `action`, 8 pt below the numeral. Today: 2 pt `action` ring. |

### 10.7 Badges

`Badge / Tile`: 88 circle + label below.
Earned — `paper-raised` fill, `shadow-card`, icon 40 pt in `star-on`, label `caption` in
`text-primary`. Unearned — `paper-sunk` fill, no shadow, icon 40 pt in `star-off`, label
`caption` in `text-secondary`. Label wraps to two lines maximum, centred, 88 pt wide.

### 10.8 Chrome

| Component | Spec |
|---|---|
| `Toolbar` | h 72, `paper` fill, 1 pt `divider` bottom edge. Leading back button, centred `title-1` title, trailing actions 16 pt apart. |
| `Bottom bar` (tracing only) | h 64, `paper` fill, 1 pt `divider` top edge |
| `Sheet / Modal` | 720 wide, height to content, `radius-sheet`, `paper-raised`, `shadow-modal`, centred, on `overlay-scrim` |
| `Sheet / Parent gate` | 560 × 420 |
| `Row / Setting` | h 64, full width, label `body` leading, control trailing, 1 pt `divider` bottom inset 16 pt leading |
| `Empty state` | Icon 72 pt in `star-off`, `title-2` heading in `text-primary` 24 pt below, `body` explanation in `text-secondary` 12 pt below, optional `Button / Primary` 32 pt below. Whole group vertically centred in the content area. |

---

## 11. The Writing Surface

The single most important spec in this document. It must match the ported engine exactly,
because the guide text and the mask bitmap are generated from these numbers.

### 11.1 Geometry (landscape, 1194 × 834)

```
  0        40                                              1154   1194
  ├────────┼─────────────────────────────────────────────────┼──────┤
  │                    Toolbar  h 72                                 │  y 0
  ├──────────────────────────────────────────────────────────────────┤  y 72
  │        ┌─────────────────────────────────────────────────┐       │
  │        │                                                 │       │
  │        │            WRITING SURFACE                      │       │
  │        │            1074 × 674                           │       │
  │        │                                                 │       │
  │        └─────────────────────────────────────────────────┘       │
  ├──────────────────────────────────────────────────────────────────┤  y 746
  │                  Bottom bar  h 64                                │
  ├──────────────────────────────────────────────────────────────────┤  y 810
  │                  Home indicator  24                              │
  └──────────────────────────────────────────────────────────────────┘  y 834
```

| Value | Number |
|---|---|
| Left / right inset | **40 pt** (engine constant — do not change) |
| Surface width | 1074 pt |
| Top edge | y = 72 (below toolbar) |
| Bottom edge | y = 746 (above bottom bar) |
| Surface height | 674 pt |
| Fill | `paper` |

### 11.2 Ruled lines

Per line of text, three horizontal rules span the full 1074 pt surface width in
`rule-line` at 1 pt:

1. **Ascender line** — dashed, 6 on / 4 off, at `baseline − ascent`
2. **Baseline** — solid, at the text baseline
3. **Descender line** — dashed, 6 on / 4 off, at `baseline + descent`

Only the baseline is solid. This is deliberate: the child aims for the solid line.

Toggled off entirely when the profile's "guide lines" setting is off — draw that variant.

### 11.3 Line capacity

At Level 3 (72 pt Jua, 96 pt line spacing), 674 pt of surface height fits **7 lines**.
At Level 1 (96 / 120) it fits **5**. At Level 9 (30 / 40) it fits **16**. Text longer than
the surface is not scrolled in v1 — the 200-character transcript cap keeps it in range at
every level, and the wireframes should show a two-line and a four-line example only.

### 11.4 Ink

Live tracing and Reveal draw ink in `ink-inside` / `ink-outside` per segment. Journal
review draws the same strokes in `ink-natural` unless "Show accuracy colors" is on.

Stroke width varies with pencil pressure between **1.5 pt and 5.0 pt**, round cap, round
join. In wireframes, draw at a nominal 3.5 pt with visible variation — flat-width strokes
read as vector art and undermine the whole illusion.

---

## 12. Frame Inventory

35 frames. The eight marked **[MVP]** are the ones I need to start development; the rest
can follow. *P* means a portrait variant is also required.

### `02 · Profiles`

| # | Frame | Notes |
|---|---|---|
| 1 | Profile Picker — populated **[MVP]** *P* | 3 profiles + add tile; two show lock badges |
| 2 | Profile Picker — first launch, empty | Only the add tile, with `Empty state` copy |
| 3 | PIN Pad — entering | 2 of 4 dots filled |
| 4 | PIN Pad — wrong PIN | Danger dots mid-shake |
| 5 | Profile Editor — new, empty **[MVP]** | Empty avatar, empty name, "No PIN" selected |
| 6 | Profile Editor — existing, with photo | Populated, PIN set, Delete visible |
| 7 | Avatar Capture — live camera | Circular mask, countdown "3" |
| 8 | Parent Gate — math challenge | `Sheet / Parent gate`, "What is 7 × 8?" |

### `03 · Journal`

| # | Frame | Notes |
|---|---|---|
| 9 | Journal Home — populated **[MVP]** *P* | Full dashboard, 5 recent cards |
| 10 | Journal Home — empty | New profile, no entries, level 1, no streak |
| 11 | Journal List — populated **[MVP]** | Drafts section + two month sections |
| 12 | Journal List — search active | Query "grandma", 2 results, keyboard up |
| 13 | Journal Calendar | March grid, dots on written days |
| 14 | Entry Detail — Typed **[MVP]** *P* | Toggle on "Typed" |
| 15 | Entry Detail — Handwritten, natural ink **[MVP]** *P* | Toggle on "Handwritten", `ink-natural` |
| 16 | Entry Detail — Handwritten, accuracy colors | Same strokes, green/red |
| 17 | Entry Detail — attempt pager | "Tracing 1 of 3", visibly worse handwriting |
| 18 | Entry Detail — overflow menu open | Rename / Export / Delete |
| 19 | Export preview | PDF page: handwriting, date, typed caption |

### `04 · Write`

| # | Frame | Notes |
|---|---|---|
| 20 | Dictation — idle | Large mic, prompt "What do you want to write, Milo?" |
| 21 | Dictation — recording **[MVP]** | Pulsing rings, live partial transcript |
| 22 | Transcript Confirm | Text in Jua, "Is that right? Tap to fix it." |
| 23 | Transcript Confirm — editing | Field focused, keyboard up, caret |
| 24 | Tracing — untouched **[MVP]** | Guide text, ruled lines, no ink. Level 3. |
| 25 | Tracing — in progress | ~60% traced, mixed green/red, live accuracy 78% |
| 26 | Tracing — Level 1 variant | 96 pt, two lines |
| 27 | Tracing — Level 9 variant | 30 pt, four lines |
| 28 | Reveal — ink only | Guide gone, "Save to My Journal" |
| 29 | Results — 2 stars **[MVP]** | Ring at 78%, +183 points |
| 30 | Results — 3 stars + new badge | Badge callout, "Best yet at Level 3" |

### `05 · Progress & Settings`

| # | Frame | Notes |
|---|---|---|
| 31 | Progress — 90 days | Chart with two level markers, per-level table |
| 32 | Progress — insufficient data | Fewer than 5 attempts; empty state |
| 33 | Settings — profile | All per-profile toggles |
| 34 | Settings — app | iCloud row disabled, "Coming soon" |
| 35 | Level-up celebration | Full-screen overlay, confetti, "LEVEL 4" |

---

## 13. Key Screen Layouts

Coordinates are landscape, 1194 × 834, measured from the top-left. Screens not listed here
follow the grid rules in §6.

### 13.1 Frame 1 — Profile Picker

| Element | x | y | Size |
|---|---|---|---|
| Title "Handwritten Journal", `title-1`, centred | — | 88 | — |
| Subtitle "Who's writing today?", `headline`, `text-secondary`, centred | — | 140 | — |
| Avatar row (4 × `Avatar / XL`, 64 pt gaps, total 832) | 181 | 320 | 832 × 160 |
| Names, `headline`, centred under each avatar | — | 500 | — |
| Settings gear, `Button / Toolbar` | 1118 | 32 | 44 × 44 |

The avatar row is centred as a group. With three profiles plus the add tile the row is
832 pt; recompute the start x if the count differs — always centre.

### 13.2 Frame 9 — Journal Home

| Element | x | y | Size |
|---|---|---|---|
| `Avatar / M` (tap to switch user) | 32 | 32 | 56 |
| Switch-user badge on avatar, `arrow.triangle.2.circlepath` 14 pt | 72 | 72 | 22 |
| Name, `display` | 104 | 30 | — |
| Streak, flame 20 pt + `body` in `streak-flame` | 104 | 82 | — |
| Progress button, `Button / Toolbar` | 1058 | 36 | 44 |
| Settings button, `Button / Toolbar` | 1118 | 36 | 44 |
| Level card, `paper-sunk`, `radius-card` | 32 | 140 | 1130 × 96 |
| — Level label `headline`, bar `Bar / Level`, star count `caption` inside at 24 pt padding | | | |
| `Button / Primary` "✎ New Entry" | 437 | 272 | 320 × 72 |
| "Recent" `title-2` | 32 | 388 | — |
| "See all ▸" `button-sm`, trailing | — | 392 | — |
| Recent row: 5 × `Card / Entry`, 24 pt gaps (total 1096) | 32 | 430 | 1096 × 240 |
| "Badges" `title-2` | 32 | 698 | — |
| Badge strip: 64 pt circles, 20 pt gaps, **no labels** | 32 | 738 | — |

The home badge strip drops the labels — at 64 pt with two-line labels the row would cross
the bottom safe area. Labels appear in the full badge showcase, reached by tapping the row.
As laid out, the strip ends at y = 802 against an 810 pt safe limit.

### 13.3 Frame 14 / 15 — Entry Detail

| Element | x | y | Size |
|---|---|---|---|
| `Toolbar` — back leading, "Wednesday, March 4" centred `title-1`, `ellipsis.circle` trailing | 0 | 0 | 1194 × 72 |
| `Toggle / TypedHandwritten`, centred | 387 | 96 | 420 × 56 |
| Page surface, `paper`, 1 pt `divider`, `radius-card` | 40 | 176 | 1114 × 470 |
| — Typed state: transcript in `journal` at Level 3, ruled lines visible, 40 pt inner padding | | | |
| — Handwritten state: archived strokes, same ruled lines, same inner padding | | | |
| `Pager / Attempt`, centred | — | 666 | 420 × 44 |
| "Show accuracy colors" toggle row, centred | — | 718 | — |
| `Button / Secondary` "Trace This Again" | 337 | 762 | 260 × 56 |
| `Button / Secondary` "Share" | 613 | 762 | 244 × 56 |

Frames 14 and 15 must be **pixel-identical apart from the page surface contents and the
selected toggle segment**. The whole point of the feature is that the two readings sit in
the same frame; any drift between them will read as a glitch when the page flips.

### 13.4 Frame 24 — Tracing

| Element | x | y | Size |
|---|---|---|---|
| `Toolbar`: "Level 3 · Mar 4" leading `headline`; undo, clear trailing; `Button / Primary` "Done ✓" at 160 × 48 far trailing | 0 | 0 | 1194 × 72 |
| Writing surface (§11) | 40 | 72 | 1074 × 674 |
| Bottom bar: "Live accuracy: 78%" `body` leading at 40 pt | 0 | 746 | 1194 × 64 |

---

## 14. Sample Content

Use these fixtures verbatim across every frame. Consistent sample data makes the frame set
read as one product instead of 35 sketches.

**Profiles**

| Name | PIN | Level | Stars | Streak | Notes |
|---|---|---|---|---|---|
| Milo | yes | 3 | 15 | 5 days | The primary subject of every populated frame |
| Ada | no | 1 | 4 | 0 | Younger sibling; used to show a second avatar |
| Dad | yes | 10 | 220 | 0 | Parent profile |

**Entries** (Milo)

| Date | Text | Attempts | Best |
|---|---|---|---|
| Mar 4 | "I saw a red bird in the yard" | 3 | 94%, ★★★ |
| Mar 3 | "We made pancakes with Grandma" | 1 | 81%, ★★☆ |
| Mar 1 | "My tower fell down but I built it again" | 2 | 90%, ★★★ |
| Feb 27 | "The dog has a cold nose" | 1 | 66%, ★☆☆ |
| Feb 25 | "I want to be an astronaut" | 1 | 88%, ★★☆ |

**Drafts:** "Tomorrow we go to the museum" · "Grandpa is teaching me chess"

**Canonical numbers for the Results frames:** accuracy 78%, 2 stars, base 78 + star bonus
50 + streak bonus 25 + level bonus 30 = **183 points**. Frame 30 uses accuracy 94%,
3 stars, 94 + 75 + 25 + 30 = **224 points**.

---

## 15. Drawing Convincing Handwriting

Several frames live or die on whether the ink looks like a seven-year-old traced it. A
clean vector path will not do.

**Method.** Set the target sentence in Jua at the frame's level size on a locked layer at
30% opacity. Draw over it with Penpot's freehand path tool in a single gesture per letter
stroke, following the letterform but permitting real error: overshoot the baseline, round
off the corners, let the second half of a long word drift upward. Then delete the guide
layer (Tracing and Reveal frames keep it; Entry Detail frames do not).

**Rules that make it read as authentic:**

- **Vary the width.** 1.5–5.0 pt within a single stroke. Constant width is the strongest
  tell that ink is fake.
- **Break at natural pen lifts** — between letters, and at the crossbar of *t* and the dot
  of *i*. A whole word in one unbroken path is wrong.
- **Put the errors where children actually make them:** exits from *a* and *o* overshoot,
  descenders on *g*, *y*, *p* fall short, and the letters at the end of a line lean.
- **In accuracy-mode frames, colour by geometry, not by taste.** A segment is
  `ink-outside` only where it genuinely sits outside the traced letterform. Roughly 20–25%
  red for the 78% frames, under 10% for the 94% frames. Red placed decoratively will look
  wrong to anyone who has watched a child trace.
- **Frame 17 must be visibly worse than frame 15.** It is attempt 1 against attempt 3 of
  the same sentence — that contrast is the entire argument for keeping attempt history, so
  make it unmistakable.
- **Thumbnails** are the same artwork scaled to ~28%, in `ink-natural`, never in accuracy
  colours.

---

## 16. States and Edge Cases Checklist

Full fidelity means the unhappy paths are drawn too. Confirm each is covered before
sign-off:

- [ ] First launch — no profiles exist (frame 2)
- [ ] New profile — no entries, level 1, no streak, all badges grey (frame 10)
- [ ] Wrong PIN (frame 4)
- [ ] Profile with no photo — `Avatar / Empty` in the picker
- [ ] Draft entry with no tracing yet (frame 11, drafts section)
- [ ] Entry with exactly one attempt — attempt pager hidden (frame 15)
- [ ] Entry with three attempts — pager visible (frame 17)
- [ ] Search with results (frame 12)
- [ ] Progress with fewer than 5 attempts — trend suppressed (frame 32)
- [ ] Guide lines toggled off — Tracing variant
- [ ] Colorblind ink scheme — one Tracing or Results variant
- [ ] Left-handed layout — toolbar actions mirrored, one Tracing variant
- [ ] Destructive confirmation behind the parent gate (frame 8)

Not required for v1 wireframes: dark mode, iPhone, offline or error states (the app is
fully offline by design), and any iCloud sync UI beyond the disabled row in frame 34.

---

## 17. Handoff Back To Development

When the frames are ready, I need:

1. **The Penpot file** (or `.penpot` export). This machine has a local Penpot MCP
   connection, so I can read boards and export shapes directly once the file is here.
2. **A list of anything you changed** from §5–§11. Those sections are the source of truth
   for `AppConstants.swift`; if the spacing or a colour moved during design, the code has
   to move with it.
3. **PNG exports at 2×** of the eight `[MVP]` frames, as a visual reference I can check
   the built screens against.

Development then starts at Phase 1 in `DESIGN_DOCUMENT.md` §15.

---

*Document version: 1.0*
*Last updated: 2026-08-27*
*Companion to DESIGN_DOCUMENT.md v1.1*
