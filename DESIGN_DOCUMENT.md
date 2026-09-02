# Handwritten Journal

## Design Document v3.0

An iPad journal for a child who is learning to write. The child talks about their day, the
app transcribes it, and the words appear on a ruled page for them to write over. Each line
they finish stops being a guide and becomes their own handwriting, right where they wrote
it. Do that for a day and there is a page. Do it for a year and there is a journal in the
child's own hand.

Companion: `WIREFRAME_SPEC.md` v2.6 (measurements, tokens, frame inventory).
Build notes: `PENPOT_HANDOFF.md`.

---

## 0.10 What Changed in v3.0

**The ink is never lost, the judge grades a real pen, and the modal waits its turn.**

1. **The archive is written on every stroke** — and every undo, erase and clear — and
   the store is saved each time, not left to autosave (§6). Done adds the score; it no
   longer stands between the child and their work being kept.
2. **A surface only writes the ink it put back.** Finishing an entry, reading it and
   tapping *Write on this page* built a surface with no ink on it, which reported an
   empty record and wrote an empty archive over the child's page. The next surface is
   now always staged from the entry itself, and a surface that has not restored the
   entry's ink — or could not — can neither overwrite the archive nor shorten the
   record (§6).
3. **`HJST` v2 carries each point's letter** (§6.1), so a reopened page re-derives
   exactly the record it closed with instead of re-attributing ink against the mask.
   v1 archives still open.
4. **The page has one width for life** (§6.2). It lays out at the width its ink was
   first drawn at and scales to the window, so Stage Manager, Split View or a bigger
   iPad can never re-wrap the words out from under the strokes.
5. **The order judge tracks the pen along the taught path instead of snapping each
   sample to the nearest point of it** (§8.1a). Nearest-point reading flickered
   between parts of a letter that pass close to themselves — the bar of an *e* and
   the arc that comes back round to it, the tail of a *y* and the line drawn down over
   it, every stem and its bowl — and docked letters drawn exactly as taught: on a
   realistic pen, a correct *e* lost its 20% three times in four. Direction is now the
   net motion of a part's first visit, so a pen that runs up a stem to begin it from
   the top has not drawn it upwards; where a pen lands between parts, the part it goes
   on to move along is the one it meant. `FormationJudgeRealismTests` traces every
   character with a wobbling, mis-landing pen and requires no false docks — and still
   requires every backwards or out-of-order trace to be caught.
6. **The remediation modal waits until the child is done with the word** (§8.1b). A
   word reads as complete the moment its last letter has any ink, and the stem of a
   *t* arrives before its crossbar; the modal used to open over a letter the child was
   about to finish. It now waits until every letter of the word is fully covered, or
   until the pen lands on another word.
7. **"Hear what I said" is gone.** The microphone feeds the recogniser and nothing
   else; no audio is recorded or kept. `WritingSession.audioData` and
   `spokenDuration` remain in the schema, unread, so existing stores need no migration.

---

## 0.10 What Changed in v3.1

- **Journal Home is an action deck over a points card** (§4.3). New Entry and *Practice
  my letters* are two tiles side by side, each saying what it earns; beneath them the
  points card shows the total, today's gain and the last seven days, and every entry in
  the list shows its points. The navigation bar is gone — no export button on this
  screen, and search sits directly above the entries.
- **Practice letters earn points** (§4.11, §8.3): +2 when a letter flips green in the
  arrow order, +1 otherwise, each letter once a day; never streaks or badges.
- `UserProfile.practiceLedger` (§5.1) keeps one entry per letter per day.

## 0.9 What Changed in v2.9

**The remediation modal** — finishing a word with wrong-order letters now teaches the
letter on the spot (§8.1b).

1. The moment a word's last letter is inked and the pen lifts, if any of its letters
   took the order discount, a modal covers the page: the word at the top with those
   letters in red, and below it one of them — picked at random — taught with the
   practice sheet's own demo-then-trace loop.
2. **The only way out is through.** There is no close control. Tracing the letter
   correctly — taught order, taught directions, every stroke covered — reveals the
   button that closes it. A wrong attempt wipes the ink and replays the arrows; *Watch
   again* replays them on request.
3. **Success corrects that letter, and that letter only.** Its discount is lifted for
   the life of the entry (recorded on the session by character position, so reopening
   the entry keeps it); the word's other red letters keep theirs, and the modal does
   not return for them — one lesson per word.
4. A word prompts at most once per sitting, and only when finished under the child's
   own pen: pages restored from an archive never prompt for words already written.

---

## 0.8 What Changed in v2.8

**The order discount** — accuracy now measures *how* a letter was drawn, not only where
the ink landed (§8.1a).

1. A letter whose ink clearly took its parts out of the taught order, or drew a part
   against its taught direction, keeps **80% of its score**. The taught order is the one
   the practice sheet demonstrates (`LetterFormations.swift`): for an *a*, the circle
   first starting at the top, then the right-hand line, also from the top.
2. **Judged leniently, docked only when clear.** Pen lifts don't matter — an *a* drawn
   in one motion that still goes circle-then-line passes. Go-overs are ignored. Ink that
   barely lies along the formation is not judged at all; the inside/outside score
   already speaks for it.
3. **Jua only.** The formations are hand-fitted to Jua (§4.11), so the app only grades
   an order it has actually demonstrated. The other four faces score exactly as before,
   and Progress already compares per-setting.
4. The practice sheet's live % takes the same discount — the sheet teaches the rule the
   journal grades — and its footer says so when a traced letter ignored the arrows.
   Characters with no formation (punctuation) are never docked.

---

## 0.7 What Changed in v2.7

**The practice sheet** — a letter-formation worksheet (§4.11), reached from *Practice my
letters* on the main screen.

1. All 52 letters as Aa–Zz pairs plus the digits 0–9, on the same ruled paper as the
   journal, traced with the same green/red engine.
2. **Touch a letter and it shows you how it is written**: each stroke draws itself in
   order as a thin purple line with an arrowhead. When the demo ends the arrowheads
   leave and the thin lines stay, solid, as an inner guide — no numbers, no clutter;
   the animation itself carries the order.
   Then it is the child's turn — trace it, and enough good ink flips the cell green.
   Starting the next letter clears the last one.
3. **Pure sandbox.** Nothing is saved or scored: no entries, no stars, no streak, no
   badges. It exists to demonstrate how letters should be written.
4. **Jua only.** The 62 stroke-order formations are hand-fitted to Jua's letterforms
   (`LetterFormations.swift`); the other faces differ enough — bowls, hooks, tails —
   that one set of paths cannot be honest for all five.

---

## 0.6 What Changed in v2.6

The main screen is now **badges, then every entry, newest first** — and an entry is no
longer a task with a state.

1. **The resume card and every "Keep writing" are gone.** The home card, the "Still to
   write" section, and the mid-session Results button. Unfinished work is not a mode the
   app tracks and offers back; it is just a page with words still on it.
2. **The separate journal list screen is deleted.** The main screen carries the whole
   journal, so search and export moved to its toolbar. `JournalListView.swift` is removed.
3. **Tapping an entry opens it to read; Edit carries on writing it.** The Typed ↔
   Handwritten toggle stays exactly where it was — it is still the point of the app — and
   Edit is now the primary button beneath it rather than a secondary one.
4. **The "Your writing" settings card is gone** from the main screen. The gear reaches the
   same settings.
5. **The Handwritten reading now looks like the editor** — ruled paper and a faint guide
   under the ink, instead of strokes on blank white (§4.7).

What did *not* change is the model. `WritingSession.spokenBuffer` (said but not yet
written) versus `transcript` (the record) is load-bearing for the write flow — a child
dictates more than they write in one sitting by design, and §5.3 still holds. Only the UI
that framed the leftover as unfinished business was removed.

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

## 0.6 What Changed in v2.6

**Free row selection, and the pencil never scrolls.**

| Was (v2.5) | Now |
|---|---|
| A commit gesture: the end-of-line check, or tapping the next line — in order only | **Any row selects by tapping it, at any time**; the next untraced row comes up on its own when a row fills |
| Written lines lost their guide entirely | **Traced rows keep faint letterforms under the ink** — legible as text, unmistakably the child's |
| The record moved when the child said so | **The record is derived from the ink**: the unbroken run of fully-traced rows from the top |
| The pencil could pan the page (finger-tracing on) | **The pencil never scrolls** — pen touches are excluded from the scroll gesture outright |
| Fixing a traced line went through a chip | **Tap the row** — its ink comes back in accuracy colours and every tool works on it |

**Why it is better.** The check was one more thing to learn and one more thing drawn on
the page; free selection plus auto-advance gets the same flow with zero new UI — the
ordinary path is still speak, then write straight down the page, and the taps are only for
going back, skipping, or fixing. Excluding the pencil from the scroll gesture removes the
last way a pen stroke could be eaten by a pan. And the derived record closes a loophole:
nothing can ever *say* it is written — it either is inked or it is not.

**What it costs.** Finishing is a sensor again (the row fills), which v2.5 argued against —
but the agency the check protected now lives in free selection: the child can take any row
back at any moment, so no automatic transition is ever final.

## 0.5 What Changed in v2.5

**One screen, and nothing is in the journal until it is in their handwriting.**

| Was (v2.4) | Now |
|---|---|
| Four screens on the way to the pen: start, recording, check-what-I-said, then the page | **One screen.** The mic, the live transcript, the fixing and the writing are all the page |
| Dictation was reviewed in a text field, then committed wholesale as guide text | **Dictation lands on the page as *spoken* text** — pale, editable in place, and provisional |
| The whole transcript became the entry the moment the child tapped "Start writing" | **A line's words join the record only when the child finishes writing it** — by tapping the check at the end of the line, or tapping the next line to take it in hand |
| A line settled automatically when its last letter got ink | **Finishing a line is the child's own act.** The settle is the commit, so nothing commits by sensor |
| An unfinished entry was a half-written record | **The record is always fully written.** "Unfinished" means spoken words are still waiting — they are not in the journal, exports, or any count |

**Why it is better.** The old flow made a five-year-old cross three screens of adult
ceremony — record here, proofread there, write somewhere else — before touching the pen.
Now the words appear where they will be written, in the face they will be written in, and
the child's first act can be the one they came for. And the provisional tier fixes a
quiet dishonesty: v2.4 called the transcript "the entry" before a single letter was the
child's. Now the journal *is* the handwriting, by construction — a transcript the
recogniser got wrong simply never becomes the record, because the child fixes it or never
writes it.

**What it costs.** The page now carries a fourth interaction (edit) beside pen, scroll and
tap, and the renderer draws a third text tier. The check screen's one virtue — forcing a
look at the whole transcript — is given up in favour of fixing what you notice when you
notice it.

## 0.4 What Changed in v2.4

**The page is the whole screen, and finished writing stays where it was written.**

| Was (v2.3) | Now |
|---|---|
| A finished line shrank to half size and flew into a "writing so far" panel at the top | **It settles in place.** Its guide fades and its ink turns from red-and-green to graphite. Nothing moves. |
| Two surfaces: a read-only panel above, an active surface below | **One page**, edge to edge, from the toolbar to the footer |
| Re-tracing meant re-opening the entry from the journal | **Tap any finished line to write it again**, in the middle of writing |
| Saying more started a new page | **Saying more appends** to the page you are on |
| Results and Entry Detail listed the session's sentences | **One entry, one result** — one accuracy, one word count, one recording |

**Why it is better.** The v2 settle animation copied the child's work somewhere else to
prove it counted. Once the page scrolls, that is unnecessary and slightly dishonest: the
line is already in the right place, on the right paper, at the right size. Letting the
guide fall away underneath it is the same emotional beat with none of the machinery, and it
leaves the page above the child's hand reading as continuous handwriting.

It also makes re-tracing obvious. A line with no guide under it is a line you have written,
and tapping it to write it again needs no explaining.

**What it costs.** The writing surface now has a tap gesture as well as a pen and a scroll
(§4.4), and the renderer has to draw three line states instead of one.

## 0.3 What Changed in v2.3

**The transcript is no longer broken into sentences.** It is one continuous scrolling page.

| Was | Now |
|---|---|
| Split the transcript into sentence-sized pieces that each fit the surface | **One page.** The whole transcript is laid out and the child works down it, scrolling. |
| A review screen with edit / split / join per sentence | **One text field** showing everything, for fixing what the recogniser misheard |
| A "Sentence 3 of 8" queue and a writing-so-far panel | **A word-progress bar.** The page above is the child's own writing; there is nothing separate to show. |
| `Sentence` entity, one archive and audio clip per sentence | **The session holds it all** — one transcript, one stroke archive, one recording |

Deleted outright: `TranscriptSplitter` and its tests, the `Sentence` model, the review
list, the queue chip, the writing-so-far panel, and the per-sentence audio slicing.

**Why it is better.** Splitting made the child's own words feel like a set of exercises,
and it made the app carry a splitter, a fit rule, a review UI and a queue — a lot of
machinery whose only job was to undo the fact that a writing surface is smaller than a
story. Making the surface scroll removes the problem instead of managing it.

**What it costs.** A scrolling surface and a pen are in tension — see §4.4.

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
              ┌──── THE PAGE (one screen) ──────────┐
              │                                     │
              │  speak ─▶ words land as SPOKEN text │
              │             │  (fix a word in place)│
              │             ▼                       │
              │  write the line in hand             │
              │             │                       │
              │  finish it (✓ or tap the next line) │
              │             ▼                       │
              │  it settles — its words join the    │
              │  record; tap it later to redo it    │
              │     ▲                               │
              │     └── "say more" appends spoken   │
              │        "I'm finished"               │
              └──────────────┼──────────────────────┘
                             ▼
                     Results (this session)
                             │
                   ┌─────────┴──────────┐
                   ▼                    ▼
              Write more          See My Journal
```

**The loop is the design.** Speak and watch the words land pale on the page → write down
it, finishing each line with a tap and watching it turn into handwriting → say more when
the spoken words run out. One screen, no ceremony between talking and writing, and nothing
in the journal that is not in the child's own hand. Everything else in the app is in
service of that loop.

An entry ends when the child taps "I'm finished". Results summarise **only that entry** —
not lifetime totals, which would make each sitting feel smaller than the last.

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

### 4.3 Journal Home — the main screen

```
┌────────────────────────────────────┐
│  ╭──╮↻ Milo              [📈] [⚙]  │
│  ╰──╯ 🔥 5-day streak              │
│                                    │
│  ┌────────────────────┐ ┌────────┐ │
│  │ ✎ New Entry  +230▸ │ │ ABc    │ │
│  │   Tell me about    │ │Practice│ │
│  │   your day         │ │ +2/ltr │ │
│  └────────────────────┘ └────────┘ │
│  ┌────────────────────────────────┐│
│  │ ✦ 1,240 points   Last 7 days  ›││
│  │   +224 today     ▁▂▃▅▄▆█      ││
│  └────────────────────────────────┘│
│  Badges ────────────────── 3 of 8  │
│  [🏆][🎯][🔥][░][░][░][░][░]       │
│                                    │
│  My Journal ─────────────────────  │
│  [🔍 Search what you said        ] │
│  ┌────┬───────────────────────┬──┐ │
│  │~~~~│ Aug 28 · 9:56 PM      │★★★│ │
│  │~~~~│ "I saw a red bird…"   │+224│ │
│  │    │ 23 words · 94% · Jua  │  │ │
│  └────┴───────────────────────┴──┘ │
│              … every entry …       │
└────────────────────────────────────┘
```

**The action deck, then the points, then badges, then every entry, newest first (v3.1).**
New Entry and *Practice my letters* are two tiles on the content grid — the primary and
its outlined partner — each with a chip saying what it earns (§8.3). Beneath them the
points card shows the running total, what today added, and a bar for each of the last
seven days; tapping it opens Progress. There is **no navigation bar**: the export button is
gone from this screen (an entry's ⋯ menu still reaches *Share as PDF*, including the whole
journal), and search is a plain field directly above the entries it filters. There is no
second journal screen: the main screen *is* the journal and the list is never truncated.

**There is no resume card and no "Keep writing".** An entry is not a task with a state —
it is a page you either open or don't. Tapping a row opens it to read (§4.7), and **Edit**
there carries on writing it. A child who spoke more than they wrote finds those words
waiting on the page when they open it again, which is the same outcome the resume card
bought at the cost of a mode.

Rows show the **handwriting thumbnail**, not typed text — the journal should look like a
journal at a glance. Metadata reads *"23 words · 94% · Jua Large"*, or *"23 words · not
written yet"* when there is no tracing. The points the entry earned sit under its stars,
so the list reads as the ledger of a number that only goes up (§8.3).

There is no "Your writing" settings card. The gear reaches the same settings, and the main
screen is for entries.

### 4.4 Writing an entry — one screen

Everything happens on the page (`WIREFRAME_SPEC.md` §11.13). There is no session-start
screen, no recording screen, no review screen: the mic, the live transcript, the fixing
and the writing share one surface.

```
┌──────────────────────────────────────┐
│ I'm finished   Wednesday, March 4  ◆↺🗑│  ← toolbar
│                                      │
│  Today we went to the park and I     │  ← WRITTEN: their ink,
│  saw a big dog. The dog wanted       │    graphite — the record
│                                      │
│  to play with me and we threw a ✓    │  ← IN HAND: guide + live
│                                      │    red/green + the check
│  ball for it until it got tired.     │  ← SPOKEN: pale, editable,
│  Then we had ice cream on the way    │    not yet real
│                     ⋮                │    the whole page SCROLLS
├──────────────────────────────────────┤
│ 🎤  So far: 88%  [███░░] 15 of 48 ⌄ [Done]│  ← mic lives here
└──────────────────────────────────────┘
```

**Speak** — the mic is a round button in the footer, drawn big in the centre while the page
is empty. `SFSpeechRecognizer`, on-device, `en-US`, live partial results, up to **five
minutes**. The words land on the page *as the child says them* — in the journal face, on
the ruled lines, in the pale spoken tier — so the page is the live transcript. While
listening, the footer becomes a level meter, the elapsed time, and *I'm done talking*.
**The audio is not kept** (§10.4, v3.0) — it goes to the recogniser and nowhere else.

**A pause ends an utterance, not the take.** `SFSpeechRecognizer` hands back one utterance
at a time and numbers each from zero, so its latest hypothesis is only ever the *tail* of
what has been said — and it ends its task at every silence. A take therefore keeps the
finished utterances beside the live one and starts a fresh recognition task on the same
audio each time one ends; the microphone, the recording and the five-minute clock run
underneath, untouched. Taking the hypothesis as the transcript overwrote everything said
before the first pause, and tearing the engine down on the first final result stopped the
microphone mid-story while the page still showed it listening. A five-year-old telling a
story stops for breath constantly, so a take that cannot survive a pause is not a take.

At the five-minute cap recording stops itself and a warm banner slides over the page —
*"That's a whole lot of story! I stopped listening so we can start writing."* The cap
exists because the recogniser drifts on long takes, not to hurry the child.

Microphone permission is preceded by a **child-legible explainer** (frame 40) so the first
thing a five-year-old sees is not an adult system dialog. If permission is refused or
recognition is unavailable (frame 41), *Type it instead* puts the keyboard straight onto
the page — the app never dead-ends, and typing is the same path as speaking with the mic
removed.

**Three row states, and when text becomes real.** Every row of the page is in one of
three states, distinguishable at a glance:

| State | Letters | Ink | Part of the record |
|---|---|---|---|
| **Traced** — has ink, not selected | faint grey, under the ink | natural graphite | see below |
| **Selected** — being written now | black | red / green per segment | — |
| **Untraced** — waiting | pale and cool, editable | none | **no** |

**Any row can be selected by tapping it, at any time** — a traced row for fixing, a row
further down to skip ahead, the row they just left. A pen that starts moving on an
unselected row selects it and begins the stroke in the same gesture. When the selected
row's last letter gets ink, the next untraced row is selected on its own, and the row left
behind settles: letterforms fade to faint grey, ink turns graphite, in place. The ordinary
flow is still speak, then write straight down the page — the taps are for going back, not
for going forward.

**The record is derived, never declared.** What the journal, exports and every count read
is the unbroken run of fully-traced rows from the top of the page, recomputed from the ink
itself. It grows as rows fill, and shrinks if a record row's ink is cleared. A row traced
out of order is scored — the child wrote it — but the record, the story so far in order,
waits for the rows before it. Letters skipped on a traced row score zero (§8.1).

**Fixing a misheard word** happens in place: hold a finger on an untraced word, it opens
under a small action-coloured box, the keyboard rises, done. Untraced text is the only
editable tier — and only where no traced row sits below it, because an edit must never
reflow a row out from under its ink. There is no bulk proofread step; the child fixes what
they notice while the words are still words.

**Fixing a row you already wrote is just tapping it.** Its ink comes back in accuracy
colours, and the pen, eraser, undo and clear work on it exactly as they did the first time
— all four are scoped to the selected row, so the rest of the page's ink is untouchable.
Only the latest tracing is kept (§5.5): redoing overwrites, and a child who goes back over
a row they rushed watches their percentage go up, which is the whole reason it exists.

**Saying more appends to this page.** Tapping the footer mic again adds the new words to
the spoken tier after the last existing word and scrolls to them. An entry is a day's
page, however many times the child spoke to fill it — and the new words are no more real
than the first ones were until they too are written.

**The pencil never scrolls.** Pen touches are excluded from the scroll gesture outright,
so a pen on the page is always ink — a stroke can never be eaten by a pan. Fingers scroll:

| Finger tracing | One finger | Two fingers |
|---|---|---|
| Off | scrolls (taps still select) | — |
| On | draws | scrolls |

Two fingers is a lot to ask of a five-year-old holding a pencil, so **a chevron button at
the foot of the page scrolls without any gesture at all**. That button is the primary
mechanism; the gestures are for whoever finds them.

Taps are the third input and they all mean one thing — *select this row* — which is what
makes the surface legible: there is no tap target to learn, no region where a tap does
something different, and a held finger (the one exception) opens an untraced word for
fixing.

Ink is drawn in green/red per segment **always**; there is no toggle, because during
writing the colours *are* the feedback.

Three tools in the toolbar:

| Tool | Does |
|---|---|
| **Eraser** | Rubs out every point inside a 72 pt circle on the selected row and re-scores the letters it touched. Selected state fills the button. |
| **Undo** | Removes the selected row's last whole stroke, in order. |
| **Clear** | Wipes the selected row's ink. The rest of the page is unreachable. |

The eraser and undo are not redundant: undo is chronological, the eraser is spatial. A
child who overshoots the *a* in a ten-letter word wants to fix the *a*, not unwind
everything after it.

The readout in the footer reads **"So far: 88%"** with a one-line hint below it — see §8.1
for why the live number and the final number are not the same.

**Stopping part-way must be unremarkable.** A five-minute story is far more than a child
will write in one sitting, so stopping part-way is the *normal* case, not the exception.
*I'm finished* settles the page as it stands: every row with ink counts — they traced it —
with skipped letters at zero, and the untraced remainder stays with the entry as what is
still to write — visible on the resume card, absent from the journal, exports and every
count. No warning, no "are you sure", no lost-progress language: nothing real can be lost,
because only what is written is real.

### 4.5 Results

Summarises the entry — one entry, one result:

```
        Great job, Milo!
     You wrote all 48 words today
            ★ ★ ★
         ╭───────────╮
         │    91%    │
         │  Accuracy │
         ╰───────────╯
          + 224 points
   Best yet with Jua at Large ✨

  What you wrote ──────────────────
  ┌────────────┐  48 of 48 words
  │ Today we   │  You finished the whole thing —
  │ went to    │  nothing left over.
  └────────────┘  Jua · Large · Trace

     🏆 NEW BADGE: Sharp Shooter

        [ Say something new ]
        [ See My Journal ]
```

The panel is a thumbnail of the page in the child's own hand plus the two numbers that
matter. There is no per-sentence breakdown, because there are no sentences — and a list of
line scores would turn a journal entry back into a marked test.

**The word count carries "how far", the percentage carries "how well" — and both describe
only the record.** Stopped part-way, the subtitle reads *"You wrote 32 words today"* and the
note reads *"16 words you said are still spoken — waiting on the page for next time"*. The
accuracy is over written words only, which is no longer a special rule: unwritten words are
not in the record at all (§8.1). None of this language treats stopping as a failure, because
at five minutes of dictation it isn't one — the rest stays spoken, not unwritten.

**When words are still waiting the only way on is out** — *See My Journal*. "Say something
new" would add to a pile the child has not finished, so it appears only once the page is
fully written. Carrying on is done by reopening the entry and tapping **Edit** (§4.7).

"Best yet with *font* at *size*" replaces v1's "Best yet at Level N". The comparison must
be **setting-matched** or it is dishonest: 88% at Extra Large is not better than 84% at
Small.

### 4.6 Journal List — folded into the main screen

**There is no separate journal list screen.** It existed to hold the full history, month
grouping, search and export while the main screen showed a five-entry carousel. The main
screen now carries the whole journal (§4.3), so a second screen listing the same rows was
one tap of pure ceremony.

Search moved to the main screen's toolbar and matches transcript text — what the child
said, not how they wrote it. Export moved to the same toolbar (§4.8).

Month section headers are a future addition, wanted once a journal runs to a few hundred
entries; they are not needed to browse a first year.

### 4.7 Entry Detail — the toggle

**Reading an entry and writing it are one screen in two modes.** They used to be two
screens with a modal between them, which made *look at what I wrote* and *write some more*
feel like different places to be — and made every trip between them a chance to lose
something. Now:

| Mode | The page is | Opens this way |
|---|---|---|
| **Edit** | the writing surface: mic, ink, tools | a new entry, straight after the telling |
| **View** | the entry as it reads, with its stats | an entry reopened from the journal |

**The pencil changes mode by itself.** Putting the pen on a page you were reading *is* the
ask to write on it, so the page hands over without the child finding a button first; the
View/Edit switch in the toolbar is there for fingers. Nothing is destroyed on the way
between them — it is one session and one canvas archive, and the ink is set aside on the
way out of Edit so the surface can be rebuilt from it.

Still the heart of the app, showing the **whole entry as one page**:

- **Typed** renders the entry on ruled paper in the profile's face — so the two states are
  visually comparable, not one plain and one pretty.
- **Handwritten** renders the page the way the editor showed it: **ruled paper, the words
  faint underneath, and the child's strokes on top in natural graphite**. Not ink floating
  on blank white — a child looking at their own writing should see what they were aiming at,
  and a parent should be able to read a wobbly word by the guide beneath it. The guide uses
  the *same* faintness constant the editor uses beneath finished ink, so the two cannot
  drift apart.
- **Alignment is by construction, not by agreement.** The rules, the guide and the ink are
  drawn through one transform scaled from the width the page was captured at, so the
  original line breaks and baselines are reproduced rather than recomputed. Laying the text
  out at the review page's own width would re-wrap it and the words would slide out from
  under the strokes that belong to them.
- The replay is sized to the **text**, not to the captured canvas. The writing page keeps
  ruling itself far below the last word so more can be dictated onto it; reproducing all of
  that here would bury a three-line entry under a screen of empty paper.
- Switching uses a horizontal 3-D flip (0.35 s), which reads to a child as "turning the
  page over". Reduce Motion replaces it with a cross-fade.
- Below the page, **one stats row for the entry**: accuracy, stars, word count, and
  *(v3.0: the recording and "Hear what I said" are gone — see §10.4.)*
- **The page scrolls.** A long entry is never truncated.
- **⋯ menu:** Edit · Write it all again · Share as PDF · Rename · Delete.
- **Edit** opens the page exactly as it stands — the words, the record and the child's
  ink — finished or not, with no warning, because nothing is being destroyed. A line is
  written again by tapping it in Edit (§4.4), which is the only re-tracing a child ever
  needs.
- **A tracing is only put back at the width it was captured at.** Greedy word wrap puts
  different words on different lines at a different width, so the same points would land on
  letters they were never drawn over: the tracing would read as scribble and the record,
  being derived from ink, would re-derive as empty and overwrite what the child actually
  wrote. Edit therefore shows such a page without its ink — honest, and reversible, because
  the archive is untouched and View still draws it correctly at its own width. **The record
  never shrinks below what the page opened with until the ink has accounted for it.**
- **Replacing the whole tracing is its own action**, *Write it all again* in the ⋯ menu,
  and it says so first: *"This will replace what you wrote. The words stay the same."*
  Making that the meaning of Edit — as v2.6 briefly did, keyed on `isComplete` — threw a
  finished page away every time a child opened it to add one more line, and put the
  per-line re-trace of §4.4 out of reach on exactly the entries most worth going back to.

### 4.8 Export

Two scopes from the same screen:

- **One entry** — a single PDF page: the handwriting, the date, the typed words as a caption.
- **The whole journal** — one page per entry, oldest first, with a cover carrying the
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
  Setting              Mode   Best  Avg  Entries 
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
2. The line is a 5-entry rolling average.
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

### 4.11 Practice sheet

```
┌────────────────────────────────────┐
│ ‹ Back    Practice Letters   ↩  🗑 │
│                                    │
│  Aa Bb Cc Dd Ee                    │
│  Ff G̶g̶ Hh Ii Jj Kk   ← one letter │
│  Ll Mm Nn Oo Pp        highlighted,│
│  Qq Rr Ss Tt Uu        thin purple │
│  Vv Ww Xx Yy Zz        stroke lines│
│  0 1 2 3 4 5 6 7 8 9               │
│                                    │
├────────────────────────────────────┤
│ Your turn — trace big G!      94%  │
└────────────────────────────────────┘
```

A worksheet, not a journal page. The full alphabet in capital–lowercase pairs plus the
digits, ruled like the writing page, rendered in **Jua at a size the sheet computes for
itself** — the largest type at which the widest row still fits the screen, so the letters
fill the page edge to edge on any iPad.

**The loop:** touch a letter → its formation demo plays — each stroke draws itself as a
**thin purple line** (`practice-path`, the one hue with no other meaning in the app) at a
followable pace, an arrowhead landing at each end. Stroke order is carried by the
animation alone — no numbered badges cluttering the letter; a child who wants the order
again taps the letter again. When the demo ends **the arrowheads leave and the thin lines
stay, solid**, an inner guide running down the middle of each stroke, and the footer says
*"Your turn."* The child's ink always renders **above** the guide — the guide is part of
the paper, the ink is the pen.

**The pencil is a pen, the finger is a pointer.** A pencil touch inks immediately, from
the exact point it lands — no tap-slop dead zone, no scroll-view touch delay, and a
pencil arriving after a resting palm takes the stroke over from it. A pencil tap on a
*new* letter still plays the demo (landed, lifted, wrote nothing = a tap); on the
already-selected letter it leaves a dot, which is how the dot of an i gets traced.
Finger taps always play the demo; finger strokes buffer their first samples through the
tap-detection phase so their ink also begins at first contact. The
child traces with the live green/red ink of the writing page. Enough good ink — measured
as **pen-travel inside the letter against the formation's own length**, so a fast
confident trace earns the same credit as a slow careful one — flips the cell green with a
success haptic: *"Nice G! Pick another letter."* Touching the next letter clears the
last one; touching the same letter replays its demo. A pen that simply starts writing on
another letter switches to it without the demo — they are already tracing.

**Sandbox rules:** no ink is saved, nothing is graded, and nothing here touches the
streak or the badges — but a letter that flips green **earns points** (§8.3, v3.1): two
in the arrow order, one otherwise, each letter once a day. The award replaces the footer
% for the letter in hand (*+2 points*) and a *+18 today* pill in the toolbar keeps the
day's count. Letters that have earned stay coloured for the rest of the day — green for
two points, orange for one (blue and orange in the colour-blind scheme) — so the sheet shows
what is done; the letter in hand always draws in the plain guide colour so its ink stays
visible, and the idle footer carries a one-line legend. Undo and clear live in the toolbar;
live accuracy shows in the footer while ink is down. The footer % takes the order discount (§8.1a) exactly as the journal does —
the sheet teaches the rule the journal grades — and when a traced letter ignored the
arrows the "Nice G!" line becomes a nudge: *"Good G! Try the strokes in the arrow order."*

**Why Jua only:** the stroke-order guides are hand-authored per letterform
(`LetterFormations.swift`, 62 characters × 1–4 strokes, in glyph-ink-box coordinates,
fitted to the glyph's real outline via CoreText at render time and inset by half of
Jua's stroke width, so the guide runs down the middle of the stroke rather than along
its edge). Single- versus
double-story letters and differing hooks make one data set dishonest across faces;
locking the sheet to the default face keeps every arrow truthful. Reduce Motion skips
the animation and shows the numbered guide immediately.

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
    var practiceLedger: [String: Int] = [:]   // "yyyy-MM-dd|G" → 1 or 2 (§8.3, v3.1)
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastWroteOn: Date?
    var totalWordsWritten: Int = 0
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

    // Everything the child said, verbatim
    var rawTranscript: String = ""
    var spokenDuration: Double = 0        // seconds, ≤ 300 per dictation

    var author: UserProfile?

    // The page itself — see §5.3
}
```

A session is **one entry — a page**. It opens when the child taps New Entry and closes when
they tap "I'm finished" (or the app is backgrounded for more than 30 minutes). Speaking
again during the same sitting appends to the same page rather than opening a new one
(§4.4); two separate sittings on one day are two entries, which is why the journal list
shows a time alongside the date.

Denormalising font/size/mode onto the session — rather than reading it from the profile —
is deliberate. Progress compares like with like, and a child who moves from Large to Medium
must not have their old sessions silently relabelled.

### 5.3 There is no Sentence entity — and the transcript is the record

A session holds one record, one spoken buffer, one stroke archive and one recording.
Splitting the transcript into rows bought nothing once the page scrolled, and it cost a
model, a relationship and an ordering column.

```swift
// on WritingSession
var transcript: String            // THE RECORD — only text the child has written (v2.5)
var spokenBuffer: String          // said but not yet written; provisional, editable
var rawTranscript: String         // everything the recogniser heard, verbatim
@Attribute(.externalStorage) var audioData: Data?      // the whole telling

var tracedAt: Date?
var accuracy: Double              // §8.1, over the record's letters
var letterAccuracies: [Double]    // aligned to `transcript`
var wordsWritten: Int             // == wordCount(transcript), by construction
var totalWords: Int               // record + buffer: what "of 48 words" means
@Attribute(.externalStorage) var strokeArchive: Data?
@Attribute(.externalStorage) var thumbnailData: Data?
```

**`transcript` follows the ink** (§4.4): it is the unbroken run of fully-traced rows from
the top of the page, re-derived whenever the ink changes — it grows as rows fill and
shrinks if a record row's ink is cleared. Everything downstream — journal rows, search,
Entry Detail's Typed page, exports, `totalWordsWritten`, badges — reads `transcript` and
never the buffer. The buffer exists so a child who spoke for four minutes and wrote for
six does not have to say it again tomorrow; it is scratch, not record, and the resume card
is the only UI that quotes it.

### 5.4 There is no Draft entity either

A draft is **an entry with spoken words still waiting**: `!spokenBuffer.isEmpty`. The entry's
own record is complete whatever the buffer holds — a "draft" is unfinished *telling*, never
unfinished record.

Since v2.6 this distinction has **no UI of its own**. Such an entry is an ordinary row in
the journal whose metadata reads *"N words · not written yet"*; opening it and tapping Edit
puts the waiting words back on the page. The flag still drives the Results copy (§4.5) and the
entry-detail line that reads *"You finished the whole thing."* — it is a property of an
entry, not a state the app asks the child to resolve, and it never gates Edit (§4.7).

### 5.5 Reproducing a tracing

The session carries font, size, mode, `transcript` and the canvas width. Together those
reproduce the *exact* guide layout at any time — the mask renderer is deterministic given
those inputs, so a line's glyph boxes can be recovered to re-score it or to re-trace it. That keeps an "ink over guide" review state,
or a re-score under a revised algorithm, available without a migration.

Progress reads font/size/mode from the **session**, so a settings change never relabels
history. Index `WritingSession.fontKey`, `sizeKey` and `modeRaw`.

---

## 6. Stroke Persistence

Strokes are archived as a compact binary blob, not JSON. A ten-line page traced by a child
runs 15,000–40,000 sample points; JSON would be several megabytes per entry, which is
unacceptable when the goal is to keep every page forever and eventually sync it.

### 6.1 Format `HJST` v2

```
Header (8 bytes)
  magic        4  "HJST"
  version      1  0x02   (0x01 still decodes; see below)
  flags        1  reserved (0)
  strokeCount  2  UInt16, little-endian

Per stroke
  pointCount   2  UInt16
  points[]     14 bytes each (10 in v1):
     x         4  Float32   canvas coordinates
     y         4  Float32
     force     1  UInt8     force × 255, clamped
     inside    1  UInt8     0 = outside letter, 1 = inside
     letter    4  Int32     index of the glyph the point was drawn against, −1 if none
                           (v2 only)
```

The blob is then compressed with `Compression` / LZFSE.

**Why the letter is stored (v2).** The record is derived from which letters have ink,
and ink is attributed to the row in hand *as it is drawn*. An archive that keeps only
positions has to re-derive that attribution against the mask when the page reopens, and
a descender's tail re-read against the whole page can land on the row below and
unfinish a line the child finished — the page would reopen with a shorter record than
it closed with. v2 makes a restore exact. A v1 archive decodes unattributed and the
canvas attributes it afresh, as before.

**Measured expectation:** 6,000 points → 60 KB raw → ~18–24 KB compressed, so a ten-line
page lands around 120 KB. **One archive per entry, not per attempt** — re-tracing a line
rewrites the entry's archive rather than adding to it. A child writing daily for five years
produces on the order of 200 MB of ink, plus voice. Both are viable keepsakes and viable
iCloud payloads.

**The eraser edits the archive.** Erasing removes points from the in-memory stroke set
before encoding; a stroke that loses its middle becomes two strokes.

**The archive is written on every stroke** (v3.0) — pen-up, undo, erase, clear and a
restore each re-encode the ink to the entry and save the store at once. Done adds the
score and nothing else. Two rules keep this safe:

- **Only a surface that has put the entry's ink back may write it.** A canvas carries
  a *provenance* — fresh, pending, restored or lost — and the view model refuses to
  write the archive, or to move the record, on the word of a canvas that is pending or
  lost. The bug this closes: finishing an entry, reading it, and tapping *Write on this
  page* built a new surface from a stale cache with no ink in it; that surface reported
  an empty record and wrote an empty archive over the child's page. The next surface is
  now always staged from the entry.
- **Never an empty archive over ink**, except by the child's own undo or clear on a
  surface that accounts for the archive — then the empty page is the truth.

**The `inside` flag is trace-specific.** It records whether a point fell inside the guide
letterform. Copy mode has no letterform under the pen, so the flag is meaningless there —
see §7.4. Reserve `flags` bit 0 to mean "no per-point inside data" before shipping, so a
Copy-mode archive is not misread as an all-outside trace.

### 6.2 Replay — and one width for life

```swift
enum StrokeArchive {
    static func encode(_ strokes: [TracingStroke]) throws -> Data
    static func decode(_ data: Data) throws -> [TracingStroke]
    static func decodeArchive(_ data: Data) throws -> Decoded   // strokes + whether attributed
}
```

Rendering an archived attempt into a view of a different size uses an aspect-fit transform
derived from the stored `canvasWidth/Height`. Aspect ratio is preserved; the drawing is
letterboxed rather than stretched, because stretched handwriting looks wrong immediately.

**The writing surface does the same** (v3.0). Greedy word wrap at any other width puts
different words under the child's strokes, so once an entry has ink its page lays out at
`canvasWidth` for life and `ScrollingCanvas` scales the canvas to the window. Stage
Manager, Split View and a bigger iPad show the same page larger or smaller; they never
re-wrap it. Touches arrive in canvas coordinates, so the pen and the eraser need no
conversion — only scrolling does.

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

### 7.4 Laying out the page

The child speaks for up to five minutes and the result is laid out as one continuous page.
`MaskRenderer.contentHeight(text:setup:width:)` measures how tall that page needs to be —
with the real face at the real size, never a character count, because the five bundled
faces differ by up to 40% in advance width.

The page is then a `UIScrollView` whose content is one tall canvas. Nothing is truncated
and nothing is split; a longer entry is simply a longer page.

There is no fit rule and no splitter any more. Both existed only because the surface used
to be fixed-height.

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

entryAccuracy     = mean(letterAccuracy) over every scored glyph, spaces excluded
```

A letter with no ink scores **0%** — but only on rows the child traced.

The scored population is **every row with any ink**, wherever it sits on the page: the
child wrote it, so it counts, and its untouched letters cost. Rows with no ink are not in
the population at all — unwritten words are not failed words, and stopping part-way stays
ordinary by construction (v2.4's "words never reached" rule, now at row granularity).

```
scored letters  = every letter on a row with any ink, spaces excluded
accuracy        = mean(letterAccuracy) over scored letters
progress        = wordsWritten / totalWords     — inked words over everything said
```

**Live and final differ on purpose.**

| | Denominator |
|---|---|
| **Live** — shown while writing as *"So far: NN%"* | Only letters actually attempted |
| **Final** — computed at Done | Every letter in every word that was started |

If the live figure applied the skip-penalty it would lurch downward each time the child
moved to a new letter, which reads as being punished for progress. The page reports
*"9 of 30 words"* alongside it, so how far they have got is never confused with how well
they did.

The end of the session states the outcome plainly: *"You wrote the whole thing"*, or
*"2 letters were skipped"*, or how many words are still waiting.

### 8.1a The order discount

Accuracy also cares *how* the letter was drawn. Each inked letter is judged against its
taught formation — the stroke order and per-stroke direction the practice sheet
demonstrates (§4.11) — and a letter that clearly took the wrong path keeps only **80%**
of its score:

```
letterAccuracy(i) = pointsInsideGlyph(i) / pointsAttemptedOnGlyph(i)
                    × 0.8 if the ink did not follow the formation
```

The discount is per letter, so one backwards *a* on a forty-letter page costs half a
percent, and a page of backwards letters costs the full twenty. It flows through
everything derived from letter accuracy — the live figure, the final figure, stars,
points — and the finish message names it the way it names skipped letters.

**What counts as wrong.** The letter's parts must be *first traced* in the taught
sequence (circle before line for an *a*), each part in its taught direction (top-down;
a loop like *o* must also begin near its taught start). Everything else is forgiven by
design:

- **Pen lifts don't matter.** An *a* drawn in one motion that still goes
  circle-then-line, each the right way, passes. The demo's stroke count is a teaching
  device, not a rubric.
- **Go-overs don't matter.** Only the first genuine visit to each part is judged;
  darkening a finished part is not a fault.
- **Unjudgeable ink passes.** Ink that barely lies along the formation is given the
  benefit of the doubt — the inside/outside score already speaks for wild ink, and a
  20% dock must never stack onto a letter the child plainly struggled with for a
  different reason.
- **No formation, no judgment.** Punctuation has no taught order and is never docked.

**Jua only.** The formations are hand-fitted to Jua and the practice sheet demonstrates
them in Jua (§4.11), so only Jua entries take the discount — the app does not grade an
order it has never shown. The other faces score as §8.1 alone. If per-face formations
are ever authored, the gate (`FormationOrderJudge.honestFaceID`) is where the decision
lives.

The judgment runs at pen-up, never mid-stroke, and re-runs when ink changes — undo,
eraser, clear, or a restored archive (stroke order is chronological in the archive by
construction, so an old entry re-scores identically).

**How the judge reads a real pen (v3.0).** Letterforms pass close to themselves — the
bar of an *e* starts two points from the arc that comes back round to it, the tail of a
*y* runs up the same line its second stroke runs down, every stem meets its bowl — and
snapping each sample to the nearest point of the taught path flickered between those
parts, producing "backwards" verdicts for letters drawn exactly as taught. So:

- **The pen is tracked along the path.** Its position along a part is carried forward
  and only moves as far as the pen moves; a part is only surrendered once the pen is
  clearly off it.
- **Where a pen lands between parts, the part it goes on to move along is the one it
  meant** — judged over the next stroke-width or two, weighted by closeness, among the
  parts it actually stays with. A pen plainly *on* one part (half as far from it as from
  any other) is tracing that part whichever way it is going, which is what makes a stem
  drawn bottom-up through the start of its hump still read as a stem drawn upwards.
- **Direction is the net motion of a part's first visit**, not its opening travel: a pen
  that runs up a stem to begin it from the top and then draws it down has drawn it down.
- **A genuine visit covers a substantial share of the part** — enough travel and at
  least 40% of its length — so a landing beside a junction is not a visit to the wrong
  part.
- **A tap is a dot** when an *i* or *j* has one near enough to be meant.

`FormationJudgeRealismTests` traces every character on real Jua geometry with a
wobbling, mis-landing pen, forty times each, and requires no false docks — steady hand
or shaky — while still requiring every backwards and every out-of-order trace to be
caught.

### 8.1b The remediation modal

The discount is a nudge; the modal is the lesson. **When a word is complete and the
child is done with it**, if any of its letters took the order discount, a modal covers
the whole page — chrome included:

```
┌──────────────────────────────────┐
│       Let's practice little a!   │
│                                  │
│            d o g s               │  ← the word in the journal face;
│            ▔red▔                 │    wrong-order letters in red
│  The red letters were written in │
│  a different order. Watch how    │
│  little a is written…            │
│  ┌────────────────────────────┐  │
│  │      (the letter, big,     │  │  ← the practice sheet's own
│  │   arrows play, then trace) │  │    demo → trace loop, one letter
│  └────────────────────────────┘  │
│          ↻ Watch again           │  ← after success, this becomes
│                                  │    [ ✓ I did it — keep writing ]
└──────────────────────────────────┘
```

- **One lesson, picked at random.** More than one red letter: one of them, at random,
  is taught. The others stay red — their discount stands.
- **The only way out is through.** No close control exists until the letter is traced
  correctly, which here means the full bar: taught order, taught directions, every
  stroke of the formation covered, and the practice sheet's good-ink threshold. A
  wrong-order attempt wipes itself **at the pen-up that condemned it** and replays the
  arrows — the verdict is sticky (first visits cannot be unmade by more ink), so a
  deferred wipe would leave doomed ink on the sheet for the child's correct retrace to
  merge into, and the retrace could then never complete. The reset is the canvas's own,
  synchronous act; the modal only says *"Almost!"* over it. (This is the one deliberate
  exception to "the app never dead-ends" — the demo replays forever, the bar is one
  letter, and the lesson is the point.)
- **A finger can dot an i here.** On the practice sheet a finger tap always replays the
  demo, and the dot of an i is a pencil-only nicety — harmless there, because the
  sheet's green flip never requires the dot. The modal requires the whole formation,
  so on its sole-letter sheet a finger tap on the letter *once tracing has begun* inks
  the dot instead; replays live on the *Watch again* button.
- **Success corrects that letter only.** Its discount is lifted for the life of the
  entry; the modal closes; the live figure rises. The remediation is recorded on the
  session (`remediatedCharIndices`, by character position — glyph indices are not
  stable across sittings) so reopening and re-finishing the entry keeps the correction.
  *Write it all again* clears remediations with the ink they excused.
- **Once per word, and only under the child's own pen.** A word prompts at most once
  per sitting; a stroke that finishes two qualifying words queues the second modal
  behind the first; and a page restored from its archive never prompts for words that
  arrived already written — their discounts still apply, silently.
- **Not before the child is done with the word** (v3.0). A word reads as complete the
  moment its last letter has *any* ink, and a letter with several parts gets its first
  part first: the stem of a *t* completes the word before the crossbar exists. The
  modal used to open there, over a letter the child was about to finish. Now a
  qualifying word waits until every one of its letters is fully covered — every part
  of every formation visited — or until the child's pen lands on another word, which is
  them saying they are done with this one.
- The trace in the modal does not replace the ink on the page — the page keeps what
  the child wrote; only the order verdict is forgiven.

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
Journal Home shows the total, what today added and a bar for each of the last seven days
(§4.3); every entry in the list shows what it earned.

**Practice letters earn points too (v3.1).** A letter that flips green on the practice
sheet is worth **+2** when its strokes followed the arrows and **+1** when they did not
(§8.1a); a one-point letter tops up to two if it is traced in order later the same day.
Each character earns at most once a calendar day, so the whole sheet — 62 characters — is
worth 124 and needs no cap. Practice points add to the running total only: they never
extend a streak, unlock a badge or appear in the journal list. The journal stays the
point.

### 8.4 Streaks

A streak counts consecutive **days** with at least one completed session. Missing a day
resets it. `longestStreak` is kept forever.

### 8.5 Badges

None reference levels.

| ID | Name | Earned when |
|---|---|---|
| `first_entry` | First Entry | First entry written |
| `sharp_shooter` | Sharp Shooter | Any tracing at 90% or better |
| `streak_5` | 5-Day Streak | Streak reaches 5 |
| `ten_entries` | Ten Entries | 10 completed entries |
| `perfect_week` | Perfect Week | Wrote on 7 consecutive days |
| `thousand_words` | 1,000 Words | 1,000 words written |
| `every_font` | Every Font | At least one tracing in each of the five faces |
| `neat_writer` | Neat Writer | Five consecutive entries at 85% or better |

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

### 10.4 The child's voice — retired

*(v3.0)* The recording and *"Hear what I said"* are gone. The microphone feeds the
speech recogniser and nothing else: no audio file is written, nothing is sliced,
nothing is kept. The explainer screen's promise — *"Your voice stays on this iPad"* —
is now literally true of the sound as well as the words: it never exists as a file.
`WritingSession.audioData` and `spokenDuration` stay in the schema, unread, so existing
stores need no migration; deleting an entry still deletes whatever an older build stored
there.

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
chosen size (`WIREFRAME_SPEC.md` §7.2–7.3), at that size everywhere — a finished line is
never redrawn smaller. Thumbnails are the one exception (§10.6 of the spec).

### 11.3 Motion

| Moment | Motion |
|---|---|
| Standard transition | 0.30 s ease-in-out |
| Typed ↔ Handwritten | 0.35 s 3-D flip, y-axis |
| Guide fade on reveal | 0.50 s |
| **A row settles** — whenever selection leaves it | **0.45 s cross-fade in place: letterforms to faint grey, ink to graphite** |
| Spoken words landing during dictation | 0.15 s fade-in per word, no movement |
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
  Models/         UserProfile, WritingSession, WritingSettings, TracingStroke
  Services/       MaskRenderer (per-glyph), StrokeColorizer, ScoringEngine, BadgeEngine,
                  LetterFormations (stroke-order data, Jua-fitted),
                  StrokeArchive, StrokeEraser, SpeechRecognitionService,
                  AudioSlicer, AudioService, HapticsService, FontRegistry,
                  PDFBookBuilder
  ViewModels/     ProfileViewModel, SessionViewModel, DictationViewModel,
                  TracingViewModel, ProgressViewModel
  Views/          ProfilePickerView, ProfileEditorView, PinPadView, AvatarCaptureView,
                  PracticeView (letter formation worksheet),
                  JournalHomeView (badges + full journal), CalendarView, EntryDetailView,
                  ExportView, JournalBookExportView,
                  WriteSessionView (dictate → check → write),
                  ResultsView, ProgressView, SettingsView, FontPickerView, SizePickerView
    Components/   TracingCanvas, TracingSurface (scrolling page), PageReplayView,
                  PracticeCanvas (worksheet + stroke-order demo overlay),
                  LevelMeter, WritingProgressBar, DesignSystem (buttons, avatars,
                  stars, rings, segmented control)
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
- `SessionTests` — appending a second dictation to an open page, session close on
  background, and resuming an unfinished entry scrolled to the right word.
- `PageLayoutTests` — page height grows with text and with size; every bundled face lays
  the same words out without dropping glyphs; word indices march forward and match the
  transcript; a word can be located on the page so a resumed entry scrolls to it.
- `MaskRendererFontTests` — the mask matches the visible guide for **every face on the
  list**, at every size. This is the test that catches a badly chosen font.
- `PerLetterScoringTests` — the important one. An untouched glyph scores 0; a word with
  four of twenty-eight letters traced scores near 14%, not near 95%; words never started are
  excluded from the denominator entirely; the live figure excludes unstarted letters while
  the final figure includes them for started words; spaces are not scored.
- `FormationOrderTests` — §8.1a against the real Jua formation data. Circle-then-line
  passes and line-then-circle fails; a bottom-up line fails; one continuous
  circle-then-line motion passes (lifts don't matter); go-overs pass; a clockwise or
  bottom-started *o* fails; dot-before-stem *i* fails; far-off ink is not judged; the
  discount is 0.8× per letter, live and final, cleared by an erase, and named by the
  finish message.
- `FormationHelpTests` — §8.1b end to end on a real laid-out page. Finishing a word
  with a wrong-order letter fires the help request once, naming exactly the wrong
  letters; remediation lifts exactly the picked letter's discount and never re-prompts;
  a page restored from an archive never prompts while its wrong-order ink still takes
  the discount; and a remediation recorded by character position comes back.
- `EraserTests` — points inside the circle are removed, a stroke split in the middle becomes
  two strokes, and the touched letters are re-scored while the others are untouched.
- `ProgressBreakdownTests` — per-setting aggregation, and that a settings change does not
  relabel old sessions.

---

## 15. Development Phases

| Phase | Contents |
|---|---|
| **1** | Profiles, PIN, SwiftData model, Journal Home shell |
| **2** | Long-form dictation → check → write, Trace mode only. The scrolling page, the eraser and per-letter scoring all land here — none of them are polish. |
| **3** | Word progress, resuming an unfinished entry where the child left off, Results |
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
| Speech recognition on young voices | Spoken words stay editable in place until written; a mishearing never has to enter the record; keyboard fallback |
| A chosen font traces badly | Curated list only, plus `MaskRendererFontTests` |
| **Per-glyph masks are a real engine change** | Budget for it in phase 2; `CTLine` glyph runs give the bounding boxes |
| **Latest-only means a bad re-trace destroys a good one** | "Trace This Again" must say *"This will replace what you wrote"* |
| **Five minutes of speech is a lot of writing** | Stopping part-way is the easy path: "I'm finished" is always in the toolbar, the resume card is first on Home, no warning language anywhere |
| **Scrolling a surface you are drawing on** | Touch-count separation plus a button that scrolls with no gesture at all (§4.4). Watch this in testing — it is the one interaction a five-year-old could genuinely fight |
| **A very long entry makes a very tall mask bitmap** | The renderer drops to 1× above ~40 MP rather than allocating tens of megabytes |
| Voice recordings are the most sensitive data here | On-device only, deleted with the entry, stated plainly in child-legible copy (§10.4) |
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

- `WIREFRAME_SPEC.md` v2.6 — measurements, tokens, component library, frame inventory
- `PENPOT_HANDOFF.md` — what the built Penpot file does differently and why
- `Original Traceright App/` — the working tracing engine this is ported from

---

*Document version: 2.6*
*Last updated: 2026-08-27*
