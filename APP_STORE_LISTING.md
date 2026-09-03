# App Store Listing — Handwritten Journal

Everything App Store Connect will ask for, written and ready to paste. Character limits
are noted against each field and every string below has been counted (§10 shows the
counts). Drafted 2026-09-01 against `DESIGN_DOCUMENT.md` v2.9 — if a feature changes,
change the copy here first.

Facts this copy is built on: iPad only (`TARGETED_DEVICE_FAMILY: 2`), portrait and
landscape, iOS 18.0 minimum, bundle `com.mattvorst.education.handwrittenjournal`,
home-screen name **Handwritten Journal**, on-device speech (`requiresOnDeviceRecognition = true`).
**Decided 2026-09-02, not yet in the build:** Apple Pencil is required; the app will send
anonymous crash reports and usage statistics; the basic app is always free and paid
features may come later (`DESIGN_DOCUMENT.md` §10.5). The copy below already says so.

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
4. Keep it. The finished page joins the journal, newest first, with the date and their voice attached.

WHY IT WORKS

Handwriting practice is dull. Journalling is not. Most tracing apps hand a child a word — cat, dog, ball. This one asks what happened to them and hands that back to be written. The sentence is worth writing because it is theirs, and the book that piles up is a real reward, not a sticker.

WHAT'S INSIDE

• Say it out loud — speech becomes words to trace, all on this iPad
• Marked letter by letter, so tracing half a letter scores like half a letter
• Stroke order taught, not just shape — a letter drawn backwards stops the page and teaches that one letter properly, then lets them carry on
• A practice sheet: every letter Aa to Zz and 0 to 9, each one drawing itself stroke by stroke with arrows to follow
• An eraser, an undo, and a scroll button, so the pencil never has to fight the page
• Badges, stars and a writing streak
• Read any entry as their handwriting or as typed words, one tap apart
• Export a single page, or the whole book, as a PDF for a grandparent
• Several children, one iPad — a profile each, with an optional PIN

FOR GROWN-UPS

You choose the letterform and the size, and they are settings, not rewards. Nothing has to be earned to make the letters bigger. Five typefaces — Jua, Andika, Baloo 2, Sniglet and Comic Neue — and five sizes, each previewed at its real size in its real face before you pick it. Andika is in the list because some children read it far more easily than anything else.

Progress is kept per setting, so if the score dips after you move to a smaller size, the chart shows you why instead of worrying you.

PRIVACY

Your child's journal stays on this iPad. Speech is recognised on the device and no audio is recorded or kept, and there is no account, no sign-in and no advertising. Nothing your child writes leaves unless a grown-up taps Share. The app sends anonymous crash reports and usage statistics so we can fix problems and improve it; they contain no journal content and no names, and we will never sell them.

FREE

The basic app is always free, because we want children to thrive. Some additional features may be paid, because we will never sell your data.

WHAT IT IS NOT

Not a curriculum. Not a reading app. Not a game with levels to unlock. Not online.

Made for children roughly five to eight who can speak in sentences and are learning to form their letters. iPad with Apple Pencil, held like a notebook. Requires Apple Pencil.
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
• Your child's writing stays on this iPad
• Requires Apple Pencil
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
| Price | **Free** *(decided 2026-09-02)* — "the basic app is always free"; no in-app purchases in 1.0; paid features may come later | §1.5 says so in those words and claims no advertising; keep both. If purchases arrive while the app is listed in Kids, they must sit behind a parental gate (Guideline 1.3). |

### 2.1 The Kids Category decision — flag this before you submit

Listing in the **Kids** category buys you the best shelf for this app and triggers
App Store Review Guideline 1.3, which requires a **parental gate** in front of anything
that takes a child out of the app — including the share sheet — plus no third-party
analytics or advertising of any kind.

The advertising half is clear by construction. **Analytics is not, any more:** the app
will send anonymous crash reports and usage statistics (`DESIGN_DOCUMENT.md` §10.5), and
Guideline 1.3 allows that in the Kids Category only if no personally identifiable
information or device information reaches a third party — so the analytics provider has
to be chosen with the Kids shelf in mind, or the Kids shelf given up. The other half is
unchanged: **the parent gate was deliberately removed in v2.0** (`DESIGN_DOCUMENT.md`
§10.3), and Export/Share is one tap from a child's thumb, as are Delete Profile and Reset
Progress.

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

*(Revised 2026-09-02 for the decision to collect crash reports and usage data.)*

Declare, under **Data Not Linked to You**, used for **Analytics** and **App Functionality**:

| Category | Data type | Note |
|---|---|---|
| Diagnostics | Crash Data | Stack traces, app version, device model, OS version |
| Diagnostics | Performance Data | Launch time, hangs, memory, if the provider reports them |
| Usage Data | Product Interaction | Screens and features used, session length |
| Identifiers | Device ID | Firebase's app-instance ID: random, per install, reset when the app is deleted. IDFV and the advertising identifier are not collected (`project.yml` Info.plist keys; `FirebaseAnalyticsCore`) |

Everything else stays **not collected**: no contact info, no user content (the journal
never leaves the device), no photos, no audio, no location, no financial info, no
browsing history. Tracking (as Apple defines it — linking to third-party data for
advertising, or sharing with data brokers): **No**, and the ATT prompt is therefore not
needed.

Justification to have ready: speech recognition runs with `requiresOnDeviceRecognition
= true`; ink, photos and entries are written to local storage only; the only egress of
user content is a PDF a grown-up creates through the system share sheet; crash and usage
data goes to Google (Google Analytics for Firebase, configured with no advertising
identifier, no IDFV and all advertising consent denied) under Google's data processing
terms and contains no content or identity. If only Apple's own App Store Connect crash logs and App Analytics are used
(no SDK), the label goes back to *Data Not Collected* — verify the current Apple guidance
before choosing that answer.

The **Privacy Policy URL** is `https://<domain>/privacy/` — the maintained policy lives
in `Go_To_Market/website/src/pages/privacy.html`; §8 below points there.

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
1. On first launch a short welcome appears once: tap "I agree" to the terms and privacy policy, choose whether the iPad talks ("Yes, talk to me" or "No thanks"), then trace the big A with an Apple Pencil and tap "Let's write" — or tap "I don't have an Apple Pencil" to carry on without one.
2. Create a profile (a name is enough; the PIN and photo are optional).
3. Tap New Entry, then the microphone, and say a sentence out loud.
4. Tap stop. The sentence appears on a ruled page in large letters.
5. Trace over the letters with an Apple Pencil. Ink inside the letter is green, ink outside is red.
6. Finish a line and the guide text under it is removed, leaving only the tracing.

PLEASE TEST ON A PHYSICAL iPad WITH AN APPLE PENCIL. The app requires Apple Pencil for writing. Dictation depends on the microphone and on on-device speech recognition, neither of which behaves normally in the Simulator. If the microphone is unavailable, the app falls back to a keyboard so the rest of the flow can still be reviewed.

PERMISSIONS
- Microphone and Speech Recognition: to turn what the child says into words to trace. A plain-language explainer screen is shown before the system prompt. Speech recognition runs on device (requiresOnDeviceRecognition = true).
- Camera: only when "Take Photo" is tapped for a profile picture. The photo library alternative uses PhotosPicker and prompts for nothing.
Refusing any permission leaves a working path: no microphone means the keyboard, no camera means the photo library or an initial-letter avatar.

PRIVACY
The child's journal — words, ink, photos, scores — is stored locally and never uploaded; the only way it leaves the device is a PDF a grown-up exports through the system share sheet. There is no account and no advertising. The app sends anonymous usage statistics to Google Analytics for Firebase, configured without any advertising identifier; they contain no user content and no identity, are used only to fix and improve the app, and are declared in the App Privacy section.

ORIENTATION AND DEVICE
iPad only, portrait and landscape, Apple Pencil required, by design: a child holds an iPad like a notebook and writes with a pencil.
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
Your child's journal is on your iPad and nowhere else. There is no account and no server holding a child's writing; pages are deleted with the entry or the profile that holds them. The app sends anonymous crash reports and usage statistics so we can improve it; they identify no one and are never sold.

Do I need an Apple Pencil?
Yes — any model your iPad supports.

How do I print a page?
Open an entry, tap the ⋯ menu and choose Share as PDF. To export the whole book, use Export from the journal toolbar.

My child's score dropped.
Check whether the font size changed. Progress is tracked per setting for exactly this reason — a smaller letter is harder, and the chart shows each setting separately.

Contact: <your support email>
```

Marketing URL is optional in practice; if you have nothing to point at, leave it blank
rather than pointing it at a placeholder page, which reviewers do click.

---

## 8. Privacy policy — maintained on the website

The policy is `Go_To_Market/website/src/pages/privacy.html`, published at `/privacy/`
by the site build. It was rewritten on 2026-09-02 for the decisions above and says, in
order: what stays on the iPad (the journal), what the app collects (anonymous crash
reports and usage statistics, with the exact fields), who processes it, the children's
paragraph (internal operations only, never advertising or profiling), speech,
permissions and sharing, deletion, "we will never sell your data", purchases, the
website's Google Analytics, changes, contact. Two placeholders in
`website/site.config.json` must be filled before it is published: the analytics
provider and the retention period.

Legal review is still your call. The claims are written to match how the app will work
once §10.5 of the design document is built — if the analytics design changes, this policy
changes in the same commit.

---

## 9. Pre-submission checklist

- [ ] **Decide the Kids category question** (§2.1) — and if yes, build the gate in front of Share/Export
- [ ] Hold-to-confirm on Delete Profile and Reset Progress (`DESIGN_DOCUMENT.md` §10.3)
- [ ] Set the price to Free in App Store Connect; no in-app purchases configured for 1.0
- [x] Build the usage analytics (`DESIGN_DOCUMENT.md` §10.5) — Google Analytics for Firebase, 2026-09-02; the provider is named here, in the review notes and in the policy
- [ ] Decide crash reporting (Crashlytics or Apple's crash logs) and, if Crashlytics, add it to the review notes and the policy
- [ ] Remove or hide the finger-tracing switch; confirm "Requires Apple Pencil" is in the description
- [ ] Verify the five bundled typefaces are licensed for app embedding and redistribution, and add any attribution their licences require to Settings › About
- [ ] Publish the website (`Go_To_Market/website/`) with the privacy policy and support page; paste `/privacy/` and `/support/`
- [ ] Shoot 8 iPad 13" portrait screenshots per §5 with a profile whose handwriting looks like a real child's, not test ink
- [ ] Fill the App Privacy questionnaire per §3 — Diagnostics and Usage Data, not linked, no tracking
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
| Description | 4000 | 3229 |
| What's New (1.0) | 4000 | 660 |

Recount with:

```bash
python3 -c "import sys;t=sys.stdin.read().rstrip('\n');print(len(t))"
```
