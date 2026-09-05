# Penpot Wireframes — Handoff Notes

Companion to `WIREFRAME_SPEC.md` v2.7. Answers §17.2: *"a list of anything you changed
from §5–§11."*

Penpot file: **`Wireframes`**. Rebuilt for v2.0, revised for v2.1–v2.6 on 2026-08-27,
revised for v2.7 on 2026-09-01 (frames 7, 11 and 13 removed to match the code),
for v2.8 on 2026-09-01 (the style-guide palette — see §1.1 below), swept against the
app for v3.1/v3.2 on 2026-09-02 (§1.-1 — the exploration pages promoted and deleted), and
given a landscape page the same day (§1.-2), and the welcome frames the same day
again (§1.-3), swept against the app for v3.5–v3.10 on 2026-09-04 (§1.-4), and given the
first-visit frames on 2026-09-05 (§1.-5).

## 1.-5 The first visit *(drawn 2026-09-05, v3.11)*

Two frames on `03 · Journal`, continuing the top row after 54: **`61 — Journal Home — the
first visit, Practice my letters`** (x 3736) and **`62 — Journal Home — the first visit,
New Entry`** (x 4670). Each is frame 9 cloned with the overlay drawn over it the way the
app composes it (`WIREFRAME_SPEC.md` §13.9):

- **The scrim with the tile cut out** is one Boolean — the full-frame `#000000` 40%
  rectangle *minus* a 28-radius rounded rectangle 8 pt outside the tile
  (`createBoolean('difference', [scrim, hole])`) — so the tile beneath shows through
  untouched, as on the iPad, rather than a copy of the tile sitting on the scrim. A 3 pt
  `action` rim, inner-aligned, traces the hole.
- **The bubble** is one path — the rounded card with the tail on its top edge, from an SVG
  path with `A` arcs for the corners — in `paper-raised` under the `shadow-modal` cut-paper
  shadow (0 / 6 / 0 at 18%), with the line in the `headline` typography and *Skip* in
  `button-sm` `text-secondary`, grouped as `Bubble / Speech`. Frame 61's card is 158 tall
  (two lines), frame 62's 186 (three) — the app sizes it to the words the same way.
- **The finger** is the real symbol: `hand.point.up.left.fill` rendered at 72 pt, its alpha
  traced (a throwaway marching-squares pass over an 8× bitmap, simplified to 63 points)
  and imported as a path in a 72 × 78 box, filled `text-primary` with a 2 pt `paper-raised`
  outer stroke for the rim and a soft shadow (0 / 3 / blur 4 at 30%). The box sits so the
  fingertip is at 62% of the tile's width, 6 pt under its centre line; the 44 pt `action`
  ring at the tip is the press. Named `Finger · hand.point.up.left`.
- **Annotations** in the usual bottom-of-frame style (Nunito 15, `action`, 786 wide at
  y 1150), as fixed-height boxes — auto-height texts made from the plugin never laid out
  this session.

**New in the library.** `hand.point.up.left` joins the Foundations icon sheet at (399, 2708),
beside `questionmark.circle` — 27 icons now. It is the traced silhouette scaled to 32 pt,
in ink, the way the other filled symbols are drawn.

**Two more, the same day, on `04 · Write`** — the spotlight's other two targets
(`WIREFRAME_SPEC.md` §13.9): **`63 — Practice — the first tap`** (x 1868, y 6470) is frame
49 cloned with the big A's cell cut out of the scrim (72 × 128 at (32, 182), `radius-chip`
+ 8, the 3 pt `action` rim), the bubble under it at the left margin with its tail on the
A, and the finger on the A; **`64 — Write — the first entry's tap`** (x 2802, y 6470) is
frame 20 cloned with the 176 pt microphone cut out as a circle (192 across at (321, 692)),
the bubble centred under it and the finger on the microphone. Same construction as 61/62;
each keeps its screen's chrome and carries a fresh annotation.

## 1.-4 The v3.5 – v3.10 sweep *(2026-09-04)*

The file had not been touched since v3.6. This pass brought it up to the app as it stands
today — v3.7 (the string catalog and the recorded voice) changed nothing visible, so the
work is v3.5's leftover, v3.8, v3.10 and the analytics removal that is still in the
working tree.

**One new frame. `60 — Practice — how to trace a letter`** on `04 · Write`, beside frame
50 (x 934, y 6470). It is frame 49 cloned, dimmed under a 35% scrim, with the card over
it: the title, the ✕ in its `paper-sunk` disc, three step rows (1 and 2 done, 3 current,
so the disc treatments and both text weights are all visible at once), the 320 × 400
one-letter sheet, and the two text buttons. `WIREFRAME_SPEC.md` §13.8 has the numbers.

**What the frame settles, and where it left the spec.** Step 3 wraps to two lines at 640
wide, so the sheet cannot start at the spec's y 245: the card is **640 × 765**, the sheet
starts at **265** and the buttons at **689**. §13.8 now says so. The sheet beneath is
drawn in its idle state — the *G* back to `guide-text`, no award chip, "Touch a letter to
start." — because the tutorial is what a first visit opens.

**The letter.** The sheet is frame 57's construction (rules at the 40 pt insets, ascender
at 80, baseline at 296, descender at 359; Jua at 300 pt) with a little *a* centred instead
of a big *A*. Its formation is new: two `practice-path` strokes — the bowl anticlockwise
from the top right, then the stem — with a filled arrowhead at each end, the blue start
dot (12 pt `action` disc on a 16 pt `paper-raised` halo) where the bowl begins, green ink
over the traced part and a short red stray where it left the letter, so step 3's sentence
has something to point at. The **highlight cell** is `action` at 10% behind a 2 pt
`action` hairline at 38% — that is the app's `drawHighlight`, and it had never been drawn
in the file before.

**Frames edited in place:**

| Frame | Change |
|---|---|
| 49, 49 landscape | The **?** leads the trailing toolbar group; the annotation records the start dot and that no ink lands until the arrows have finished |
| 09, 10, 12, 54, 09 landscape | The Progress toolbar button is gone (v3.10 — the points card is the one way in) and so is the New Entry tile's "up to +230 points" chip (v3.5 — the points have no ceiling to promise). The landscape annotation and `Notes — 06 · Landscape` note 5 were rewritten to match |
| 25 | The annotation carries the v3.10 advance pause: a full row stays in hand until the pen has rested for a second |
| 33, 33 landscape | The PROFILE row is now a 48 pt avatar, the name in `body`, "Name, photo and PIN" in `caption-sm` and the chevron, 80 tall — the whole row a target. The Mode subtitle reads *Trace writing*. The landscape copy had also never caught v3.4's *Sound* → *Voice feedback* rename; it has now |
| 34 | **PROFILES** at the top: one row per profile (Milo with the photo stand-in, Ada with her initial, as frame 1 draws them) and the long-press note beneath. The **SYNC** section and its disabled iCloud row are gone |

**New in the library.** `questionmark.circle` joins the Foundations icon sheet at
(249, 818) — 26 icons now. It is the one icon drawn as a ring plus a Nunito glyph rather
than as paths, because §9's set had no question mark to trace.

**Working tree, not committed.** Frame 34's missing SYNC section and frame 33's *Trace
writing* subtitle follow the uncommitted Firebase/Telemetry removal (`Telemetry.swift`,
`GoogleService-Info.plist` and the Firebase package deleted, `PrivacyInfo.xcprivacy`
added). `DESIGN_DOCUMENT.md` §9 and its "not built" list still describe the disabled
iCloud row — worth a pass when that work is committed.

**Still open — frames 29 and 30.** Results still shows the **v3.4** point figures (224 and
183). v3.5 made points per letter and per whole word, and §14 now names a different
canonical example — *"I saw a red bird"*, perfectly, on a five-day streak, 24 + 9 + 9 + 30
+ 25 + 30 = 127. Redrawing those two frames means a new sample entry, not a new number, so
it was left for a decision rather than guessed at.


## 1.-3 The welcome and a voice *(drawn and built 2026-09-02, v3.4)*

Four frames added to `02 · Profiles` on a third row (y 2588): **55 — Welcome — a grown-up
agrees**, **56 — Welcome — voice feedback**, **57 — Welcome — trace a letter** and **58 —
Welcome — that was a finger**. `WIREFRAME_SPEC.md` §13.7 has the coordinates;
`DESIGN_DOCUMENT.md` §4.0 and §4.12 the behaviour. Two existing frames were edited in
place: **33** (the *Sound* row is now *Voice feedback* with a one-line subtitle) and
**34** (a LEGAL section — *Terms of use*, *Privacy policy*, the agreed-on line — and the
third note rewritten: the microphone feeds recognition and nothing else).

**What the frames settle.** The welcome is one screen family with three steps and a
step-dot header; every step is the page's width, centred, so there is no landscape frame
(in landscape the app scrolls 55 and 56, and puts 57's words and buttons beside the sheet
rather than let the sheet scroll).
Frame 57's letter sheet is the practice sheet (frame 49) at 320 × 400 with one character
on it, drawn the way frame 49 draws: rules at 40 pt insets, the letter as Jua text, the
formation as thin `practice-path` strokes with arrowheads, the child's ink over it. The
two rows that open Safari are a new `Row / Link` (§10.8) — `Row / Setting` with the label
in `action` and `square.and.arrow.up` trailing; the app draws `arrow.up.right.square`,
which the icon sheet does not have.

**What the app does differently from the frames** (built the same day):

- The welcome's privacy note mirrors the *published* policy's summary: no account; the
  journal never leaves the iPad; and no advertising, analytics, or crash reporting
  (`DESIGN_DOCUMENT.md` §10.5).
- The step dots are drawn by the app at the same sizes; *Back* returns to the previous
  step, and agreeing twice is harmless.
- A finger stroke on frame 57's sheet inks (the sheet allows a finger so it can be
  recognised); the frames draw the same ink on 57 and 58 and change only the status line
  and the button state.

**How they were built.** The `storage` helpers from the landscape pass, extended: boards
with `clipContent = false`, library typographies by name, icons by the SVG round-trip
from the Foundations sheet (ink → the wanted colour, paper cut-outs → the surface colour,
stroke-based icons scaled by 32), buttons as boards with an estimated label width, and
the letter sheet as a clipping board with Jua applied via `penpot.fonts.findByName`.
Each frame was one `execute_code` call and was exported at 0.5× to check.

**v3.6 (2026-09-02) — frame 59, *You'll need an Apple Pencil*, drawn after 58 (x 3736,
row 3).** *I don't have an Apple Pencil* no longer carries straight on: the tap shows this
page in place of the letter — the well, why the pencil is the point, three sunk notes, a
`Row / Link` to Apple's compatibility table, *Back to the letter*, *Skip for now* and a
caption. *Skip for now* finishes the welcome for that launch only; the pencil check is
back at the next, until a pencil traces the letter. Frame 57's annotation was rewritten
to say so. Built with the same `storage` helpers as 55–58 (still in the plugin after the
v3.4 pass). Deviations: the icon sheet has no `applepencil.and.scribble`,
`hand.raised.slash`, `pencil.tip.crop.circle` or `applepencil`, so the frame draws
`pencil.line` in the well and the third note and `hand.thumbsup` and
`checkmark.circle.fill` in the first two; the app draws the SF Symbols. The imported
`pencil.line` renders its body filled unless its path is given a fill in the surface
colour — done on 59 and on 57/58's buttons. `WIREFRAME_SPEC.md` §13.7 has the
coordinates.

## 1.-2 Landscape — page `06 · Landscape` *(drawn and adopted 2026-09-02, v3.3)*

A new page **`06 · Landscape`** holds landscape versions of one frame from each screen
family — **1194 × 834**, on a 1294 / 934 grid, each numbered after the portrait frame it
mirrors: 20, 24, 25 and 48 (Write), 29 (Results), 49 (Practice), 09 (Journal Home), 15
(Entry Detail), 01 (Profile Picker), 31 and 33 (the sheets), plus `Notes — 06 · Landscape`.
The plugin API cannot reorder pages, so it lands after `99 · Scratch` — drag it up by hand.
The portrait pages stay the reference for content and states; this page settles layout only.

**The rule that drives everything.** The page keeps its portrait width. Ink is stored at
the width it was written at (`canvasWidth` 754 — the 40 pt inset either side of an 834 pt
page) and is drawn over the guide letters, so a page must never re-wrap. In landscape the
writing page, the reading page and the practice sheet therefore stay 834 wide and the
extra 360 pt becomes a **rail**: everything the portrait footer held — mic, readout,
progress, the scroll chevron, *I'm finished* — stacks in it behind a 1 pt divider. The rail
sits on the side of the free hand: left for a right-handed child, right when *Left-handed
layout* is on (frame 48). A resting forearm never crosses a button, and the finish button
is a reach away from the pencil rather than under the palm. The page is 762 tall instead
of 958, so it scrolls sooner — about 8 lines at Large rather than 10. The toolbar is the
portrait toolbar stretched: Back leading, the date centred, the tools trailing at 52 pt.

**The other screens.** Journal Home is two columns — dashboard (header, deck, points,
badges) at 560 on the left, journal (search, rows) at 562 on the right, Progress and
Settings keeping the top-right corner; the badge strip is a clipping board so it reads as
scrollable, and row quotes truncate to one line as the app does. Entry Detail keeps the
page at its width on the left and moves the stats card and both actions into the 336 pt
column beside it. Results is score left, page preview right, one button under both. The
Profile Picker is one row of four at the same 96 pt gaps. Progress and Settings are drawn
as **system page sheets** — the portrait layout centred over a scrim, scrolling inside;
nothing reflows, and the pickers, Export and app settings present the same way.

**What the app does differently from the frames** (built the same day as v3.3;
`WIREFRAME_SPEC.md` §3, §11.1, §13.6 and `DESIGN_DOCUMENT.md` §0.12 are the record):

- **Full screen only.** `project.yml` declares both landscape orientations and
  `UIRequiresFullScreen`, so there is never a Split View window narrower than the page.
- **The rail side is a setting.** *Controls in landscape* under WRITING — Auto (away from
  the writing hand), Left, Right — not only the handedness toggle the frames imply.
- **Entry Detail's column sits on the rail's side**, not always on the right as frame 15
  draws it, so the page does not jump when the pencil lands and Edit takes over.
- **Journal Home's dashboard is fixed in portrait too.** Only the entries scroll, in both
  orientations; the frame only showed landscape.
- **The undrawn states follow the family rule:** the word editor sits under the page
  column above the keyboard while the rail keeps its footer; the listening rail is the
  stop, the clock, the level and the caption stacked; the cap banner lies over the page.
- The practice sheet keeps its portrait width so the letters keep their size, as drawn.

**How they were built.** Each frame is a scripted deep copy of its portrait source (§7's
serialise-and-rebuild), moved subtree by subtree by a per-frame placement rule with width,
height and text overrides — so the handwriting, icons and styling are the originals, not
redrawn. The annotations on the frames and the notes board say which rule each one shows.

## 1.-1 v3.2 — the Write flow and the badge card *(promoted 2026-09-02)*

The exploration pages `13 · Journal` (2026-09-01) and `14 · Write` (2026-09-02) were both
adopted by the app the day they were drawn. **They have now been promoted onto the
canonical pages and both exploration pages are deleted** — there is one version of every
frame again, and it is the one the app builds.

**What moved.** Frames 9, 10 (from `13 · Journal`) and 20, 21, 22, 24, 25, 29, 30, 44
(from `14 · Write`) replaced the frames of the same numbers; **52 — doodling with the
crayon** and **53 — adding words with the keyboard** are new on `04 · Write`; frame 49
(Practice Letters) is the +2-a-letter alternate. The MCP plugin cannot move or clone a
shape across pages (§7), so each frame was serialised on its own page and rebuilt shape by
shape on the target — boards, groups, paths (by `d`), texts with their per-range styling —
then checked against an export of the original.

**What was rebuilt in place.** The write frames that had no alternate — 26, 27, 42, 45,
46, 47, 50 — were brought to v3.2 rather than redrawn: the `Segmented / View · Edit`
control removed, the leading *I'm finished* replaced by **Back**, `pencil`, `crayon` and
`textformat.abc` added to the toolbar at x 454 / 506 / 558, the date box widened to 300,
the footer's *Done* replaced by *I'm finished*, and a `Row handle` dropped into the margin
gutter of every row with the `pencil.line` marker on the row in hand.

**Frame 48 is built.** It was marked *NOT BUILT* because nothing read `isLeftHanded`;
`TracingCanvasView` now does. It is frame 25 with the handle gutter mirrored to the right
— which is all the app mirrors — and its note says so.

**Frame 54 — Journal Home — badge detail** is new (v3.2): `Sheet / Badge` over frame 9 for
*5-Day Streak*. Both states of the card — earned and not earned yet — are on
`01 · Components` under §10.8. The frame number is **54**, not 52: `WIREFRAME_SPEC.md`
had 52 promised to the badge card and already spent on the crayon frame.

**The other frames the app had outgrown:**

- **15 and 18 — Entry Detail.** The mode switch is gone from the toolbar (Back · date · ⋯),
  and *Hear what I said* is gone from the stats card and from the ⋯ menu, which is now the
  app's four rows with only *Delete this entry* in `danger`.
- **12 — Journal Home, search active.** It was still the old top search bar with a Cancel
  button. Rebuilt from frame 9: the page scrolled to the list, "2 results" as the section
  header, the query in the field with its clear control, two matching rows and the keyboard.
- **19 — Export preview.** Gained the on-device line and the two option toggles the app
  shows under every scope; **43**'s note no longer describes the Journal Home export
  button, which went in v3.1.

**One number to check on a device:** the resting-hand threshold,
`TracingCanvasView.handRadius` (50 pt of `UITouch.majorRadius`).

**Still by hand, please.** The plugin API cannot delete library assets: `Segmented / View · Edit`
joins `Bar / Level`, `Sheet / Parent gate`, `Toggle / TypedHandwritten` and the three stale
`journal / L*` typographies in §2.3/§2.5 as things to remove from the assets panel.

## 1.0 v2.9 — the journal reads only as handwriting

The app removed the typed reading of an entry (`EntryPageView` no longer has a
`Reading` state); the wireframes now match:

- **Frame 14 — Entry Detail — Typed is deleted.** The number joins the retired list.
- **Frames 15 and 18**: `Toggle / TypedHandwritten` removed, the page surface moved up
  to y 96 and grown to 786 × 700, one more ruled line added (6 now — the page keeps
  ruling below the last word), and the scrollbar stretched to match. Frame 15 renamed
  to plain "15 — Entry Detail".
- **`Toggle / TypedHandwritten` is retired.** Like the other retired components, the
  plugin API cannot delete it from the assets panel — **please remove it by hand**
  along with the items in §2.3/§2.5. Its main-instance board still sits on
  `01 · Components` under `10.6`.
- 37 artboards now (was 38).

## 1.1 v2.8 — the style-guide palette

Every page was swept for the v2.8 token values (`WIREFRAME_SPEC.md` §5/§8,
`STYLE_GUIDE.md` for the decisions):

- **Library colors updated in place:** `paper` `#FAF5E8`, `paper-sunk` `#F1E8D3`,
  `star-on` `#F28522`, `success` `#43A047`, `danger` `#D64541`. Three decorative
  accents added: `pencil-yellow`, `eraser-pink`, `lilac-star` (26 library colors now).
- **Shape fills/strokes swept by hex** on all seven pages. `#FF3B30` and `#34C759`
  were replaced only on semantic uses (destructive buttons/text/icons, wrong-PIN dots,
  the success note); the 432 generated accuracy-ink paths under `Live ink` and on
  `99 · Scratch`, and the `Swatch · ink-*` tiles, keep their original values.
- **All drop shadows re-cut** to the cut-paper spec (blur 8/24/48 → y 3/4/6, 0 blur,
  8/12/18%), and every `Button / Primary` board (except Disabled) now carries
  `shadow-card`.
- **Foundations:** swatches and hex labels updated, a `5.6 · Decorative` row added
  (the Color Tokens board grew to 1760 tall; the Icon Sheet moved down to y 1890),
  and the Elevation board's labels now state the cut-paper values.

---

## 1. What Is In The File

| Page | Contents | Boards |
|---|---|---|
| `00 · Foundations` | 26 color tokens, 17 type specimens, spacing/radii/stroke rulers, elevation samples, icon sheet (26 icons) | 5 |
| `01 · Components` | §10.1–§10.8, including both states of `Sheet / Badge` | 7 |
| `02 · Profiles` | Frames 1–6, 51, and the welcome 55–59 (§1.-3) | 12 |
| `03 · Journal` | Frames 9, 10, 12, 15, 18, 19, 43, 54 | 8 |
| `04 · Write` | Frames 20–22, 24–27, 29, 30, 40–50, 52, 53, 60 — every one a state of the single v3.2 screen | 22 |
| `05 · Progress & Settings` | Frames 31–34, 38, 39 | 6 |
| `06 · Landscape` | Landscape versions of frames 01, 09, 15, 20, 24, 25, 29, 31, 33, 48, 49 and a notes board (§1.-2) | 12 |
| `99 · Scratch` | Font calibration check; never referenced by development | 1 |

**48 portrait artboards at 834 × 1194** — every one verified for overflow — plus **11 landscape artboards at 1194 × 834** on `06 · Landscape` (§1.-2).

**Library:** 26 colors, 20 typographies, 19 components (recounted 2026-09-04).

### Retired frames — do not reuse the numbers

| # | Was | Why |
|---|---|---|
| 8 | Parent Gate — math challenge | Removed at your request. See §5 below — this one has a cost. |
| 16 | Entry Detail — accuracy colours | The journal is always natural ink now; there is nothing to show |
| 35 | Level-up celebration | Levels removed |
| 17 | Sentence attempts | Latest tracing only (v2.1) |
| 7 | Avatar Capture — live camera | The system photo picker replaced the camera (v2.7) |
| 11 | Journal List | Journal Home lists every entry itself (v2.7) |
| 13 | Journal Calendar | Removed (v2.7) |

### New frames

| # | Frame | Why it exists |
|---|---|---|
| 38 | Settings — font picker | You cannot choose a typeface from a name; this shows five live previews |
| 39 | Settings — font size picker | Same, plus the "ready to move down a size" nudge |
| 40 | Write — microphone access | Child-legible explainer shown *before* the iOS prompt |
| 41 | Write — microphone unavailable | Refused or unsupported; the keyboard takes over |
| 42 | Write — recording stopped at five minutes | Recording stops itself, copy stays warm |
| 43 | Export preview — the whole journal | The book: fanned stack, 38 pages, size and options |
| 44 | Write — tapping written text to write it again | The v2.4 re-trace gesture, drawn |
| 45 | Write — more dictation added to the page | Proves an entry grows rather than forking |
| 46–48 | Write — §16 variants | Guide lines off, colourblind ink, left-handed |

### Frames retired in v2.3 / v2.4 — do not reuse the numbers

| # | Was | Why |
|---|---|---|
| 23 | Write — split / join a long sentence | No splitter (v2.3) |
| 28 | Write — reveal, ink only | A line now reveals in place as it is finished (v2.4 §11.10) |
| 36 | Write — tracing, appending | Frames 25 and 45 cover it; there is no second surface to append to |

---

## 2. Deviations From `WIREFRAME_SPEC.md` §5–§11

### 2.1 Typography — SF Pro Rounded → **Nunito** *(§7.1)*

SF Pro Rounded is not in Penpot's font set and cannot be uploaded over MCP. Every UI chrome
style uses **Nunito** — closest open rounded-terminal equivalent, full 200–900 weight range.
Bold → 700, Semibold → 600, Regular → 400. Sizes and line heights match §7.1 exactly, so
swapping back is a one-pass change.

The five **journal faces are all real** and all render correctly (§7.2).

### 2.2 Iconography — SF Symbols → drawn vectors *(§9)*

Penpot has no SF Symbols support. All 26 symbols are drawn as 24 × 24 vector paths on the
Foundations icon sheet, named after their SF Symbol counterparts. Geometric equivalents,
not tracings. Replace with real SF Symbol SVG exports before sign-off; every call site
references them by symbol name.

### 2.3 Stale library typographies

`journal / L1`, `journal / L3` and `journal / L9` still sit in the file's assets. The Penpot
plugin API has no delete method for typographies, so **please remove those three by hand**
in the assets panel. Their replacements — `journal / Extra Large` through
`journal / Extra Small` — are already there and in use.

### 2.4 Frames 24, 26, 27 read "Live accuracy: —"

An untouched writing surface has no accuracy. Frame 25 shows the live number.

### 2.5 The Components page still carries a v1 section header

`10.8 · Chrome` had the parent-gate sheet removed in place; the section is otherwise
current. `Bar / Level` is gone from `10.5`, replaced by the `Segmented` control. The
retired components are still registered in the library — **delete `Bar / Level` and
`Sheet / Parent gate` from the assets panel** along with the typographies in §2.3.

---

## 3. How The Handwriting Was Made

§15 describes drawing over a locked guide layer by hand. The plugin API has no freehand
gesture, so the ink is generated:

- A single-stroke alphabet (39 glyphs) in em units, broken at natural pen lifts — between
  letters, at the crossbar of *t*, at the dot of *i*.
- **Calibrated per face.** Each of the five faces was measured against the same sentence at
  72 pt and my alphabet scaled to match:

  | Face | Real width @72 pt | Calibration |
  |---|---|---|
  | Jua | 847 pt | 1.000 |
  | Andika | 958 pt | 1.131 |
  | Baloo 2 | 845 pt | 0.998 |
  | Sniglet | 1183 pt | 1.397 |
  | Comic Neue | 863 pt | 1.019 |

  This is why the ink in frames 25 and 44 sits exactly on the guide letters beneath it, and
  why the font picker previews wrap the same way the real app will.
- Per-letter jitter that **increases along the line**, baseline overshoot, short descenders,
  a whole-line lean.
- Stroke width random-walks within §11.4's range, re-rolled every two Bézier segments,
  **scaled by `size / 72`**.

**Accuracy colouring is geometric.** Each segment's mean deviation from the un-jittered
letterform is tested against 0.075 em — about half a stem width. A seed is then searched so
the red fraction lands on §15's target for that accuracy: 6.3% at 94%, 23.4% at 78%,
36.1% at 66%.

---

## 4. Additions Not In §12–§13

- **Frame 1** — each profile shows its font and size under the name, and Ada is drawn with
  an **initial-letter avatar** to cover the "no photo" case without looking like the Add tile.
- **Frame 44** — the re-trace selection treatment (band, outline, chip) is mine, not the
  spec's. You asked for tapping graded text to re-trace it; nothing in §10 covered selecting
  a *line* rather than a component, so §11.12 and §13.3 were written from this frame.
- **Frame 39** — the "Milo has been above 90% for two weeks — Small might be ready to try"
  line. It is the only thing in v2 that replaces level progression, and it is addressed to a
  grown-up, not the child.
- **Frame 34** — a second plain-language note saying destructive actions are not gated (§5).
- **Frames 29 / 30** — the score breakdown line, so §14's 224 and 183 are checkable, and the
  split into "finished the whole entry" / "stopped part way" rather than "one sentence" /
  "two sentences".
- **Frame 12** — one fixture not in §14: *"Grandma read me a story"*, Jan 18, 85%. §12 asks
  for 2 results and only one §14 session contains the word.

---

## 5. Removing The Parent Gate Has A Cost

You asked for frame 8 to go, and it is gone. Recording what that changes:

Delete Profile and Reset Progress are now reachable by anyone holding the iPad. In a
household with two children and a shared device — which is the household this app is
designed for — one of them can erase the other's journal from the Settings screen in three
taps, and the journal is the entire product.

I have labelled both actions "Grown-ups only" and written a note into frame 34 saying
plainly that the app does not check. That is honest, but honesty is not a control.

**Suggestion, not a request to reinstate the math puzzle:** a press-and-hold for three
seconds on the destructive button, or a "type DELETE" confirmation, stops a six-year-old
without the ceremony of a gate screen. Either is a component, not a frame. `DESIGN_DOCUMENT.md`
§10.3 and §16 record this as an accepted risk rather than a solved problem.

---

## 5.2 v2.2 Notes — long-form dictation

**The measurement that drove the design.** I checked how much text actually fits the 754 pt
writing surface at each size before drawing anything:

| Size | pt | Lines | Fits |
|---|---|---|---|
| Extra Large | 96 | 3 | **~56 characters** |
| Large | 72 | 4 | ~99 |
| Medium | 56 | 6 | ~192 |
| Small | 42 | 8 | ~341 |
| Extra Small | 30 | 11 | ~658 |

At Extra Large — the setting a five-year-old is most likely to be on — a perfectly ordinary
spoken sentence does not fit. So the splitter cannot be "split on full stops"; it has to
measure against the real font at the real size and break at word boundaries. The fixture is
built to exercise this: the second sentence is 96 characters, which overflows Large, so
seven spoken sentences become **eight pieces to write**.

**The workload problem is the real one.** 41 seconds of talking produced 8 pieces. Five
minutes produces around 14, which is 20+ minutes of tracing — far past what a five-year-old
will do in a sitting. The design answer is not a shorter cap but making *stopping* ordinary:

- "Finish for now — 5 saved for later" on the reveal screen, on every sentence.
- A "Sentence 3 of 8" queue chip so the child always knows where they are.
- No warning language anywhere. Stopping is not an abandon.

**Superseded in v2.6.** This section originally called for a resume card on Journal Home and
a "Still to write" section in the journal list. Both are gone: an entry is not a task with a
state. An unfinished entry is an ordinary row reading *"N words · not written yet"*, and
opening it and putting the pencil on the page — or tapping *Write on this page* — carries on (v3.2: the Edit switch is gone). See `DESIGN_DOCUMENT.md` §0.6.

**Frame 42 changed meaning.** It was "you hit the 200-character cap"; it is now "you talked
for five minutes". The copy stays warm — *"That's a whole lot of story!"* — and it states
the workload honestly: *"112 words · about 20 minutes of writing."*

**Drafts stopped existing as a thing.** An unfinished session *is* the draft, so
`Row / Draft` became `Row / Unfinished` with a progress bar, and the `Draft` model is
deleted from the design document. *(v2.6: `Row / Unfinished` is retired too — an unfinished
entry is now an ordinary row.)*

**Audio storage changed shape.** Recording a whole session rather than a sentence means a
5-minute master at ~1.2 MB; daily for five years is over 2 GB. v2.2 sliced the master into
per-sentence clips; **v2.4 keeps it whole**, because with no sentences there is nothing to
slice; *"Hear what I said"* was retired in v3.0 (no audio is kept).

---

## 5.5 v2.6 Notes — free row selection

**What you asked for:** pencil movements must never scroll; the end-of-line button goes;
three row states — previously traced (faint grey letterforms with the trace vectors over
them), selected (black lettering with green/red marks), untraced-unselected (light grey) —
and any row selectable by tapping it at any time.

**What changed in the file.** A new `guide-faint` token (#000 @ 15%); `04 · Write` frames
24–27 and 44–48 rebuilt: traced rows now show faint letterforms *under* the graphite ink,
exactly one row is black-with-accuracy-ink, the check icon is gone everywhere, and frame
44 became "tapping a traced row to fix it" — the row re-selected with its ink back in
accuracy colours, no band and no chip.

**Resolutions the request left open** (mirrored in the app, BUILD_LOG.md):

- Auto-advance survives: when the selected row's last letter gets ink, the next untraced
  row is selected on its own. Free tapping is the override, not the only mechanism.
- The record became *derived*: the unbroken run of fully-traced rows from the top. It can
  shrink if a record row's ink is erased.
- Fix-a-word moved to a **held finger** (taps now always mean "select this row"), and is
  gated to untraced rows with no traced row below them, so an edit can never reflow ink.
- Tools (eraser, undo, clear) are scoped to the selected row.

## 5.4 v2.5 Notes — one screen, spoken until written

**What you asked for:** one screen for speech capture, viewing, editing and tracing; and
text that is not finalised until the child taps the next line to trace, or an icon at the
end of the current line — *"the text doesn't become part of the record until they trace
it."*

**How it resolved.** The mic moved onto the page (footer, plus centre-stage when the page
is empty), dictation streams onto the ruled lines live, and fixing a misheard word is a tap
plus the keyboard, in place. Frames 20, 21, 22 and 42 kept their numbers but became states
of the page; nothing else was left to unify.

The finalisation rule became a third text tier: **spoken** (`spoken-text`, cool and pale) is
everything said-but-unwritten, **guide text now exists only on the line in hand**, and the
icon you asked for is the **end-of-line check** — outlined until every letter has ink,
filled after, tappable either way. Finishing a line (check, or tapping the next line) is
both the settle animation and the commit of that line's words to the record.

**Judgement calls made while drawing, worth your eye:**

- **In-order writing only.** Only the *next* spoken line can be taken in hand — a record
  assembled line by line has to stay contiguous or the entry stops reading as prose.
- **"I'm finished" commits the line in hand if it has any ink** (they traced it, so it
  counts; skipped letters score zero) and returns it to spoken if it has none.
- **The spoken buffer is kept but is not record.** It survives with the open entry so a
  child never has to re-say four minutes of story, but journal, search, exports and word
  counts read only written text.
- **Spoken text is the only editable tier.** The in-hand guide must not move under the
  pen; written lines are the record. Edits therefore can never reflow anything traced.
- **`spoken-text` is cooler as well as lighter than `guide-text`** (#5B6B8C @ 42% vs black
  @ 80%) so the two tiers separate even at a squint. This must be checked on a real panel.

**Retired as screens, kept as numbers:** 20 (start), 21 (recording), 22 (check — now
"fixing a word"), 42 (cap — now a banner). The review field is gone entirely; its job is
done word by word on the page.

## 5.3 v2.4 Notes — the page is the whole screen

**What you asked for:** previously written text at the top of the screen, new dictation
appearing in the traceable area and scrolling as it fills, and tapping graded text to
re-trace it.

**How it resolved.** The first part sounded like the v2 writing-so-far panel, but building
it that way would have put the child's finished work in one surface and their live work in
another, with a hard edge between them. Since the page already scrolls, the finished text is
*already* at the top of the screen — it just needed to stop looking like guide text. So a
finished line keeps its position, drops its guide, and turns from red-and-green to graphite.
The panel is gone and the page above the child's hand reads as continuous handwriting.

This also makes the third part legible without instruction: **a line with no guide under it
is a line you have written**, so tapping it to write it again is discoverable. Frame 44
draws the selected state — an `action` band at 12%, a 2 pt outline, and a "Write this line
again" chip beneath.

**Three line states** are now drawn on every Write frame (§11.11): graded, in hand,
untraced. Getting the middle one right matters most — it is guide text *plus* live accuracy
ink, which is the only state where both layers are visible at once.

**Frame 45 exists to prove appending.** It shows the page scrolled down with ten graded
lines above and fresh guide text below, at 48 of 58 words. Without it, "saying more adds to
this page" is a claim rather than a drawing.

**Results and Entry Detail lost their per-sentence lists.** Both now show one thumbnail of
the page plus one accuracy, one word count, one recording. `Row / Sentence` is retired and
replaced by `Card / Entry stats`.

**Frame 22 was rebuilt** as a single editable field holding the whole transcript, with a
caret at the end — no list, no split/join controls, nothing to review row by row.

---

## 5.1 v2.1 Notes

**The eraser** is drawn as a toolbar toggle plus a 72 pt dashed cursor over the ink it will
remove. The distinction worth preserving in code: **undo is chronological, the eraser is
spatial**. They are not redundant, and a child who overshoots one letter in a long word
needs the spatial one.

**Per-letter grading changes the live readout.** The writing screens now say *"So far: 78%"*
with *"16 letters still to go"* beneath, rather than a single "Live accuracy". If the live
number applied the zero-penalty it would start at 0% and crawl for the whole sentence,
which reads as continuous failure. The penalty lands at Done, and Reveal states the outcome
plainly. `WIREFRAME_SPEC.md` §11.4 has the rule.

**Latest-only rippled further than expected.** Removed: frame 17, the `Pager / Attempt`
component, the attempt count and chevron on every sentence row, "best of N tracings" from
the export page, and "best NN%" from every journal list row — a session now shows its
**mean** accuracy, because there is no longer a best to pick from.

**Voice playback** appeared as "Hear it" on each sentence row in frames 14, 15 and 18; it is retired as of v3.0 — no audio is recorded or kept.

**A defect fixed in passing:** toolbar labels ("Close", "Cancel", "Save", back labels) were
sitting flush against the top edge of every toolbar across all four pages — a helper ignored
vertical centring when a height was given without a width. 32 labels re-centred.

---

## 6. Known Rough Edges

1. **Frame 7** — the countdown numeral overlaps the silhouette's head; it wants a scrim
   behind it or to sit above the circle.
2. **Avatars are placeholder silhouettes**, not photographs. Real cropped photos would make
   frames 1, 3, 4, 6 and 9 read much more like the finished product.
3. **The badge set is invented.** Eight badges appear by name; `DESIGN_DOCUMENT.md` §8.4 now
   owns the list and the earn conditions — reconcile if you disagree with any of them.
4. **The Progress chart data is illustrative**, not derived. The per-setting table and the
   four counters use real figures.
5. **Scroll affordances are static.** Frames 45 and 15 draw a scrollbar; the fade at the
   clipped edge that a real implementation wants is not drawn, and the chevron button does
   not show its disabled state at the bottom of the page.
6. **The Components page has not been re-laid-out for portrait**, and it has not been
   updated since v2.1 — it still shows `Pager / Attempt`, the old sentence row and the
   writing-so-far panel. The components used in the frames are current; the catalogue page
   lags, and `Row / Sentence`, `Queue chip` and `Writing so far` should all be deleted from
   the assets panel along with the items in §2.3.
7. **Penpot's export service is unreliable** and got worse across these revisions, and it
   serves stale renders — a board exported immediately after an edit sometimes comes back
   as the previous version. Verify against the shape tree, not only the PNG. All boards are
   verified structurally; the v2.4 Write and Results frames were also rendered and looked
   at.
8. **Frame 22 still asks a five-year-old to proofread.** It is now one field rather than a
   list, which is much less work, but a child will tap "Start writing" and ignore it. That
   is the right default — a misheard word is still traceable — but the screen is really a
   grown-up surface wearing child clothes. Worth watching in testing.
9. **Tap, pen and scroll now share the writing surface.** The wireframes cannot prove the
   gesture separation works; only a device can. If tapping a graded line turns out to fire
   during ordinary writing, the fallback is a explicit "fix a line" toolbar mode rather
   than loosening the tap target.
10. **The left-handed variant (frame 48) mirrors the toolbar and footer but not the text.**
   Text stays left-aligned, which is correct for English; only the controls move away from
   the writing hand.

---

## 7. Penpot API Notes For Whoever Scripts This File Next

**A script that throws part-way still commits what it did.** `execute_code` is not
transactional. A helper that built a board, appended children, and then hit an error left
two orphaned boards and two empty text shapes sitting at the page root — invisible in the
canvas, but they show up as page children and they survive a later `remove()` pass that
only matches frame names. After any failed call, re-list `penpot.currentPage.root.children`
and clean up before retrying.

**Boards placed by a slot helper can land on top of each other.** Two frames were assigned
the same grid slot and overlapped exactly; nothing warned. Check for duplicate `(x, y)`
pairs across page children after any bulk placement.

**Renaming does not follow content.** Shape names are set at creation, so a text shape whose
`characters` you later edit keeps its old name (`Text · 91% · 2 sentences`). Search
`characters`, never `name`, when auditing copy.

1. **`penpot.group()` destroys imported SVG children** when grouped with any other shape
   type — renders blank while every property still reports correct values. Every composite
   here uses a **board with `clipContent = false`** instead. Groups of *only* imported SVGs
   are safe.
2. **Imported SVG paths arrive with empty `fills`/`strokes`** — colour lives in inaccessible
   `svgAttrs`. Assign by child index unconditionally; do not test for existing paint.
3. **Shapes are not extensible** (`shape.foo = x` throws) and **`penpot.createText("")`
   returns null**, so an empty string blows up on `applyToText`.
4. **Writes only land on the active page**, and `penpot.openPage()` is slow enough that a
   page switch plus heavy work in one `execute_code` call will time out — sometimes after
   the work has already committed, sometimes before. Switch pages in their own call, build
   one frame per call, and re-read the page before assuming a failed call did nothing.
5. **Avoid `await` inside frame builders.** An async text measurement per button was enough
   to push whole-frame calls over the limit; label widths are estimated instead.

---

*Generated alongside the v2.0 rebuild and the v2.1 / v2.2 revisions, 2026-08-27.*
