# Penpot Wireframes — Handoff Notes

Companion to `WIREFRAME_SPEC.md` v2.6. Answers §17.2: *"a list of anything you changed
from §5–§11."*

Penpot file: **`Wireframes`**. Rebuilt for v2.0, revised for v2.1–v2.6 on 2026-08-27.

---

## 1. What Is In The File

| Page | Contents | Boards |
|---|---|---|
| `00 · Foundations` | 23 color tokens, 17 type specimens, spacing/radii/stroke rulers, elevation samples, 25-icon sheet | 5 |
| `01 · Components` | §10.1–§10.8 | 8 |
| `02 · Profiles` | Frames 1–7 | 7 |
| `03 · Journal` | Frames 9–15, 18, 19, 43 + the unfinished-entry variant | 11 |
| `04 · Write` | Frames 20–22, 24–27, 29, 30, 40–42, 44–48 — every one a state of the single v2.5 screen | 17 |
| `05 · Progress & Settings` | Frames 31–34, 38, 39 | 6 |

**41 artboards, all portrait 834 × 1194** — every one verified for overflow and carrying a
PNG @2× export preset.

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
opening it and tapping **Edit** carries on. See `DESIGN_DOCUMENT.md` §0.6.

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
slice and *"Hear what I said"* sits on the entry.

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
