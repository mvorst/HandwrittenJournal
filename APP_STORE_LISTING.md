# App Store Listing — Handwritten Journal

Everything App Store Connect will ask for, written and ready to paste. Character limits
are noted against each field and every string below has been counted (§10 shows the
counts). Drafted 2026-09-01 against `DESIGN_DOCUMENT.md` v2.9 and brought up to v3.8 on
2026-09-03 — if a feature changes, change the copy here first.

Facts this copy is built on: iPad only (`TARGETED_DEVICE_FAMILY: 2`), portrait and
landscape, iOS 18.0 minimum, bundle `com.mattvorst.education.handwrittenjournal`,
home-screen name **Handwritten Journal**, on-device speech (`requiresOnDeviceRecognition = true`),
English only, no audio recorded or kept (v3.0), five faces — Jua, Andika, Varela Round,
Sniglet, Comic Neue — and five sizes, points per letter and per word (v3.5), crayons and
the ABC word-fix tool (v3.2), an optional recorded voice (v3.4, clips since v3.7), a
practice sheet with a blue start dot and a how-to card (v3.8). The website is live at
`https://handwrittenjournal.app` with the privacy policy, support page and terms
(2026-09-02).
**Decided 2026-09-04:** the app is designed for Apple Pencil, keeps all app data on the
iPad, and uses no analytics or crash-reporting SDK. The basic app is always free and paid
features may come later. Since v3.6 the welcome explains why Apple Pencil matters before
it lets anyone skip — *I don't have an Apple Pencil* opens the explanation, and a skip
lasts one launch.

---

## 1. Product page — the fields

### 1.1 App Name — 30 char limit

```
Handwritten Journal
```
*(19)* — The home-screen name is also `Handwritten Journal`. It was `Journal` until
2026-09-02, when App Store Connect rejected builds 1 and 2 with ITMS-90129 ("bundle name or
display name already taken" — it is Apple's own Journal app). If the App Store name is taken
at submission, fall back to
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
Your child talks about their day. The words appear on a ruled page in big, friendly letters. They write over them with Apple Pencil, and when a line is finished, the guide underneath goes away. What is left is their own handwriting, exactly where they wrote it.

Do that for a day and you have a page. Do it for a year and you have a journal in their own hand.

HOW IT WORKS

1. Talk. Tap the microphone and say what happened. Up to five minutes at a time, and stopping part-way is completely fine.
2. Write. The whole thing is laid out as one long page, and they work down it at their own pace.
3. Watch it mark itself. Ink inside the letter turns green, ink outside turns red — while they write, never afterwards.
4. Keep it. The finished page joins the journal, newest first, with its date and the points it earned.

WHY IT WORKS

Handwriting practice is dull. Journalling is not. Most tracing apps hand a child a word — cat, dog, ball. This one asks what happened to them and hands that back to be written. The sentence is worth writing because it is theirs, and the book that piles up is a real reward, not a sticker.

WHAT'S INSIDE

• Say it out loud — speech becomes words to trace, all on this iPad, and a misheard word is fixed with a tap before it is written
• Marked letter by letter, so tracing half a letter scores like half a letter
• Stroke order taught, not just shape — a letter drawn backwards stops the page and teaches that one letter properly, then lets them carry on
• A practice sheet: every letter Aa to Zz and 0 to 9, each one drawing itself stroke by stroke, with a blue dot where to start and arrows to follow
• An eraser, an undo, and a scroll button, so the pencil never has to fight the page
• Crayons for doodling anywhere on the page — never marked, always kept
• A voice, if you want one, that says when it is their turn, names the letter to trace and cheers a finished line — it never reads the journal aloud
• Points for every letter and every whole word, stars, badges and a writing streak
• Every page kept exactly as they wrote it, and shown in their own hand in the journal
• Export a single page, or the whole book, as a PDF for a grandparent
• Several children, one iPad — a profile each, with an optional PIN

FOR GROWN-UPS

You choose the letterform and the size, and they are settings, not rewards. Nothing has to be earned to make the letters bigger. Five typefaces — Jua, Andika, Varela Round, Sniglet and Comic Neue — and five sizes, each previewed at its real size in its real face before you pick it. Andika is in the list because some children read it far more easily than anything else.

Progress is kept per setting, so if the score dips after you move to a smaller size, the chart shows you why instead of worrying you.

PRIVACY

Your child's journal stays on this iPad. Speech is recognised on the device and no audio is recorded or kept, and there is no account, no sign-in, no advertising, no analytics and no crash reporting. Nothing your child writes leaves unless a grown-up taps Share. We will never sell their data.

FREE

The basic app is always free, because we want children to thrive. Some additional features may be paid, because we will never sell your data.

WHAT IT IS NOT

Not a curriculum. Not a reading app. Not a game with levels to unlock. Not online.

Made for children roughly five to eight who can speak in sentences and are learning to form their letters. iPad with iOS 18 or later, held like a notebook. Designed for Apple Pencil.
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
• Crayons for doodling, and a voice that cheers a finished line if you want one
• Points, stars, badges, streaks, and a journal that grows
• Export a page or the whole book as a PDF
• Your child's writing stays on this iPad
• Designed for Apple Pencil
```

For 1.x releases, keep the same shape: one plain sentence, then bullets. Do not write
"bug fixes and performance improvements" — this audience's grown-ups read release notes.

---

## 2. Categories, age rating, pricing

| Field | Value | Note |
|---|---|---|
| Primary category | **Education** | Where the whole competitive set lives (see `COMPETITION.md`). |
| Secondary category | **Kids → Ages 6–8** | The app is designed specifically for this audience. |
| Age rating | **4+** — every questionnaire answer is "None"/"No" | No violence, no ads, no user-generated content shared anywhere, no web views, no gambling, no unrestricted web access. |
| Price | **Free** *(decided 2026-09-02)* — "the basic app is always free"; no in-app purchases in 1.0; paid features may come later | §1.5 says so in those words and claims no advertising; keep both. If purchases arrive while the app is listed in Kids, they must sit behind a parental gate (Guideline 1.3). |

### 2.1 The Kids Category decision — flag this before you submit

Listing in the **Kids** category triggers App Store Review Guideline 1.3, which requires
a **parental gate** in front of anything that takes a child out of the app — including the
share sheet — and prohibits third-party advertising and device-data analytics.

This build contains no advertising, analytics, or crash-reporting SDK and sends no app
data to third parties. It still needs a parental gate before sharing a PDF, opening an
external website, or requesting a permission. The currently ungated Share/Export and
Settings actions remain the v1.0 blocker.

---

## 3. App Privacy ("nutrition label")

Declare **Data Not Collected** and **Tracking: No**. The app stores profiles, journal
entries, photos, and speech transcripts only on the iPad; it uses no third-party analytics
or crash reporting. On-device speech recognition uses
`requiresOnDeviceRecognition = true`; the only user-controlled egress is a PDF shared
through the system share sheet. Apple's optional Analytics & Improvements data is not
developer-collected data for this questionnaire.

The **Privacy Policy URL** is `https://handwrittenjournal.app/privacy/` — live since
2026-09-02; the maintained policy lives in `Go_To_Market/website/src/pages/privacy.html`;
§8 below points there.

---

## 4. Permission strings (already shipping — reproduced for review)

These are set in `project.yml` and localised in `Resources/InfoPlist.xcstrings` (v3.7),
and are already written for a child rather than an adult. Do not let them drift out of
sync with §1.5's privacy paragraph.

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
| 5 | Journal home — the action deck and points card, badges, then entries newest first with their handwriting thumbnails | A page a day becomes a book |
| 6 | Entry detail, Handwritten side of the toggle | Their handwriting, kept exactly as they wrote it |
| 7 | Practice sheet mid-demo, blue start dot and arrows on a letter | Every letter shows you how it is written |
| 8 | Settings — font picker with live previews | Five faces, five sizes. You choose, not a level. |

Caption voice: sentence case, no full stop unless there are two sentences, never
exclamation marks. First screenshot carries the whole idea on its own — most people never
swipe.

A draft set of all eight exists in `Go_To_Market/screenshots/app-store/` (2026-09-02,
simulator captures with synthesised handwriting; `SCREENSHOTS.md` there says how each was
made). Frames 1–3 are to be reshot on a physical iPad with a real child's hand; the other
five can ship as they are if the screens have not changed.

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
1. On first launch a short welcome appears once: tap "I agree" to the terms and privacy policy, choose whether the iPad talks ("Yes, talk to me" or "No thanks, stay quiet"), then trace the big A with an Apple Pencil and tap "Let's write". Without a Pencil, tap "I don't have an Apple Pencil": it explains why the app needs one (this is a handwriting app), and "Skip for now" carries on; the pencil check returns at the next launch until a Pencil has traced the letter.
2. Create a profile (a name is enough; the PIN and photo are optional).
3. Tap New Entry, then the big microphone on the page, and say a sentence out loud.
4. Tap the same microphone again to stop. The sentence appears on a ruled page in large letters. If you chose "Yes, talk to me", a short recorded voice says it is your turn — every voice line is a bundled audio clip; nothing is synthesised or downloaded.
5. Trace over the letters with an Apple Pencil. Ink inside the letter is green, ink outside is red.
6. Finish a line and the guide text under it is removed, leaving only the tracing.

PLEASE TEST ON A PHYSICAL iPad WITH AN APPLE PENCIL. The app is designed for Apple Pencil. Dictation depends on the microphone and on on-device speech recognition, neither of which behaves normally in the Simulator. If the microphone is unavailable, the app falls back to a keyboard so the rest of the flow can still be reviewed.

PERMISSIONS
- Microphone and Speech Recognition: to turn what the child says into words to trace. A plain-language explainer screen is shown before the system prompt. Speech recognition runs on device (requiresOnDeviceRecognition = true).
- Camera: only when "Take Photo" is tapped for a profile picture. The photo library alternative uses PhotosPicker and prompts for nothing.
Refusing any permission leaves a working path: no microphone means the keyboard, no camera means the photo library or an initial-letter avatar.

PRIVACY
The child's journal — words, ink, photos, scores — is stored locally and never uploaded; the only way it leaves the device is a PDF a grown-up exports through the system share sheet. There is no account, advertising, analytics, or crash reporting.

ORIENTATION AND DEVICE
iPad only, portrait and landscape, designed for Apple Pencil: a child holds an iPad like a notebook and writes with a pencil.
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
Open the iPad's Settings › Privacy & Security › Microphone and check that Handwritten Journal is switched on. The same goes for Speech Recognition, just below it. Without the microphone your child can still type their sentence with Type it instead and write it exactly the same way.

The words came out wrong.
Speech recognition on young voices is imperfect. The spoken words stay editable until they are written: tap the Abc tool on the writing page, then the word, and fix it. A misheard word never has to enter the journal.

Can more than one child use it?
Yes. Each child gets a profile with their own journal, font and size, and an optional four-digit PIN. A PIN keeps a sibling out; it is not encryption, and the app says so in Settings.

Where is our data?
Your child's journal is on your iPad and nowhere else. There is no account, advertising, analytics, or server holding a child's writing; pages are deleted with the entry or the profile that holds them.

Do I need an Apple Pencil?
Handwritten Journal is designed for Apple Pencil — any model your iPad supports. The first time it runs it asks your child to trace a letter with a pencil, and if there isn't one to hand it explains why it matters and which pencils fit your iPad. You can skip that for now and set up; it asks again the next time the app opens.

How do I print a page?
Open the entry, tap Share (or the ⋯ menu, then Share as PDF), choose This entry and print from the share sheet. The same sheet exports This month or Everything — the whole book as one PDF, which is also the backup: there is no cloud sync in this version.

My child's score dropped.
Check whether the font size changed. Progress is tracked per setting for exactly this reason — a smaller letter is harder, and the chart shows each setting separately.

Contact: hello@handwrittenjournal.app
```

The live page is `https://handwrittenjournal.app/support/` (source
`Go_To_Market/website/src/pages/support.html`), and that is the **Support URL**. The
**Marketing URL** is `https://handwrittenjournal.app/`. Keep the text above and the page
in step.

---

## 8. Privacy policy — maintained on the website

The policy is `Go_To_Market/website/src/pages/privacy.html`, published at `/privacy/`
by the site build. It describes local-only app storage, on-device speech, permissions and
sharing, deletion, purchases, and the static website's no-analytics policy. The terms of
use sit beside it at `/terms/`; the app opens both from the welcome and from Settings ›
Legal (`Onboarding.termsURL`, `Onboarding.privacyURL`), so the two URLs must not move.

Legal review is still your call. If the app later adds any third-party service or changes
how it handles data, update this policy and the App Privacy answers in the same change.

---

## 9. Pre-submission checklist

- [x] Select **Made for Kids → Ages 6–8** in App Store Connect
- [ ] Add a parental gate before Share/Export, external links, and permission requests (§2.1)
- [ ] Hold-to-confirm on Delete Profile and Reset Progress (`DESIGN_DOCUMENT.md` §10.3)
- [x] Set the price to Free in App Store Connect; no in-app purchases configured for 1.0
- [x] Remove third-party analytics and crash-reporting SDKs, and select Data Not Collected
- [x] Update the description, review notes, support page, and website to say **Designed for Apple Pencil**
- [x] Typeface licences verified — all five faces are SIL Open Font License 1.1 (`Resources/Fonts/LICENSES.md`, which ships in the bundle, so the notice travels with the fonts); a line in Settings › Legal is optional
- [ ] Decide the Handwritten/Typed reading toggle (`DESIGN_DOCUMENT.md` §4.7): the build has none — Entry Detail replays the handwriting and shows text only for an entry with no ink — so the bullet came out of §1.5 on 2026-09-03; build it or drop it from the design document
- [x] Website published 2026-09-02 (`Go_To_Market/website/`, deployed with `Website/deploy.sh --build`) — paste `https://handwrittenjournal.app/privacy/` and `https://handwrittenjournal.app/support/`, Marketing URL `https://handwrittenjournal.app/`
- [ ] Reshoot §5 frames 1–3 (and the App Preview) on a physical iPad with a real child's hand; the draft set in `Go_To_Market/screenshots/app-store/` covers the rest
- [ ] Fill the App Privacy questionnaire per §3 — Data Not Collected, no tracking
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
| Description | 4000 | 3610 |
| What's New (1.0) | 4000 | 748 |

Recount with:

```bash
python3 -c "import sys;t=sys.stdin.read().rstrip('\n');print(len(t))"
```
