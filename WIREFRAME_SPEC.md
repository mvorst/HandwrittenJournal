# Handwritten Journal — Wireframe Specification

## Penpot handoff, v3.3

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

**What changed in v2.7 — three screens removed:**

- **Avatar Capture is gone** (frame 7). Photos come from the system photo picker
  (`photo.on.rectangle`), not a custom camera screen. The Profile Editor shows *Choose
  Photo*, plus a destructive *Remove* once a photo exists.
- **The Journal List is gone** (frame 11). Journal Home lists every entry itself under a
  "My Journal" section; there is no "See all" and no separate list screen. Search stays in
  Journal Home's toolbar (frame 12 is now a state of Journal Home).
- **The Journal Calendar is gone** (frame 13), and with it the `Cell / Calendar` component.

**What changed in v2.8 — the style-guide palette** (see `STYLE_GUIDE.md` for every
decision and rejected proposal):

- **Warm paper.** `paper` and `paper-sunk` shift from near-neutral to lined-paper cream
  (`#FAF5E8` / `#F1E8D3`). `paper-raised` stays white.
- **`danger` is crayon red `#D64541`, `success` is meadow green `#43A047`, `star-on` is
  tangerine `#F28522`.** The accuracy inks (`ink-inside`, `ink-outside` and the
  colorblind pair) deliberately do **not** follow — they are a teaching channel, and
  §5.2 keeps their original values, so `success`/`danger` no longer share hexes with them.
- **Cut-paper shadows** (§8): hard bottom-edge offsets, zero blur. `Button / Primary`
  gains `shadow-card`.
- **Three decorative accents reserved** (§5.6) for the future sticker/doodle pass.
- **Explicitly rejected:** yellow primary buttons (`action` stays blue), colored or
  restructured writing rules (the dashed-outer/solid-baseline gray rules are the spec),
  a red margin rule, and any tracing-typeface change.

**What changed in v3.3 — landscape (page `06 · Landscape`):**

- **Both orientations, full screen only.** The portrait-only decision of v2.0 (§3) is
  reversed on one condition: **the page keeps its portrait width.** Ink is stored at the
  width it was written at and drawn over the guide letters, so a page never re-wraps — in
  landscape the writing page, the reading page and the practice sheet stay 834 wide (on an
  11-inch iPad) and 762 tall, and the other 360 pt is a **rail** (§11.1).
- **The rail** holds what the portrait footer held — the mic, the readout, the progress,
  the scroll chevron and *I'm finished* — on the side of the free hand: left for a
  right-handed child, right when *Left-handed layout* is on, or pinned by the new
  **Controls in landscape** setting (§13.6).
- **Journal Home** is two columns in landscape — the dashboard at 560 on the left, the
  journal on the right — and in **both** orientations only the entries scroll: the header,
  the deck, the points card, the badges, the journal header and the search field stay put
  (§13.2, §13.6).
- **Entry Detail, Results, the Profile Picker and Practice** re-flow (§13.6); the sheets —
  Progress, Settings, the pickers, Export — keep their portrait layout, centred by the
  system.
- **Not Split View.** The app declares `UIRequiresFullScreen`: a Slide Over or Split View
  window is narrower than the page.

**What changed in v3.2 — the Write flow from page `14 · Write`:**

- **Badges open a card.** Every tile on the Journal Home strip is a button; a tap opens
  `Sheet / Badge` (§10.8) — frame 54, over frame 9.

Explored on the Penpot page `14 · Write` and adopted by the app on 2026-09-02. Frames 20,
21, 22, 24, 25, 29, 30 and 44 were rebuilt from that exploration and frames 52 (doodling)
and 53 (adding words) added; the frames now live on `04 · Write` and the exploration page
is gone (`PENPOT_HANDOFF.md` §1.-1).

- **One microphone.** `Mic / Stage` — 176 pt, low on the empty page — starts the take and
  becomes the stop in the same spot (`danger`, a stop square, a pulse ring). The footer
  mic is gone from the empty page and *I'm done talking* is gone everywhere; the
  `Listening bar` is the level meter and the clock. Once the page has words the mic
  docks into the footer as `Mic / Footer`, and a take started there stops there (§10.6,
  §11.13).
- **The take ending is a change of turn.** The first unwritten row is selected on its own
  and `Callout / Your turn` takes the stage the mic left (§11.11, §11.13).
- **A resting hand selects nothing.** Wide touches are dropped; finger taps on the words
  do nothing; every row carries a `Row handle` in the margin gutter — an 8 pt dot, or the
  `pencil.line` marker on the row in hand — and a finger picks a row only by it (§11.6,
  §11.11). Fixing a word is the toolbar's **ABC** tool, not a tap or a hold; the same
  tool adds words to the end of the page (§11.13).
- **Navigation.** The Write toolbar reads Back · date · crayon · ABC · eraser · undo ·
  clear · ⋯; the `Segmented / View · Edit` control is gone from the entry page. The
  footer's *Done* becomes *I'm finished*, the one finish control; Back scores the page as
  it stands and leaves. Results end with one button, *Back to my journal* (§13.3).
- **Crayons.** A crayon tool (`scribble.variable`) draws doodles in the three §5.6 accents
  into their own layer under the ink — multiply at 85% — never scored, kept in the
  journal, the thumbnail and every PDF; `Crayon swatches` sit in the footer while it is
  in hand (§10.6).
- `scribble.variable`, `textformat.abc`, `pencil.line` and `stop.fill` join the icon set
  (§9).

**What changed in v3.1 — the action deck and points:**

Explored on the Penpot page `13 · Journal`, adopted by the app on 2026-09-02 and
rebuilt onto `03 · Journal` and `04 · Write`; the exploration page is gone.

- **Journal Home has no navigation bar.** The export button is gone from this screen —
  the whole journal is exported from an entry's ⋯ → *Share as PDF* → *Everything* — and
  the search field moved down to sit directly above the entries it filters (§13.2).
- **New Entry and Practice my letters are an action deck**: two `Button / Tile`s on the
  content grid, the primary and its outlined partner, each with a chip saying what it
  earns (§10.1). The centred button and the text link beneath it are retired.
- **Points are tracked on the home screen.** `Card / Points` shows the running total,
  today's gain and `Tracker / last 7 days`; every `Row / Session` shows "+N points" under
  its stars; the Badges header reads "3 of 8" (§10.5, §10.6).
- **Practice letters earn points** — +2 when a letter flips green in the arrow order, +1
  otherwise, each letter once a day; never streaks or badges (`DESIGN_DOCUMENT.md` §8.3).
  Frame 49 carries a "+18 today" pill and a "+2 points" footer state.
- `sparkles` joins the icon set (§9).

**What changed in v3.0 — reconciled with the built app:**

This revision was written *from* the code rather than ahead of it. Where the Penpot file
and `HandwrittenJournal/` disagreed, the app won and the wireframes were changed to match.

- **Three screens the app has and the wireframes did not.** `Practice Letters` (frame 49),
  the letter-formation help modal (frame 50) and the photo-framing step (frame 51).
- **The entry page carries a `View` / `Edit` switch** in its toolbar, and Write's toolbar
  carries the `⋯` entry menu. Reading and writing are one screen in two modes (§13.4).
- **Journal Home lost the "Your writing" card**, gained *Practice my letters* under
  New Entry, gained the search field and export button in its navigation bar, and now
  lists entries as `Row / Session` with **badges above the journal, not below**.
- **The resume board is gone.** There is no "you were writing" card anywhere in the app.
- **`Left-handed layout` and `Sound` are stored but inert** — nothing reads them. Frame 48
  is marked NOT BUILT rather than describing a layout the app never produces.
- **Copy corrected throughout** to the exact strings in the code — Results, the writing
  footer hints, Journal Home's empty state, Entry Detail's stats, the overflow menu, the
  permission screens and both Settings screens.
- **`Varela Round` replaces `Baloo 2`** in the curated face list (§7.2).
- **The badge set is the app's eight** (§10.7), and the icon sheet is exactly the symbols
  the app asks for (§9).
- **Retired components deleted from the library**, not just annotated: `Card / Session`,
  `Row / Draft`, `Pager / Attempt`, `Cell / Calendar`, `Writing so far`,
  `Toggle / TypedHandwritten` and `Sheet / Parent gate`.

**What changed in v2.9 — the journal reads only as handwriting:**

- **The typed reading of an entry is gone.** Entry Detail always shows the child's own
  strokes over the faint guide; there is nothing to flip to. Frame 14 is retired, frame
  15 is simply "Entry Detail", and the page surface grows into the toggle's space
  (§13.4).
- **`Toggle / TypedHandwritten` is retired** (§10.6), and with it the §4 page-flip
  motion and `Motion.pageFlip` in `AppConstants.swift`.
- Typing is still how a keyboard entry gets *onto* the page (frame 41's fallback), and
  the export's "include the typed words" option is untouched — this change is about
  reading, not writing.

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
| `02 · Profiles` | Frames 1–6, 51 |
| `03 · Journal` | Frames 9, 10, 12, 15, 18, 19, 43, 54 |
| `04 · Write` | Frames 20–22, 24–27, 29, 30, 40–50, 52, 53 |
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
| 7 | Avatar Capture — live camera | The system photo picker replaced the camera (v2.7) |
| 11 | Journal List | Journal Home lists every entry itself (v2.7) |
| 13 | Journal Calendar | Removed (v2.7) |
| 14 | Entry Detail — Typed | The journal reads only as handwriting (v2.9) |

---

## 3. Artboards and Orientation

**Portrait is the primary orientation; landscape is supported (v3.3).** v1 designed
landscape first, on the argument that a wider writing line is better for a child; v2
reversed that, because the writing screen is a vertical composition and a child holding an
iPad to write holds it like a notebook. v3.3 adds landscape back on one condition: **the
page keeps its portrait width.** Ink is stored at the width it was written at and drawn
over the guide letters, so a page must never re-wrap. In landscape the page stays the width
the device has in portrait — the shorter side of the screen — and the rest of the width
becomes a rail beside it (§11.1, §13.6). Every frame is designed portrait; page
`06 · Landscape` holds one landscape frame per screen family.

| | Size (pt) | Use |
|---|---|---|
| **Primary artboard** | **834 × 1194** | iPad Pro 11" portrait. Design every frame at this size. |
| **Landscape artboard** | **1194 × 834** | iPad Pro 11" landscape (page `06 · Landscape`). The page column is 834 wide; the rail 360. |
| Narrow check | 744 × 1133 | iPad mini portrait. Do not draw; verify the primary layout does not break. Landscape: page 744, rail 389. |
| Wide check | 1032 × 1376 | iPad Pro 13" portrait. Do not draw; verify. Landscape: page 1032, rail 344. |

**Full screen only.** The app declares `UIRequiresFullScreen`, so there is no Split View or
Slide Over window narrower than the page.

Design in **points, at 1×**. Penpot pixels map 1:1 to iOS points. Export at 2× and 3× only
for image assets, never for layout reference.

**Safe areas.** Reserve 24 pt at the bottom for the home indicator and 0 pt at the sides.
Nothing tappable may enter that band — i.e. nothing below **y 1170** in portrait, **y 810**
in landscape.

---

## 4. Interaction Constants

| Constant | Value | Note |
|---|---|---|
| Minimum tap target | 44 × 44 | Apple HIG floor. Child-facing primary actions are much larger. |
| Child primary action | ≥ 280 × 64 | Deliberately oversized; a six-year-old is the user. |
| Standard transition | 0.30 s ease-in-out | |
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
| `paper` | `#FAF5E8` | App background, the writing surface. Lined-paper cream (v2.8, `STYLE_GUIDE.md` §1.1) |
| `paper-sunk` | `#F1E8D3` | Card wells, keypad keys, inset panels. A warm step down from `paper` (v2.8) |
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
| `practice-path` | `#AF52DE` | The stroke-order path on the practice sheet and in the formation-help modal (frames 49, 50). Purple is the one hue with no other meaning in the app |

### 5.3 Guide layer

| Token | Hex | Use |
|---|---|---|
| `guide-text` | `#000000` @ 80% | The letters being traced — **only the line in hand** (§11.11) |
| `spoken-text` | `#5B6B8C` @ 42% | Dictated words waiting to be written. Deliberately cooler as well as lighter than `guide-text`, so "not yet real" reads at a glance and survives a squint |
| `guide-faint` | `guide-text` × 0.18 (≈ `#000000` @ 14%) | The letterforms left under a traced row's ink — legible enough to read, faint enough that the ink is unmistakably the text now (v2.6). **Not a standalone token in `AppConstants.swift`**: the canvas draws `guide-text` at `TracingCanvas.tracedGuideAlpha`, and the settle animation interpolates to it |
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
| `star-on` | `#F28522` | Earned star. Tangerine (v2.8) — no longer shares a hue family with `streak-flame`. Also a practice letter that earned one point today (v3.1) |
| `star-off` | `#D1D1D6` | Unearned star, unearned badge |
| `streak-flame` | `#FF9500` | Flame glyph and streak count |
| `success` | `#43A047` | Positive deltas on Progress. Meadow green (v2.8) — deliberately no longer the same hex as `ink-inside`, which keeps its own value. Also a practice letter that earned both points today (v3.1) |
| `danger` | `#D64541` | Delete, reset, negative deltas. Crayon red (v2.8) — deliberately no longer the same hex as `ink-outside`, which keeps its own value |
| `divider` | `#E5E5EA` | Hairline separators |

### 5.6 Decorative accents *(v2.8 — reserved, no UI role yet)*

From `STYLE_GUIDE.md` §1.2: these exist for the sticker/doodle asset pass (crayon stars,
badges, corner stickers). They must never carry meaning — no button fills, no states, and
never anywhere the accuracy inks appear.

| Token | Hex | Use |
|---|---|---|
| `pencil-yellow` | `#F6C33E` | Highlight/decorative accent only — never a primary button fill (`action` stays blue) |
| `eraser-pink` | `#E35882` | Playful highlights, badges, stickers — **not** destructive actions (`danger` owns those) |
| `lilac-star` | `#8E75C8` | Corner stickers, playful accents. Must stay visually distinct from `practice-path` purple |

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
| `varela` | Varela Round | 400 | Very open letters, evenly rounded. |
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
| `shadow-card` | 3 y, 0 blur, `#000000` @ 8% |
| `shadow-raised` | 4 y, 0 blur, `#000000` @ 12% |
| `shadow-modal` | 6 y, 0 blur, `#000000` @ 18% |

Shadows are **cut-paper** as of v2.8 (`STYLE_GUIDE.md` §3.2): a hard bottom-edge offset
with zero blur, so raised surfaces read as physical paper sitting on the page rather than
objects floating in space. `Button / Primary` carries `shadow-card`; outline and text
buttons carry none.
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
`ellipsis.circle`, `photo.on.rectangle`, `lock.fill`, `flame.fill`,
`star.fill`, `star`, `pencil.line`, `person.crop.circle.badge.plus`, `xmark`,
`arrow.triangle.2.circlepath`, `plus`, `eraser.fill`, `speaker.wave.2.fill`, `sparkles`, `checkmark.circle.fill`, `circle.dashed`.

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
| `Button / Tile` (v3.1) | h 128; primary 486 wide, secondary 284 | primary `action` + `shadow-card`; secondary `paper-raised`, 2 pt `action` stroke, flat | icon 40 / 36 leading; `button` / `headline` title, `body` subtitle @ 85%, `caption` semibold chip in a capsule — white @ 20% on the primary (top-trailing), `action` @ 10% on the secondary | 20 |

Primary button icon, when present, is 28 pt, leading, 12 pt from the label.

**The Write toolbar's tools** (v3.2), `Button / Toolbar` at a 52 pt pitch ending with
`ellipsis.circle` at x 766: `pencil` (write — the default), `scribble.variable` (crayon),
`textformat.abc` (ABC), `eraser.fill`, `arrow.uturn.backward`, `trash`. Pencil, crayon and
ABC are the three things the pen can be; the one in hand fills `action` at a 12 pt radius
with a `text-on-action` glyph, so the way back to writing is always in view. A tool with
nothing to act on draws in `action-disabled`.

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
| `Segmented` | h 44 (h 48 in a toolbar), `radius-pill`, `paper-sunk` track, selected segment `paper-raised` inset 3–4 pt with `shadow-card`. One use: the export scope (This entry / This month / Everything). **`Segmented / View · Edit` is retired** (v3.2) — the entry page has no mode switch; Back is the way out of both modes. There is **no** Trace/Copy switch — Copy is not built — and **no** date-range filter on Progress. |
| `Tracker / last 7 days` (v3.1) | "Last 7 days" `caption` over seven 24 pt bars at a 12 pt gap, 38 pt tall at the week's best day, `radius` 4: today `action`, other days `action-disabled`, a 4 pt `paper-sunk` stub for a day with nothing; weekday initials `caption-sm` beneath, today's bold in `text-primary`. Lives in `Card / Points`. |

`Bar / Level` and `Pager / Attempt` are both **retired** — there is no ladder and no
attempt history.

### 10.6 Journal and writing surfaces

| Component | Spec |
|---|---|
| `Row / Session` (**the main screen's journal list**) | h 132, full content width, `paper-raised`, `radius-card`, `shadow-card`, 16 pt padding. Thumbnail 160 × 100 `radius-chip` leading; then date + time `body-em`, the opening words of the entry in `body` truncated to one line, metadata `caption` in `text-secondary` reading *"N words · NN% · Font Size"* — the entry's per-letter accuracy over the words the child actually started; `Stars / Row` trailing with *"+N points"* `caption` semibold in `success` centred beneath it (v3.1). |
| `Card / Points` (Journal Home, v3.1) | Full content width × 128, `paper-raised`, `radius-card`, `shadow-card`, 24 pt padding. `sparkles` 32 pt in `star-on` (`star-off` at zero); the running total `numeral-l` with "points" `body` in `text-secondary` on its baseline; beneath, "+224 today" `body-em` in `success` — or "Your first entry starts the count." / "Nothing yet today" `body` in `text-secondary`; `Tracker / last 7 days`; `chevron.right` 20 pt trailing. The whole card opens Progress. |
| `Card / Entry stats` (entry detail) | Full content width × 112, `paper-sunk`, `radius-card`. Accuracy `numeral-l` with "accuracy" `caption` beneath at 28 pt in; `Stars / Row`; then a three-line stack — word count `body-em` ("48 of 48 words"), a one-line note `caption` ("You finished the whole thing." / "N words are still waiting on the page."), and the setup summary `caption` ("Jua · Large · Trace") — **One row per entry** — `Row / Sentence` is retired, and with it the per-sentence playback; *"Hear what I said"* is retired too (v3.0 — no audio is kept). The setup summary lives **inside** the card, not below it. |
| `Writing progress` | Full width of the footer. `paper-sunk` capsule track 8 pt tall, `action` fill to `wordsWritten / totalWords`, caption "15 of 48 words" beneath in `text-secondary`. Replaces the sentence queue. In the footer it is 190 pt wide, not full width — the accuracy hint sits to its left. |
| `Level meter` | 420 × 40 (280 wide in the listening bar). 5 pt bars, 5 pt gaps, `action`, with the tail in `star-off`. Purely decorative in the wireframe; a real implementation reads the input level. |
| `Mic / Stage` (v3.2) | The one mic while the page is empty: 176 pt circle, `action` fill, `shadow-raised`, `mic.fill` 76 pt, centred at (417, 788) — low on the page, near the child's hands — with "Tap to start talking" `body-em` beneath and *Type it instead* under that. **Listening**, in the same spot: `danger` fill, a 56 pt `text-on-action` stop square (radius 12), a `danger` pulse ring, "Tap when you're done talking" beneath. The page keeps its last line above the stage while it listens. When the take ends the button docks into the footer as `Mic / Footer`. |
| `Mic / Footer` | 64 pt circle, `action` fill, `mic.fill` 28 pt in `text-on-action` — present only once the page has words (v3.2: one mic, never two). Muted state (listening finished at the cap): `paper-sunk` fill, `text-secondary` glyph. A take started here stops here: `danger` fill and a 22 pt stop square while it listens. |
| `Listening bar` | Replaces the footer while recording (v3.2): the stop in the mic's spot **only when the take started from the footer**, then `Level meter` 280 wide, elapsed `numeral-l` over "of 5:00" `caption`, and the reassurance line trailing. No primary button — a take started on the stage stops on the stage. |
| `Row handle` (v3.2) | In the 40 pt margin gutter of every row with letters, centred in the gutter at the row's x-height: an 8 pt dot, black @ 15%; on the row in hand the `pencil.line` glyph, 22 pt, `action`. The one place a finger selects a row. Left-handed profiles carry it in the right-hand gutter. |
| `Callout / Your turn` (v3.2) | 660 × 116 `paper-raised`, `radius-card`, `shadow-modal`, bottom-aligned over the page where the stage was: a 64 pt `pencil-yellow` well with `pencil.line` 28 pt in `text-primary`, "Your turn — write it!" `headline`, one `body` line in `text-secondary`. Shown once, when the first telling lands on a page with no ink; gone at the first stroke or a tap. |
| `Crayon swatches` (v3.2) | Where the readout sits while the crayon is in hand: three 40 pt circles at a 52 pt pitch in `pencil-yellow`, `eraser-pink`, `lilac-star`, the one in hand ringed `stroke-selected` in `action`; "Doodles never count — tap the pencil to write again" `caption` beneath. |
| ~~`End-of-line check`~~ | **Retired in v2.6** — finishing is automatic (the row fills) and selection is free (any row, any tap). Do not reuse. |
| `Word being fixed` | A spoken word under edit: rounded rect at `radius-chip`, `action` stroke 2 pt over a 10% `action` tint, caret trailing, keyboard up (frame 22). Reached with the **ABC** tool in hand (v3.2): a tap picks the word, a drag a run. |
| `Word editor footer` | Replaces the footer while the ABC tool is in hand (v3.2). **Fixing** (frame 22): "Fix the word:" / "Fix these words:" `body` in `text-secondary`, a `paper-sunk` field at `radius-button`, `Button / Primary` "✓ Fix it", `Button / Secondary` "🎤 Say it again", `Button / Text` "Never mind". **Adding** (frame 53, when nothing is picked or the tap landed past the last word): "Add to the page:", an empty field with the placeholder "Type more words", `Button / Primary` "✓ Add them", the caption "…or tap a word above to fix it", and "Never mind". The tool puts itself down when the change lands. |
| `Thumbnail` | Aspect 5:3, `paper` fill, 1 pt `divider` stroke, handwriting in `ink-natural` at ~10% of the thumbnail width per em, doodles beneath it in their crayons (v3.2). **Never accuracy colours.** |
| ~~`Toggle / TypedHandwritten`~~ | **Retired in v2.9** — the journal reads only as handwriting; there is no typed page to flip to. Deleted from the library in v3.0. Do not confuse it with `Segmented / View · Edit`, which switches *modes*, not renderings. |
| ~~`Cell / Calendar`~~ | **Retired in v2.7** — the calendar screen is gone. Deleted from the library in v3.0. Do not reuse. |
| ~~`Card / Session`~~ | **Retired in v3.0** — Journal Home lists entries as `Row / Session`, never as a card grid. Deleted from the library. |
| ~~`Row / Draft`~~ | **Retired in v2.2** — an unfinished session *is* the draft, and it appears as an ordinary `Row / Session`. Deleted from the library in v3.0. |
| ~~`Writing so far`~~ | **Retired in v2.4** — finished lines stay where they were written. Deleted from the library in v3.0. |
| `Font option` | Full content width × 176, `radius-card`. Selected: `paper-raised`, `shadow-card`, 3 pt `action` stroke, `checkmark` 24 pt trailing. Unselected: `paper-sunk`. Name `headline`, reason `caption`, then a live preview of the sample line at 46 / 60 on one ruled line. |
| `Size option` | Full content width, height = size × 1.5 + 56. Same selected treatment. Label `body-em`, "NN pt" `caption` trailing, then a live preview at the real size. |

### 10.7 Badges

`Badge / Tile`: 88 circle + label below. Earned — `paper-raised` fill, `shadow-card`, icon
40 pt in `star-on`, label `caption` in `text-primary`. Unearned — `paper-sunk` fill, no
shadow, icon 40 pt in `star-off`, label `caption` in `text-secondary`. Label wraps to two
lines maximum, centred, 88 pt wide. The home strip uses 64 pt tiles with **no labels**. Every tile is a button: a tap opens
`Sheet / Badge` (v3.2).

Badges no longer reference levels. `DESIGN_DOCUMENT.md` §8 owns the list; `BadgeEngine.swift`
is the authority, and the library must carry exactly its eight, in its order:

| Badge | Symbol |
|---|---|
| First Entry | `pencil.line` |
| Sharp Shooter | `star.fill` |
| 5-Day Streak | `flame.fill` |
| Ten Entries | `calendar` |
| Perfect Week | `star.circle` |
| 1,000 Words | `checkmark.seal` |
| Every Font | `textformat` |
| Neat Writer | `hand.thumbsup` |

### 10.8 Chrome

| Component | Spec |
|---|---|
| `Toolbar` | h 72, `paper` fill, 1 pt `divider` bottom edge. **Journal Home has none** (v3.1). Leading back button (a plain text button — no chevron on the entry page), centred title, trailing actions. The **entry page** toolbar (view, edit and every Write state) reads (v3.2): leading "Back" at x 24, the date box 300 wide at x 130, then the mode's tools at a 52 pt pitch ending with `ellipsis.circle` at x 766 — in Edit, `pencil` 454, `crayon` 506, `textformat.abc` 558, `eraser.fill` 610, `arrow.uturn.backward` 662, `trash` 714; in View, `ellipsis.circle` alone. The one in hand of pencil / crayon / ABC is filled. |
| `Sheet / Modal` | width to content, `radius-sheet`, `paper-raised`, `shadow-modal`, centred, on `overlay-scrim` |
| `Sheet / PIN pad` | 700 × 800 |
| `Sheet / Badge` (v3.2) | 480 wide, `radius-sheet`, `paper-raised`, `shadow-modal`, centred on `overlay-scrim`. `Badge / Tile` at 88 pt, 40 pt from the top; name `title-2` 24 pt below; then *Earned* (`checkmark.circle.fill` 15 pt, `success`) or *Not earned yet* (`circle.dashed`, `text-secondary`) in `caption`; one `body` line, centred, 32 pt side padding — what earned it, or what will; `Button / Primary` "Got it" 32 pt below and 32 pt from the bottom. `xmark` 20 pt in a 44 pt `paper-sunk` disc, 16 pt in from the top-trailing corner. Closes on the button, the ✕ or the scrim; springs in and out (§4). |
| `Menu / Overflow` | 320 wide, rows h 60, `radius` 16, `paper-raised`, `shadow-modal`, hairline between rows inset 20 pt. Four rows, in this order: *Write it all again*, *Share as PDF*, *Rename this entry*, then a divider and *Delete this entry* in `danger`. (*Hear what I said* was retired in v3.0.) |
| `Row / Setting` | h 64, full width, label `body` leading, control trailing, 1 pt `divider` bottom inset 16 pt leading |
| `Keyboard` | h 316, `paper-sunk`, 1 pt `divider` top edge. Four rows, key h 62, gap 10, row gap 12, keys `paper-raised` with `radius` 8 and `shadow-card`; modifier keys `star-off`. |
| `Search field` (v3.1) | Full content width × 44, `paper-sunk`, `radius-pill`, 16 pt padding: `magnifyingglass` 20 pt in `text-secondary`, "Search what you said" `body`, `xmark.circle.fill` in `star-off` trailing once there is a query. Sits under the My Journal header, above the rows. |
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
  │  Back      Wednesday, August 27    ✏ 🖍 ABC ◆ ↺ 🗑 ⋯    │  y 0
  ├──────────────────────────────────────────────────────────┤  y 72
  │ ┌──────────────────────────────────────────────────────┐ │
  │ │                                                      │ │
  │ │            THE PAGE   834 × 958   (scrolls)          │ │
  │ │                                                      │ │
  │ │   graded lines · the line in hand · untraced guide   │ │
  │ │                 text inset 40 either side            │ │
  │ │                                                      │ │
  │ └──────────────────────────────────────────────────────┘ │  y 1030
  │ 🎤 So far: 88%  [███░░░░] 16 of 48 words ⌄ [I'm finished] │
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

**Landscape (v3.3, 1194 × 834).** The page keeps every number above — text inset 40, text
width 754, page top y = 72 — and is 762 tall instead of 958; it stands beside a **rail**
that takes the width left over, on the side of the free hand.

| Value | Number |
|---|---|
| Page column | 834 wide, y 72 – 834; x = 360 with the rail on the left, x = 0 with it on the right |
| Rail | 360 wide (344 on a 13-inch iPad, 389 on a mini), 1 pt `divider` on its page-side edge, 24 pt padding all round |
| Rail contents, top to bottom | `Mic / Footer` with the readout and its hint beside it; `Writing progress` across the rail; at the foot the scroll chevron beside a compact *I'm finished* (16 pt side padding, stretched to the rail) |
| Rail side | *Auto* → away from the writing hand (left, or right with *Left-handed layout*); or *Left* / *Right* by the *Controls in landscape* setting (§13.6) |
| Word editor | Under the page column, above the keyboard; the rail keeps its footer |
| Listening | The stop where the mic was with the clock beside it, the level across the rail, the one line of reassurance beneath |
| Rotation | Never re-wraps the page or rebuilds the surface; the row in hand is scrolled back into view |

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
- Finger *taps* on the words do nothing (v3.2); a finger picks a row only by its handle
  (§11.11). Only drags scroll. **A direct touch wider than a fingertip is a resting hand**
  and is dropped before it can select, edit or draw — `TracingCanvasView.handRadius`,
  50 pt to start with, to be checked on a device.
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

**Any row can be selected at any time — with the pencil, or by its handle** (v3.2). A
pencil tap on a traced row, the row after next, the last row of the page: one tap. A pen
that starts moving on an unselected row selects it and begins the stroke in the same
gesture — writing somewhere *is* selecting it. A finger selects only by the `Row handle`
in the margin gutter (§10.6); a finger on the words does nothing, and a resting hand is
dropped outright (§11.6). Selecting a traced row brings its ink back up in accuracy
colours for fixing; leaving any row settles it (§11.10). Selecting a row also stops the
mic if it is listening.

**When a take ends, or typed words land, the first unwritten row is selected on its own**
(v3.2), and the first time that happens on a page with no ink `Callout / Your turn` says
so. The page never asks the child to find the start.

**Nothing needs a tap to move forward.** When the selected row's last letter gets ink, the
next untraced row is selected automatically. The taps are for going back, skipping ahead,
or fixing — the ordinary flow is speak, then write straight down the page.

**The record is derived, never declared.** What the journal, search, exports and every
word count read is the **unbroken run of fully-traced rows from the top of the page** —
recomputed from the ink itself. It grows as rows fill, runs through gaps only once they
are filled, and shrinks if a record row's ink is erased or cleared. A row traced out of
order is the child's work and is scored (§11.4), but the record — the story so far, in
order — waits for the rows before it.

**Untraced text is editable; traced text is not.** With the ABC tool in hand, tapping an
untraced word opens it for fixing in place (§11.13) — provided no traced row sits below
it, because an edit must never reflow a row out from under its ink. Ink is attributed only
to the selected row, so a stray wobble can never put ink on a word the child has not
reached — and a doodle is attributed to nothing at all (§11.13).

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

- **There is one mic** (v3.2). While the page is empty it is `Mic / Stage`, 176 pt and low
  on the page with the invitation above it (frame 20); tapped, it turns into the stop in
  the same spot (frame 21) — wherever the child tapped to start, they tap to stop. Once
  the page has words the same control lives in the footer as `Mic / Footer`, 64 pt,
  always available — tapping it mid-entry is how "saying more" works — and a take started
  there stops there.
- **Listening** streams the words onto the page in `spoken-text` as they are recognised,
  caret at the end, the last line kept above the stage (frame 21). The footer is the level
  meter and the clock, nothing to tap; the reassurance line — *"Nothing goes in your
  journal until you write it."* — sits under the stop.
- **The take ending** selects the first unwritten row on its own and, on a page with no
  ink yet, shows `Callout / Your turn` where the mic stood (frame 24). The mic docks into
  the footer.
- **Fixing a word** is the **ABC** tool (v3.2): switch it on and tap the word — a drag
  picks a run — and a 2 pt `action` box with a 10% tint sits over it while the keyboard is
  up and the `Word editor footer` edits it in place (frame 22). The line reflows within
  the untraced region; traced rows cannot move because edits cannot reach them. There is
  no tap-to-edit and no hold-to-edit — a resting hand can never raise the keyboard — and
  no bulk review step: the child fixes what they notice, when they notice it.
- **Adding words** is the same tool (frame 53): switched on with nothing picked, or tapped
  past the last word, the footer offers *Add to the page* and the typed words join the
  spoken tier on their own paragraph. The tool puts itself down when the change lands.
- **Doodling** is the crayon (frame 52): strokes go anywhere in one of the three §5.6
  crayons, into a layer under the handwriting drawn in multiply at 85%, and never count —
  not attributed, not scored, not in the record or the counts. Doodles stay with the page
  and appear in the journal, the thumbnail and every PDF. Undo, clear and the eraser act
  on the doodles while the crayon is in hand.
- **Typing instead** is the same path with no mic: *Type it instead* puts the caret at the
  end of the spoken text and the keyboard types onto the page.
- **The five-minute cap** is a banner over the top of the page (frame 42), not a screen.

What died to make this: the session-start screen, the recording screen with its separate
transcript panel, and the check-what-I-said screen. Each existed to show the child text
somewhere other than where they would write it. v3.2 retired the second mic, *I'm done
talking*, the `Segmented / View · Edit` control, the toolbar's *I'm finished* (the footer's
*Done* became it), and the results' *See my page* and *Say something new*.

---

## 12. Frame Inventory

42 frames, all portrait 834 × 1194 — plus 11 landscape frames at 1194 × 834 on page
`06 · Landscape` (v3.3), one per screen family, each numbered after the portrait frame it
mirrors (01, 09, 15, 20, 24, 25, 29, 31, 33, 48, 49).

### `02 · Profiles`

| # | Frame | Notes |
|---|---|---|
| 1 | Profile Picker — populated | 3 profiles + add tile; two lock badges; Ada has no photo; each shows its font · size |
| 2 | Profile Picker — first launch, empty | Add tile with empty-state copy |
| 3 | PIN Pad — entering | 2 of 4 dots filled |
| 4 | PIN Pad — wrong PIN | Danger dots mid-shake |
| 5 | Profile Editor — new, empty | Empty avatar; **Take Photo + Choose Photo**; name field with "1–20 characters"; a single *Use a 4-digit PIN* toggle, off; Font/Size/Mode rows (Mode has no chevron) |
| 6 | Profile Editor — existing, with photo | Populated; the photo carries its own destructive **✕ badge** (there is no "Remove" button) and "Tap the photo to move or zoom it"; PIN toggle on with a four-digit field; Delete Profile visible |
| 51 | Photo framing — move and zoom | `AvatarCropView`: black ground, square framing window with the circular mask drawn over it, "Drag to move · pinch to zoom", Cancel + "✓ Use Photo". Reached from both photo buttons and from tapping the avatar |

### `03 · Journal`

| # | Frame | Notes |
|---|---|---|
| 9 | Journal Home — populated | **The main screen** (v3.1): the profile header, the action deck (`Button / Tile` × 2), `Card / Points`, then **Badges**, then **My Journal** — the search field, then every entry newest first as `Row / Session` with its points under the stars. No navigation bar, no export button, no resume card, no "Your writing" card, no card grid. |
| 10 | Journal Home — empty | New profile, no sessions, no streak, 0 points ("Your first entry starts the count.", every tracker bar a stub), badges grey ("0 of 8"); "Your journal is empty" / "Tap New Entry and tell me about your day." under a `book.closed` glyph |
| 12 | Journal Home — search active | Query "grandma", "2 results", keyboard up. Search is a plain field under the My Journal header (v3.1), not `.searchable`. |
| 15 | Entry Detail | The **View** mode of the entry page: the child's own strokes in `ink-natural`, the v3.2 toolbar (Back · date · ⋯ — there is no mode switch), one `Card / Entry stats` beneath, then `Button / Primary` "Write on this page" + `Button / Secondary` "Share". No "How it went" heading, and no *Hear what I said* (v3.0). Frame 14 (Typed) is retired (v2.9). |
| 18 | Entry Detail — overflow menu open | Write it all again / Share as PDF / Rename this entry / — / Delete this entry |
| 19 | Export preview — one entry | Scope selector, one PDF page, "1 page · one per session, oldest first", the on-device line, both option toggles |
| 43 | Export preview — the whole journal | The book: 38 pages, fanned stack, options. No size estimate — the app does not compute one. Reached from an entry's ⋯ → *Share as PDF* → **Everything**. Journal Home's export button — and the defect where it opened `ExportView` with no session — went in v3.1; the entry menu is the only route |
| 54 | Journal Home — badge detail | `Sheet / Badge` over frame 9 for *5-Day Streak* (earned: "You wrote five days in a row."). The *not earned yet* state — *Ten Entries*, "Write ten entries." — is drawn beside it as a component state on `01 · Components` §10.8 (v3.2) |

### `04 · Write`

Every frame here is a **state of the same screen** (§11.13).

**v3.2:** every frame here carries the v3.2 chrome — Back · date · pencil · crayon · ABC ·
eraser · undo · clear · ⋯ in the toolbar, the row handles in the margin gutter, and *I'm
finished* as the one finish control in the footer.

| # | Frame | Notes |
|---|---|---|
| 20 | Write — the page, nothing said yet | Empty rules, one 176 pt mic low on the page, "Tap to start talking", "Type it instead"; no footer mic, *I'm finished* disabled |
| 21 | Write — the page, listening | Words land as `spoken-text` live; the mic has turned into the stop in its own place, and the footer is the level meter and the clock, with nothing to tap |
| 22 | Write — fixing a word | The **ABC** tool in hand, one spoken word boxed in `action`; the `Word editor footer` (§10.6) replaces the normal footer — *Fix it* · *Say it again* · *Never mind* — keyboard beneath it |
| 24 | Write — your turn to write | The take has just ended: the mic has docked in the footer, the first row is in hand (black letters, the pencil marker in the gutter) and `Callout / Your turn` stands where the mic was. *I'm finished* is disabled until there is ink |
| 25 | Write — the page, part written | 3 traced (faint + graphite), 1 in hand at 55%, spoken below; 16 of 48; handles down the gutter, the pencil marker on the row in hand |
| 26 | Write — the page at Extra Large | 96 pt; fewer words per line, a much taller page |
| 27 | Write — the page at Extra Small | 30 pt; the whole 48-word entry fits one window |
| 29 | Results — the whole entry written | "You wrote everything you said!" / "All 48 words, in your own hand"; 91%, +224 points, the finish message, the page preview, then the one button — **Back to my journal** — and the caption saying where saying more went |
| 30 | Results — stopped part way, new badge | "Great writing, Milo!" / "You wrote 32 words today"; 78%, +183 points, "16 words you said are still spoken…", the new badge, then **Back to my journal** |
| 40 | Write — microphone access | Child-legible explainer shown *before* the iOS prompt |
| 41 | Write — microphone unavailable | Denied or unsupported; typing onto the page is the whole fallback — there is **no "Open iPad Settings" button** on this screen |
| 42 | Write — recording stopped at five minutes | A banner over the page, said warmly; 112 words ≈ 20 minutes of writing |
| 44 | Write — a resting hand does nothing | A palm on the page: the wide touch is dropped, nothing is selected, and the row in hand does not change. A finger picks a row only by its handle; the pencil picks one by writing on it or tapping it |
| 45 | Write — more said, added to the page | Scrolled; 10 written lines above, new spoken text below, 48 of 58 words |
| 46 | Write — no guide lines | §16 variant: ruled lines off |
| 47 | Write — colourblind ink | §16 variant: `ink-inside-cb` / `ink-outside-cb` |
| 48 | Write — left-handed layout | §16 variant, built in v3.2: `isLeftHanded` mirrors the handle gutter to the right so a resting left hand never covers it. Nothing else moves — the toolbar, the footer and the writing are frame 25's |
| 49 | Practice Letters | The alphabet worksheet reached from Journal Home. Jua only, sized so the widest row fits; the toolbar carries the "+18 today" points pill leading and undo + clear trailing; the footer carries the prompt and, once there is ink, the accuracy — replaced by "+2 points" in `success` when the letter flips green (§8.3, v3.1). Letters that earned today stay in `success` (2 points) or `star-on` (1 point) — `ink-inside-cb` / `ink-outside-cb` in the colour-blind scheme — except the letter in hand, which keeps `guide-text`; the idle footer carries a `caption` legend. Nothing is saved or graded; only the points are kept |
| 52 | Write — doodling with the crayon | The crayon in hand: a sun, a heart and a flower in the three §5.6 accents, in their own layer under the handwriting at 85% multiply; the three swatches sit in the footer where the readout usually is, with "Doodles never count — tap the pencil to write again" |
| 53 | Write — adding words with the keyboard | The **ABC** tool with nothing picked: the *Add words* field in the footer, keyboard up. Typed words join the spoken tier on their own paragraph |
| 50 | Write — letter formation help | §8.1b: a word finished with letters in the wrong order. A modal over the whole screen, chrome included — the word with its wrong letters in `ink-outside`, then a carousel of up to three lesson tiles, the live one bordered in `action`. Only tracing every red letter correctly closes it |

Frames 23, 28 and 36 are **retired**: 23 was the splitter, 28 the ink-only reveal (the page
now reveals a line at a time, in place, §11.10) and 36 the append screen, which frames 25
and 45 cover between them. Frames 20, 21, 22 and 42 keep their numbers but are **no longer
screens** — they are states of the page (v2.5).

**§16 variants** are frames 46, 47 and 48, built as states of frame 25.

### `05 · Progress & Settings`

| # | Frame | Notes |
|---|---|---|
| 31 | Progress — by mode and font | Chart with two setting-change markers (**no date-range switch and no x-axis labels** — the app hides that axis), per-setting table, the size nudge, then the stats card (Sessions written / Words written / Days journaled / Longest streak) |
| 32 | Progress — insufficient data | Fewer than 5 **entries** at one setting; empty state, plus the same copy-mode note under the table |
| 33 | Settings — profile | A single **"Name, photo and PIN"** row that opens the Profile Editor; Writing (font/size/mode + three toggles); the size nudge; Feedback; Danger zone with its caption; then *Switch to someone else* |
| 34 | Settings — app | iCloud row disabled, Version, **three** plain-language notes. No "What's new" or "Privacy" rows |
| 38 | Settings — font picker | Five curated faces (Jua, Andika, Varela Round, Sniglet, Comic Neue), live previews, selected state |
| 39 | Settings — font size picker | Five sizes, live previews. **The nudge is not here** — it belongs to Settings and Progress (§13.5) |

All six present as **sheets** with a trailing *Done*, not as pushed screens with a back
button — Progress, Settings and both pickers are `.sheet` presentations in the app.

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

Built as the v3.1 alternate, adopted by the app and rebuilt onto `03 · Journal`; frames 9,
10 and 12 there all carry this layout.

| Element | x | y | Size |
|---|---|---|---|
| `Avatar / M` (tap to switch user) | 24 | 40 | 56 |
| Switch-user badge, `arrow.triangle.2.circlepath` 14 pt | 64 | 80 | 22 |
| Name, `display` | 96 | 38 | — |
| Streak, flame 20 pt + `body` in `streak-flame` | 96 | 90 | — |
| Progress button, `Button / Toolbar` | 706 | 44 | 44 |
| Settings button, `Button / Toolbar` | 766 | 44 | 44 |
| `Button / Tile` "✎ New Entry" — primary, subtitle "Tell me about your day", chip "up to +230 points" top-trailing | 24 | 136 | 486 × 128 |
| `Button / Tile` "ABc Practice my letters" — outlined, chip "+2 points a letter" | 526 | 136 | 284 × 128 |
| `Card / Points` — `sparkles` 32 pt in `star-on`, total `numeral-l` + "points" `body`, "+224 today" `body-em` in `success`, `Tracker / last 7 days` at x 416, `chevron.right` 20 pt trailing; the card opens Progress | 24 | 280 | 786 × 128 |
| "Badges" `title-2` + rule, "3 of 8" `caption` in `text-secondary` trailing | 24 | 440 | — |
| Badge strip: 64 pt circles, 20 pt gaps, no labels, **left-aligned and horizontally scrollable** | 24 | 488 | 652 × 64 |
| "My Journal" `title-2` + rule | 24 | 600 | — |
| Search field — `paper-sunk` pill, `magnifyingglass` 20 pt + "Search what you said" | 24 | 648 | 786 × 44 |
| `Row / Session`, 16 pt gaps, newest first, "+N points" under the stars | 24 | 708, 856, 1004, 1152 | 786 × 132 |

There is **no navigation bar** (v3.1): the export button is gone from this screen — the
whole journal is exported from an entry's ⋯ → *Share as PDF* → *Everything* — and search
is a plain field above the list, not `.searchable`. There is **no** "Your writing" card
and **no** card grid. Badges come **before** the journal. When a search is active the
section header reads "N results" and the rows are the matches; when nothing matches, an
`Empty state` reading "Nothing found" / "Search looks at what you said, not how you wrote
it.".

### 13.3 Frame 25 — Write, the page part written *(the defining screen of v2.5)*

| Element | x | y | Size |
|---|---|---|---|
| `Toolbar` — "Back" leading, date centred, pencil + crayon + ABC + eraser + undo + clear + ⋯ trailing at 52 pt pitch (v3.2) | 0 | 0 | 834 × 72 |
| The page, `paper`, full bleed, scrolls | 0 | 72 | 834 × 958 |
| — traced rows, `ink-natural` over `guide-faint` letterforms | 40 | 112 | 754 wide |
| — the selected row, `guide-text` (black) with accuracy ink over it | 40 | — | 754 wide |
| — untraced rows, `spoken-text` only | 40 | — | 754 wide |
| Footer hairline, 1 pt `divider` | 0 | 1030 | 834 × 1 |
| `Mic / Footer` (§10.6) | 24 | 1060 | 64 × 64 |
| "So far: 88%" `body`, hint `caption` beneath, 218 pt wide | 108 | 1062 | 218 |
| `Writing progress` (§10.6) with "15 of 48 words" | 340 | 1074 | 166 |
| `Button / Toolbar` `chevron.down` — scrolls a line with no gesture | 530 | 1060 | 44 × 44 |
| `Row handle` on every row with letters — a dot, or `pencil.line` on the row in hand (v3.2) | 20 | — | 8 / 22 |
| `Button / Primary` "I'm finished ✓" (v3.2 — was "Done") | 590 | 1060 | 220 × 64 |

Frames 24, 26, 27 and 44–48 are the same layout with a different page state, size or
variant; only the page contents and the footer numbers change.

**Frame 20** (nothing said yet, v3.2) has no footer mic and disables *I'm finished*. The
invitation — "Tell me about your day, Milo" `title-1` and a two-line `body` caption — sits
above `Mic / Stage`, 176 pt centred at (417, 788), with "Tap to start talking" and "Type
it instead" beneath.

**Frame 21** (listening, v3.2) keeps the stage where it was and turns it into the stop;
the words land above it and the footer is the `Level meter` and the clock only.

**Frame 24** (the take just ended, v3.2) docks the mic in the footer, selects the first
row, and lays `Callout / Your turn` over the foot of the page where the stage was.

**Frame 22** (fixing a word) draws the `Word being fixed` treatment on the page, replaces
the footer with the `Word editor footer` (§10.6) at y 790–874, and puts the keyboard in the
bottom 320 pt.

**Frame 42** (the cap) lays a 660 × 116 `paper-raised` banner over the page at y = 100 —
muted mic well, "That's a whole lot of story!" `headline`, one `body` line beneath — and
mutes the footer mic.

**Frame 44** shows a traced row re-selected: row 2 back in black letterforms with its ink
in accuracy colours, the traced rows around it faint-grey under graphite. No band, no chip
— selection is its own affordance.

### 13.4 Frame 15 — Entry Detail

The entry always reads as the child's own handwriting (v2.9) — natural ink over the
faint guide, never a typed rendering and never accuracy colours. Frame 14 is retired.

**Reading and writing are one screen.** Frame 15 is that screen in **View** mode; every
frame on `04 · Write` is the same screen in **Edit** mode. Since v3.2 there is no mode
switch: *Write on this page* is how a finger moves into Edit, putting the pencil on the
page does it by itself, and **Back** — which scores the page as it stands — is the way
out of both.

| Element | x | y | Size |
|---|---|---|---|
| `Toolbar` — "Back" (plain text, no chevron) at x 24, the date at x 110, `ellipsis.circle` at x 758 | 0 | 0 | 834 × 72 |
| Page surface, `paper`, 1 pt `divider`, `radius-card`, scrolls | 24 | 96 | 786 × 748 |
| — the entry flows continuously, 32 pt inner padding, ruled; the page keeps ruling below the last word; scrollbar when it overflows | | | |
| `Card / Entry stats` (§10.6) — accuracy, stars, "48 of 48 words" and the setup summary as its third line. No *Hear what I said* (v3.0) | 24 | 858 | 786 × 112 |
| `Button / Primary` "✎ Write on this page" | 119 | 1070 | 340 × 64 |
| `Button / Secondary` "Share" | 475 | 1074 | 240 × 56 |

There is **no** "How it went" section heading: the stats card is unlabelled.

### 13.5 The size nudge — frames 33 and 31

The nudge is the only thing that replaces level progression. It appears in **Settings**
(under WRITING) and in **Progress** (under the table) — never in the size picker itself:

> *"Milo has been above 90% for two weeks — Small might be ready to try."*

Shown in `caption` / `action` when the current setting's rolling average has been ≥ 90% for
14 days and a smaller size exists. It is a suggestion to a grown-up, never an automatic
change and never a reward.

---

### 13.6 Landscape (v3.3) — page `06 · Landscape`

One rule, then its consequences. **The page keeps its portrait width** (§3, §11.1); the
rest of the screen is laid out around it.

| Screen | Landscape layout |
|---|---|
| Write (20, 24, 25, 48) | The page column, 834 wide, beside a 360 rail on the free-hand side (§11.1). The toolbar stretches: Back leading, the date centred, the tools trailing at 52 pt. |
| Practice (49) | The sheet keeps its portrait width so the letters keep their size; the prompt, the legend and the award stack in the rail. |
| Journal Home (09) | The dashboard column — header, the deck stacked, points, badges — at 560 on the left; the journal — its header with Progress and Settings trailing, the search field, the rows — on the right. In both orientations only the rows scroll. |
| Entry Detail (15) | The reading page at its width; the stats card and the two actions in the column beside it — on the rail's side, so the page stays put when the pencil lands and Edit takes over. |
| Results (29) | The score on the left, the page preview and its setup on the right, *Back to my journal* under both. |
| Profile Picker (01) | One row of four at the same 96 pt gaps. |
| Sheets (19, 31–34, 38, 39, 43) | The portrait layout, presented by the system as a page sheet over a scrim. Nothing reflows. |

**Controls in landscape** — a per-profile setting under WRITING (frame 33): *Auto* (the
rail sits away from the writing hand — left, or right with *Left-handed layout*), *Left*,
*Right*. It moves the rail on Write and Practice and the side column on Entry Detail;
nothing else mirrors.

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

**An unfinished entry** (frame 9 variant) — Mar 4, 5:30 PM, 32 of 48 words, next up
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
- [ ] An entry stopped part-way — a normal row reading "N words · not written yet"; opening it and putting the pencil on the page — or tapping *Write on this page* — carries on
- [ ] Recording stopped at the five-minute cap — banner over the page (frame 42)
- [ ] The page with nothing said yet — empty rules, one mic low on the page (frame 20)
- [ ] Listening — words landing on the page live, the stop in the mic's place (frame 21)
- [ ] The take just ended — first row in hand, the your-turn callout (frame 24)
- [ ] A spoken word being fixed with the ABC tool, keyboard up (frame 22)
- [ ] Words being added with the ABC tool (frame 53)
- [ ] A hand resting on the page — nothing selected (frame 44)
- [ ] Crayon in hand — doodles under the ink, swatches in the footer (frame 52)
- [ ] The page part written — traced above, one row selected, untraced below (frame 25)
- [ ] A traced row picked again by tapping its handle (frame 44)
- [ ] More dictation appended to an existing page (frame 45)
- [ ] An entry long enough to scroll both the writing page and Entry Detail (frames 25, 45, 15)
- [ ] Search with results (frame 12)
- [ ] Eraser selected, mid-correction (frame 25 variant)
- [ ] Microphone not yet granted (frame 40) and refused (frame 41)
- [ ] Whole-journal export (frame 43)
- [ ] Progress with fewer than 5 entries at one setting (frame 32)
- [ ] Guide lines toggled off (frame 46)
- [ ] Colourblind ink scheme (frame 47)
- [ ] Left-handed layout — the handle gutter mirrored to the right (frame 48). Nothing
      else moves. `soundEnabled` is still inert: the toggle exists, no sound is played.
- [ ] Letter practice — the alphabet worksheet (frame 49)
- [ ] A word finished with letters in the wrong order — the formation-help modal (frame 50)
- [ ] Framing a profile photo — move and zoom (frame 51)
- [ ] Camera refused after a photo was taken once — the "Camera is turned off" alert
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

*Document version: 3.0*
*Last updated: 2026-09-01*
*Companion to DESIGN_DOCUMENT.md v2.6*
*v3.0 was reconciled against the built app — where the two disagreed, the app won.*
