# App Store Listing — Handwritten Journal

Everything App Store Connect will ask for, written and ready to paste. Character limits
are noted against each field and every string below has been counted (§10 shows the
counts). Drafted 2026-09-01 against `DESIGN_DOCUMENT.md` v2.9 — if a feature changes,
change the copy here first.

Facts this copy is built on: iPad only (`TARGETED_DEVICE_FAMILY: 2`), portrait only,
iOS 18.0 minimum, bundle `com.mattvorst.education.handwrittenjournal`, home-screen name
**Journal**, on-device speech (`requiresOnDeviceRecognition = true`), no network code.

---

## 1. Product page — the fields

### 1.1 App Name — 30 char limit

```
Handwritten Journal
```
*(19)* — The home-screen name stays `Journal`; these are separate fields and the shorter
one is right under an icon. If the plain name is taken at submission, fall back to
`Handwritten Journal: Kids` *(25)*.

### 1.2 Subtitle — 30 char limit

```
Kids' handwriting, their words
```
*(30 — exactly at the limit; do not add a character.)*

Alternates, if you would rather carry the promise than the keywords:

| Subtitle | Chars | Trade-off |
|---|---|---|
| `Kids' handwriting, their words` | 30 | **Recommended.** Indexes "kids", "handwriting", "words". |
| `Handwriting practice for kids` | 29 | Strongest for search, weakest for the idea. |
| `They speak it, then write it` | 28 | Best explanation of the mechanic, indexes nothing. |
| `Say it, write it, keep it` | 25 | Best line, worst ASO. |

### 1.3 Keywords — 100 char limit, comma-separated, no spaces

```
trace,tracing,letter,alphabet,penmanship,print,dictate,speech,diary,pencil,school,abc,write,learn
```
*(97)*

Rules applied: no word repeated from the name or subtitle (Apple indexes those already, so
"kids", "handwriting", "journal" and "words" are deliberately absent), no plurals (Apple
stems them), no spaces after commas — a space costs a character. **Do not** add competitor
names; Apple rejects listings that keyword-stuff other apps' trademarks.

### 1.4 Promotional Text — 170 char limit, editable without a review

```
Your child says what happened today. The words appear on the page. They write over them, the guide fades, and their own handwriting is left behind.
```
*(147)*

### 1.5 Description — 4000 char limit

```
Your child talks about their day. The words appear on a ruled page in big, friendly letters. They write over them — pencil or finger — and when a line is finished, the guide underneath goes away. What is left is their own handwriting, exactly where they wrote it.

Do that for a day and you have a page. Do it for a year and you have a journal in their own hand.

HOW IT WORKS

1. Talk. Tap the microphone and say what happened. Up to five minutes at a time, and stopping part-way is completely fine.
2. Write. The whole thing is laid out as one long page, and they work down it at their own pace.
3. Watch it mark itself. Ink inside the letter turns green, ink outside turns red — while they write, never afterwards.
4. Keep it. The finished page joins the journal, newest first, with the date and their voice attached.

WHY IT WORKS

Handwriting practice is dull. Journalling is not. Most tracing apps hand a child a word — cat, dog, ball. This one asks what happened to them and hands that back to be written. The sentence is worth writing because it is theirs, and the book that piles up is a real reward, not a sticker.

WHAT'S INSIDE

• Say it out loud — speech becomes words to trace, all on this iPad
• Marked letter by letter, so tracing half a letter scores like half a letter
• Stroke order taught, not just shape — a letter drawn backwards stops the page and teaches that one letter properly, then lets them carry on
• A practice sheet: every letter Aa to Zz and 0 to 9, each one drawing itself stroke by stroke with arrows to follow
• An eraser, an undo, and a scroll button, so the pencil never has to fight the page
• Their voice kept with the page — "Hear what I said", years later
• Badges, stars and a writing streak
• Read any entry as their handwriting or as typed words, one tap apart
• Export a single page, or the whole book, as a PDF for a grandparent
• Several children, one iPad — a profile each, with an optional PIN

FOR GROWN-UPS

You choose the letterform and the size, and they are settings, not rewards. Nothing has to be earned to make the letters bigger. Five typefaces — Jua, Andika, Baloo 2, Sniglet and Comic Neue — and five sizes, each previewed at its real size in its real face before you pick it. Andika is in the list because some children read it far more easily than anything else.

Progress is kept per setting, so if the score dips after you move to a smaller size, the chart shows you why instead of worrying you.

PRIVACY

Everything stays on this iPad. Speech is recognised on the device, the recordings are stored on the device, and there is no account, no sign-in, no analytics and no advertising. Nothing leaves unless a grown-up taps Share.

WHAT IT IS NOT

Not a curriculum. Not a reading app. Not a game with levels to unlock. Not online.

Made for children roughly five to eight who can speak in sentences and are learning to form their letters. iPad, held like a notebook.
```

### 1.6 What's New — 4000 char limit (version 1.0)

```
First release.

Say what happened today, write it on the page in your own hand, and keep it.

• Speak for up to five minutes; the words arrive on a ruled page ready to trace
• Green and red ink shows how the writing is going, letter by letter, as it happens
• Finish a line and the guide underneath disappears — the page is your handwriting now
• A letter drawn out of order gets taught on the spot, then you carry on
• A practice sheet for every letter and number, each one showing how it is written
• Badges, stars, streaks, and a journal that grows
• Export a page or the whole book as a PDF
• Everything stays on this iPad
```

For 1.x releases, keep the same shape: one plain sentence, then bullets. Do not write
"bug fixes and performance improvements" — this audience's grown-ups read release notes.

---

## 2. Categories, age rating, pricing

| Field | Value | Note |
|---|---|---|
| Primary category | **Education** | Where the whole competitive set lives (see `COMPETITION.md`). |
| Secondary category | **Kids → Ages 6–8** *(decision required — read §2.1)* | Or leave secondary empty and stay out of the Kids category entirely. |
| Age rating | **4+** — every questionnaire answer is "None"/"No" | No violence, no ads, no user-generated content shared anywhere, no web views, no gambling, no unrestricted web access. |
| Price | *Your decision* — the category norm is free with an unlock in the $3–$10 band | Whatever you pick, §1.5's copy must match: it currently claims no advertising, so do not add ads. |

### 2.1 The Kids Category decision — flag this before you submit

Listing in the **Kids** category buys you the best shelf for this app and triggers
App Store Review Guideline 1.3, which requires a **parental gate** in front of anything
that takes a child out of the app — including the share sheet — plus no third-party
analytics or advertising of any kind.

The app already clears the analytics and advertising half by construction (§10.1 of the
design doc: no network code at all). The problem is the other half: **the parent gate was
deliberately removed in v2.0** (`DESIGN_DOCUMENT.md` §10.3), and Export/Share is one tap
from a child's thumb, as are Delete Profile and Reset Progress.

Two honest options:

1. **List in Kids.** Put a gate back in front of Share/Export and the destructive Settings
   rows only — not in front of the app. This is the v1.0 blocker, and it is small.
2. **List in Education only.** No gate required, no guideline 1.3 exposure, and you lose
   the Kids shelf. §10.3 already records the ungated destructive actions as an accepted
   risk, so this ships today.

Either way, the recommendation in §10.3 stands independently: put a hold-to-confirm in
front of Delete Profile before this reaches a real child.

---

## 3. App Privacy ("nutrition label")

Answer: **Data Not Collected** — every category, every type.

Justification to have ready, because a reviewer may ask: the app contains no networking
code, no analytics SDK and no crash reporter; speech recognition runs with
`requiresOnDeviceRecognition = true`; audio, ink, photos and entries are written to local
storage only; the only egress is a PDF a grown-up creates through the system share sheet,
which is user-initiated and outside the app's collection.

A **Privacy Policy URL is still required** even when nothing is collected. Draft policy in
§8 — host it and paste the URL.

---

## 4. Permission strings (already shipping — reproduced for review)

These are set in `project.yml` and are already written for a child rather than an adult.
Do not let them drift out of sync with §1.5's privacy paragraph.

| Key | String |
|---|---|
| `NSMicrophoneUsageDescription` | Handwritten Journal listens so you can say your sentences out loud. Your voice stays on this iPad. |
| `NSSpeechRecognitionUsageDescription` | Handwritten Journal turns what you say into words you can trace. Everything happens on this iPad. |
| `NSCameraUsageDescription` | Take a photo for your profile. Photos stay on this iPad. |

The photo library needs no string — `PhotosPicker` does not prompt.

---

## 5. Screenshots

**Required:** iPad 13" display, **portrait** (2064 × 2752 or 2048 × 2732). No iPhone
screenshots are needed — the target is iPad-only. Up to 10; ship 8. Captions belong in the
image, not in a field.

| # | Frame | Caption |
|---|---|---|
| 1 | Writing page mid-sentence, guide plus live green ink | They say it. It appears. They write it. |
| 2 | The same page a few lines later, top lines graded and guide-free | Finish a line and the guide disappears |
| 3 | Close crop of a letter with green and red ink | Marked letter by letter, as they write |
| 4 | The remediation modal, one letter with its arrows | A letter drawn backwards gets taught on the spot |
| 5 | Journal home — badges, then entries newest first | A page a day becomes a book |
| 6 | Entry detail, Handwritten side of the toggle | Their handwriting, kept exactly as they wrote it |
| 7 | Practice sheet mid-demo, arrows on a letter | Every letter shows you how it is written |
| 8 | Settings — font picker with live previews | Five faces, five sizes. You choose, not a level. |

Caption voice: sentence case, no full stop unless there are two sentences, never
exclamation marks. First screenshot carries the whole idea on its own — most people never
swipe.

### 5.1 App Preview video (optional, 15–30s, portrait)

No voice-over, no music bed with lyrics, captions only:

1. (0–4s) Child taps the microphone, speaks. Text lands on the ruled page. *"Say what happened."*
2. (4–14s) Pencil traces a line, ink runs green. *"Write it in your own hand."*
3. (14–19s) The line finishes; the guide fades out from under the ink. *"The guide goes. Your writing stays."*
4. (19–26s) Journal home scrolls through a dozen dated pages. *"A year of days, in their own handwriting."*
5. (26–30s) Cover of the exported book PDF. *"Everything stays on your iPad."*

---

## 6. App Review Information — notes to the reviewer

```
Handwritten Journal is an offline iPad app for children aged roughly 5–8 who are learning to write. There is no account, no sign-in and no server, so no demo credentials are needed — launch it and create a profile.

HOW TO SEE THE MAIN FEATURE IN 60 SECONDS
1. On first launch, create a profile (a name is enough; the PIN and photo are optional).
2. Tap New Entry, then the microphone, and say a sentence out loud.
3. Tap stop. The sentence appears on a ruled page in large letters.
4. Trace over the letters with an Apple Pencil or a finger. Ink inside the letter is green, ink outside is red.
5. Finish a line and the guide text under it is removed, leaving only the tracing.

PLEASE TEST ON A PHYSICAL iPad. Dictation depends on the microphone and on on-device speech recognition, neither of which behaves normally in the Simulator. If the microphone is unavailable, the app falls back to a keyboard so the rest of the flow can still be reviewed.

PERMISSIONS
- Microphone and Speech Recognition: to turn what the child says into words to trace. A plain-language explainer screen is shown before the system prompt. Speech recognition runs on device (requiresOnDeviceRecognition = true).
- Camera: only when "Take Photo" is tapped for a profile picture. The photo library alternative uses PhotosPicker and prompts for nothing.
Refusing any permission leaves a working path: no microphone means the keyboard, no camera means the photo library or an initial-letter avatar.

PRIVACY
The app has no networking code of any kind — no analytics, no crash reporting, no ads, no account. Recordings, ink, photos and entries are stored locally. The only way anything leaves the device is a PDF a grown-up exports through the system share sheet.

ORIENTATION AND DEVICE
iPad only, portrait only, by design: the writing screen stacks a page above a writing line, and a child holds an iPad like a notebook.
```

If you list in the Kids category (§2.1), add one line naming where the parental gate sits.

---

## 7. Support and marketing pages

Both URLs are required fields. Minimum viable support page text:

```
Handwritten Journal — Support

Handwritten Journal is an iPad app for children who are learning to write. Your child says what happened today, the words appear on a ruled page, and they write over them in their own hand.

COMMON QUESTIONS

The microphone isn't working.
Open Settings › Privacy & Security › Microphone and check Journal is switched on. The same goes for Speech Recognition. Without the microphone your child can still type their sentence and write it exactly the same way.

Can more than one child use it?
Yes. Each child gets a profile with their own journal, font and size, and an optional four-digit PIN. A PIN keeps a sibling out; it is not encryption, and the app says so in Settings.

Where is our data?
On your iPad and nowhere else. There is no account and no server. Recordings and pages are deleted with the entry or the profile that holds them.

How do I print a page?
Open an entry, tap the ⋯ menu and choose Share as PDF. To export the whole book, use Export from the journal toolbar.

My child's score dropped.
Check whether the font size changed. Progress is tracked per setting for exactly this reason — a smaller letter is harder, and the chart shows each setting separately.

Contact: <your support email>
```

Marketing URL is optional in practice; if you have nothing to point at, leave it blank
rather than pointing it at a placeholder page, which reviewers do click.

---

## 8. Privacy policy — draft to host

```
Privacy Policy — Handwritten Journal
Last updated: <date>

Handwritten Journal does not collect any data.

The app has no user accounts, no servers and no networking code. It does not contain analytics, crash reporting or advertising software of any kind.

WHAT THE APP STORES ON YOUR DEVICE
- Profiles: a name, an optional photo, an optional PIN (stored only as a salted hash), and writing settings.
- Journal entries: the words your child spoke, the strokes they wrote, accuracy scores and dates.
- Audio: a recording of each dictation, kept so your child can hear what they said.

All of it is written to storage on your iPad and protected by iOS file protection. None of it is transmitted anywhere.

SPEECH RECOGNITION
Speech is converted to text using Apple's on-device speech recognition. The app requires on-device recognition, so the audio is not sent to Apple's servers for this purpose.

SHARING
The only way information leaves your device is if an adult exports a page or the journal as a PDF and shares it. What happens to that file afterwards is governed by whatever app or service you send it to.

DELETION
Deleting an entry deletes its writing, its scores and its recording. Deleting a profile deletes everything belonging to that profile. Deleting the app removes all of it.

CHILDREN
This app is designed for children. Because it collects nothing and transmits nothing, it does not knowingly or unknowingly collect personal information from anyone, of any age.

CONTACT
<your support email>
```

Legal review is your call, but the claims above are all checkable in the source and none
of them are hedged — keep it that way, and if networking is ever added, this file changes
in the same commit.

---

## 9. Pre-submission checklist

- [ ] **Decide the Kids category question** (§2.1) — and if yes, build the gate in front of Share/Export
- [ ] Hold-to-confirm on Delete Profile and Reset Progress (`DESIGN_DOCUMENT.md` §10.3)
- [ ] Confirm the pricing/IAP configuration matches §1.5's "no advertising" claim
- [ ] Verify the five bundled typefaces are licensed for app embedding and redistribution, and add any attribution their licences require to Settings › About
- [ ] Host the privacy policy (§8) and the support page (§7); paste both URLs
- [ ] Shoot 8 iPad 13" portrait screenshots per §5 with a profile whose handwriting looks like a real child's, not test ink
- [ ] Fill the App Privacy questionnaire as Data Not Collected (§3)
- [ ] Paste the review notes (§6) and confirm the build was tested on physical hardware
- [ ] Re-count §1.1–§1.4 after any edit — the subtitle is at exactly 30 characters

---

## 10. Character counts, as submitted

| Field | Limit | Used |
|---|---|---|
| App Name | 30 | 19 |
| Subtitle | 30 | **30** |
| Keywords | 100 | 97 |
| Promotional Text | 170 | 147 |
| Description | 4000 | 2870 |
| What's New (1.0) | 4000 | 520 |

Recount with:

```bash
python3 -c "import sys;t=sys.stdin.read().rstrip('\n');print(len(t))"
```
