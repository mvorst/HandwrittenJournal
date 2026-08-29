# Handwritten Journal

## Design Document v2.7

An iPad journal for a child who is learning to write. The child talks about their day, the
app transcribes it, and the words appear on a ruled page for them to write over. Each line
they finish stops being a guide and becomes their own handwriting, right where they wrote
it. Do that for a day and there is a page. Do it for a year and there is a journal in the
child's own hand.

Companion: `WIREFRAME_SPEC.md` v2.5 (measurements, tokens, frame inventory).
Build notes: `PENPOT_HANDOFF.md`.

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
│  [↑]              [🔍 Search    ]  │
│  ╭──╮↻ Milo              [📈] [⚙]  │
│  ╰──╯ 🔥 5-day streak              │
│                                    │
│        ┌──────────────────┐        │
│        │  ✎  New Entry    │        │
│        └──────────────────┘        │
│                                    │
│  Badges ─────────────────────────  │
│  [🏆][🎯][🔥][░][░][░][░][░]       │
│                                    │
│  My Journal ─────────────────────  │
│  ┌────┬───────────────────────┬──┐ │
│  │~~~~│ Aug 28 · 9:56 PM      │★★★│ │
│  │~~~~│ "I saw a red bird…"   │  │ │
│  │    │ 23 words · 94% · Jua  │  │ │
│  └────┴───────────────────────┴──┘ │
│  ┌────┬───────────────────────┬──┐ │
│  │~~~~│ Aug 28 · 7:56 PM      │★★★│ │
│  └────┴───────────────────────┴──┘ │
│              … every entry …       │
└────────────────────────────────────┘
```

**Badges first, then every entry, newest first.** There is no second journal screen: the
main screen *is* the journal, so search and export live in its toolbar and the list is
never truncated.

**There is no resume card and no "Keep writing".** An entry is not a task with a state —
it is a page you either open or don't. Tapping a row opens it to read (§4.7), and **Edit**
there carries on writing it. A child who spoke more than they wrote finds those words
waiting on the page when they open it again, which is the same outcome the resume card
bought at the cost of a mode.

Rows show the **handwriting thumbnail**, not typed text — the journal should look like a
journal at a glance. Metadata reads *"23 words · 94% · Jua Large"*, or *"23 words · not
written yet"* when there is no tracing.

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
**The audio is recorded and kept** (§10.4).

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

**Three tiers, and when text becomes real.** Every line of the page is in one of three
states, distinguishable at a glance:

| State | Text | Ink | Part of the record |
|---|---|---|---|
| **Written** — finished | none — their ink *is* the text | natural graphite | **yes** |
| **In hand** — being written | guide, locked | red / green per segment | not yet |
| **Spoken** — said, waiting | pale and cool, editable | none | **no** |

**The child finishes a line by saying so**: tapping the check that sits at the end of the
line in hand, or tapping the next spoken line to take it in hand. That is the settle —
guide fades, ink turns graphite, in place — and it is also the **commit**: only then do
that line's words join the record. Writing goes in order; only the next spoken line can be
taken in hand, because a record assembled line by line must stay contiguous. Letters
skipped on a line the child chose to finish score zero (§8.1) — finishing is a choice, not
a certificate.

**Fixing a misheard word** happens in place: tap a spoken word, it opens under a small
action-coloured box, the keyboard rises, done. Spoken text is the only editable tier — the
in-hand line's guide must not move under the pen, and written lines are the record. There
is no bulk proofread step; the child fixes what they notice while the words are still
words, and a mistake they never notice is caught the moment it becomes awkward to trace.
Since edits can only touch the spoken tier, nothing the child has written ever reflows.

**Tap a written line to write it again.** The line highlights, a *"Write this line again"*
chip appears beneath it, and tapping the chip clears that line's strokes and returns it to
the in-hand state. The words stay in the record — only the ink is redone, and only the
latest tracing is kept (§5.5). A child who goes back over a line they rushed watches their
percentage go up, which is the whole reason it exists.

**Saying more appends to this page.** Tapping the footer mic again adds the new words to
the spoken tier after the last existing word and scrolls to them. An entry is a day's
page, however many times the child spoke to fill it — and the new words are no more real
than the first ones were until they too are written.

**Scrolling and the pen are separated by touch count, not by guesswork:**

| Finger tracing | One finger | Two fingers |
|---|---|---|
| Off | scrolls | — |
| On | draws | scrolls |

With finger tracing off, only the pencil draws and a finger scrolls — unambiguous. With it
on, the split is what Notes and Procreate do. Two fingers is a lot to ask of a five-year-old
holding a pencil, so **a chevron button at the foot of the page scrolls without any gesture
at all**. That button is the primary mechanism; the gestures are for whoever finds them.

Taps are the third input, and each tap target is unambiguous about which tier it landed
on: a written line selects for re-tracing, the next spoken line advances, a spoken word
opens for fixing, the check finishes the line. None of those regions is one where drawing
or scrolling is the obvious intent, and a tap that lands nowhere meaningful clears the
selection and does nothing.

Ink is drawn in green/red per segment **always**; there is no toggle, because during
writing the colours *are* the feedback.

Three tools in the toolbar:

| Tool | Does |
|---|---|
| **Eraser** | Rubs out every point inside a 72 pt circle and re-scores the letters it touched. Selected state fills the button. |
| **Undo** | Removes the last whole stroke, in order. |
| **Clear** | Wipes the page's ink. Nothing is scored until Done. |

The eraser and undo are not redundant: undo is chronological, the eraser is spatial. A
child who overshoots the *a* in a ten-letter word wants to fix the *a*, not unwind
everything after it.

The readout in the footer reads **"So far: 88%"** with a one-line hint below it — see §8.1
for why the live number and the final number are not the same.

**Stopping part-way must be unremarkable.** A five-minute story is far more than a child
will write in one sitting, so stopping part-way is the *normal* case, not the exception.
*I'm finished* commits the line in hand if it has any ink (they traced it, so it counts —
skipped letters at zero) and returns it to spoken if it has none. The spoken remainder
stays with the entry as what is still to write — visible on the resume card, absent from
the journal, exports and every count. No warning, no "are you sure", no lost-progress
language: nothing real can be lost, because only what is written is real.

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
  **"Hear what I said"** — the recording the child made when they dictated it. One entry has
  one recording, so there is nothing to slice and nothing to list.
- **The page scrolls.** A long entry is never truncated.
- **⋯ menu:** Edit · Hear what I said · Write it all again · Share as PDF · Rename · Delete.
- **Edit** is the primary button below the page, and it is how every entry is changed —
  this screen is what a tap on the main screen opens, so Edit is one tap from the journal.
  **It opens the page exactly as it stands** — the words, the record and the child's ink —
  finished or not, with no warning, because nothing is being destroyed. A line is written
  again by tapping it inside the session (§4.4), which is the only re-tracing a child ever
  needs.
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

**Sandbox rules:** no persistence, no score kept, no streak or badge effect. Undo and
clear live in the toolbar; live accuracy shows in the footer while ink is down.

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

**`transcript` grows one finished line at a time** (§4.4): finishing the line in hand moves
its words from `spokenBuffer` into `transcript`. Everything downstream — journal rows,
search, Entry Detail's Typed page, exports, `totalWordsWritten`, badges — reads
`transcript` and never the buffer. The buffer exists so a child who spoke for four minutes
and wrote for six does not have to say it again tomorrow; it is scratch, not record. Since
v2.6 no list or card quotes it — it is seen only on the page itself, when the entry is
opened for editing.

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

**Measured expectation:** 6,000 points → 60 KB raw → ~18–24 KB compressed, so a ten-line
page lands around 120 KB. **One archive per entry, not per attempt** — re-tracing a line
rewrites the entry's archive rather than adding to it. A child writing daily for five years
produces on the order of 200 MB of ink, plus voice. Both are viable keepsakes and viable
iCloud payloads.

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

A letter with no ink scores **0%** — but only on lines the child chose to finish.

v2.4 needed a special rule here ("words never reached are not scored") to keep stopping
part-way from reading as collapse. v2.5 gets the same outcome structurally: unwritten
words are not in the record at all (§5.3), so there is nothing to score and nothing to
excuse. The scored population is simply the record.

Inside a line the child *did* finish, a skipped letter still scores zero — finishing a
line is a choice, not a certificate, and the anti-skip property is what made per-letter
grading worth doing:

```
scored letters  = every letter of the record (finished lines), spaces excluded
accuracy        = mean(letterAccuracy) over scored letters
progress        = wordsWritten / totalWords     — record over record-plus-spoken
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

### 10.4 The child's voice

Each dictation is recorded before it is transcribed, and **the recording is kept whole**
(`WritingSession.audioData`, AAC mono 32 kbps, external storage). There is nothing to slice
any more: one entry has one recording, and *"Hear what I said"* sits on the entry. The
recording keeps the **whole telling**, including words that never get written — the voice
is its own artefact (below), and the spoken-until-written rule (§4.4) governs text, not
sound. Deleting the entry deletes it all.

Size is the thing to watch. A five-minute take is ~1.2 MB, and a child who fills the cap
every day for five years would accumulate over 2 GB. In practice entries are far shorter
than the cap — the fixture entry is 41 seconds, ~160 KB — and a second dictation appended
to the same page is concatenated into the same recording. If the totals ever become a
problem, the fix is a retention setting with the size stated, not silent trimming.

This is the most sensitive data the app holds, and it is worth being explicit about:

- It **never leaves the iPad**. There is no network code.
- It is covered by the same courtesy-lock caveat as everything else (§10.3): a PIN is not
  encryption.
- Deleting an entry deletes its recording. Deleting a profile deletes all of them.
- The explainer screen says so in words a child can read: *"Your voice stays on this iPad."*

The reason to keep it is simple and it is not a feature request from the child: in three
years, the page in their handwriting *paired with* their five-year-old voice saying it
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
chosen size (`WIREFRAME_SPEC.md` §7.2–7.3), at that size everywhere — a finished line is
never redrawn smaller. Thumbnails are the one exception (§10.6 of the spec).

### 11.3 Motion

| Moment | Motion |
|---|---|
| Standard transition | 0.30 s ease-in-out |
| Typed ↔ Handwritten | 0.35 s 3-D flip, y-axis |
| Guide fade on reveal | 0.50 s |
| **A line settles** — on the child's finish-tap, never automatically | **0.45 s cross-fade in place: guide out, ink to graphite** |
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

- `WIREFRAME_SPEC.md` v2.5 — measurements, tokens, component library, frame inventory
- `PENPOT_HANDOFF.md` — what the built Penpot file does differently and why
- `Original Traceright App/` — the working tracing engine this is ported from

---

*Document version: 2.7*
*Last updated: 2026-08-28*
