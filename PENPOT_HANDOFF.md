# Penpot Wireframes — Handoff Notes

Companion to `WIREFRAME_SPEC.md` v2.2. Answers §17.2: *"a list of anything you changed
from §5–§11."*

Penpot file: **`Wireframes`**. Rebuilt for v2.0, revised for v2.1 and v2.2 on 2026-08-27.

---

## 1. What Is In The File

| Page | Contents | Boards |
|---|---|---|
| `00 · Foundations` | 23 color tokens, 17 type specimens, spacing/radii/stroke rulers, elevation samples, 25-icon sheet | 5 |
| `01 · Components` | §10.1–§10.8 | 8 |
| `02 · Profiles` | Frames 1–7 | 7 |
| `03 · Journal` | Frames 9–15, 18, 19, 43 + the unfinished-session variant | 11 |
| `04 · Write` | Frames 20–30, 36, 40–42 + 4 state variants | 19 |
| `05 · Progress & Settings` | Frames 31–34, 38, 39 | 6 |

**43 artboards, all portrait 834 × 1194** — 38 numbered frames plus 5 variant states —
every one verified for overflow and carrying a PNG @2× export preset.

**Library:** 23 colors, 20 typographies, 31 components.

### Frames retired in v2.0 — do not reuse the numbers

| # | Was | Why |
|---|---|---|
| 8 | Parent Gate — math challenge | Removed at your request. See §5 below — this one has a cost. |
| 16 | Entry Detail — accuracy colours | The journal is always natural ink now; there is nothing to show |
| 35 | Level-up celebration | Levels removed |
| 17 | Sentence attempts | Latest tracing only (v2.1) |

### New frames

| # | Frame | Why it exists |
|---|---|---|
| 36 | Write — tracing, appending | The defining screen of v2: sentence one sits above, sentence two is being traced |
| 38 | Settings — font picker | You cannot choose a typeface from a name; this shows five live previews |
| 39 | Settings — font size picker | Same, plus the "ready to move down a size" nudge |
| 40 | Write — microphone access | Child-legible explainer shown *before* the iOS prompt |
| 41 | Write — microphone unavailable | Refused or unsupported; the keyboard takes over |
| 42 | Write — at the 200-character limit | Recording stops itself, copy stays warm |
| 43 | Export preview — the whole journal | The book: fanned stack, 38 pages, size and options |

### New variant states

`25 — Write — eraser active` sits alongside the three §16 variants (guide lines off,
colorblind ink, left-handed) as states of frames 24 and 25.

---

## 2. Deviations From `WIREFRAME_SPEC.md` §5–§11

### 2.1 Typography — SF Pro Rounded → **Nunito** *(§7.1)*

SF Pro Rounded is not in Penpot's font set and cannot be uploaded over MCP. Every UI chrome
style uses **Nunito** — closest open rounded-terminal equivalent, full 200–900 weight range.
Bold → 700, Semibold → 600, Regular → 400. Sizes and line heights match §7.1 exactly, so
swapping back is a one-pass change.

The five **journal faces are all real** and all render correctly (§7.2).

### 2.2 Iconography — SF Symbols → drawn vectors *(§9)*

Penpot has no SF Symbols support. All 25 symbols are drawn as 24 × 24 vector paths on the
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

  This is why the ink in frames 25 and 36 sits exactly on the guide letters beneath it, and
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
- **Frame 17** — the three-tracing comparison strip (61% → 79% → 94%) is mine, not the spec's.
  Stepping a pager one attempt at a time hid the improvement; showing them together is the
  argument for keeping attempt history.
- **Frame 39** — the "Milo has been above 90% for two weeks — Small might be ready to try"
  line. It is the only thing in v2 that replaces level progression, and it is addressed to a
  grown-up, not the child.
- **Frame 34** — a second plain-language note saying destructive actions are not gated (§5).
- **Frames 29 / 30** — the score breakdown line, so §14's 183 and 224 are checkable.
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
- A **resume card** that takes the primary slot on Journal Home (frame 9 variant), and a
  "Still to write" section at the top of the journal list.
- No warning language anywhere. Stopping is not an abandon.

**Frame 42 changed meaning.** It was "you hit the 200-character cap"; it is now "you talked
for five minutes". The copy stays warm — *"That's a whole lot of story!"* — and it states
the workload honestly: *"14 sentences · about 20 minutes of writing."*

**Drafts stopped existing as a thing.** An unfinished session *is* the draft, so
`Row / Draft` became `Row / Unfinished` with a progress bar, and the `Draft` model is
deleted from the design document.

**Audio storage changed shape.** Recording a whole session rather than a sentence means a
5-minute master at ~1.2 MB; daily for five years is over 2 GB. The design now slices the
master into per-sentence clips using the recogniser's segment timestamps and discards the
master — ~250 MB over the same period, and it is what "Hear it" needs anyway.

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

**Voice playback** appears as "Hear it" on each sentence row in frames 14, 15 and 18.

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
5. **Scroll affordances are static.** The writing-so-far panel shows a scrollbar; the fade
   at the clipped edge that a real implementation wants is not drawn.
6. **The Components page has not been re-laid-out for portrait**, and it has not been
   updated for v2.1 — it still shows `Pager / Attempt` and the old sentence row. The
   components used in the frames are current; the catalogue page lags.
7. **Penpot's export service is unreliable** and got worse across these revisions. All 43
   boards are verified structurally (size, no overflow, content density); roughly a third
   have been rendered and looked at. The rest are verified by inspection.
8. **The review screen (frame 22) asks a five-year-old to do editorial work.** Edit, split
   and join are all there, but a child will tap "Start writing" and ignore them. That is
   the right default — every row is already good enough to trace — but the screen is
   really a grown-up surface wearing child clothes. Worth watching in testing.

---

## 7. Penpot API Notes For Whoever Scripts This File Next

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
