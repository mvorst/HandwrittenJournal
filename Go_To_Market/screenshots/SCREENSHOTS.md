# Screenshots

Two sets. `raw/` is every screen captured from the iPad simulator at native resolution;
`app-store/` is the eight-frame App Store set built from them, captioned in the image as
`APP_STORE_LISTING.md` §5 specifies. Everything is iPad 13-inch portrait, 2064 × 2752 —
the size App Store Connect requires — except the three landscape captures, which are
2752 × 2064.

**These are drafts.** The handwriting on every page is synthesised by the DEBUG demo
harness (`DemoData.swift`), which writes each letter along its taught formation with a
wobbling hand, and the live green ink was replayed as real touches from those same paths.
It reads as a careful six-year-old's print, which is the point, but it is not a child.
Before submission, reshoot frames 1–3 (and the App Preview video) on a physical iPad with a
real child's hand and Apple Pencil; the other five frames can stay as they are if the UI
has not changed.

## The App Store set (`app-store/`)

| # | File | Frame | Caption |
|---|---|---|---|
| 1 | `01.png` | Writing page mid-sentence: settled lines above, live green ink on the row in hand, spoken words pale below | They say it. It appears. They write it. |
| 2 | `02.png` | The same page a line later, the finished line settled to graphite, the next row in hand | Finish a line and the guide disappears |
| 3 | `03.png` | Close crop of "The" with green and red ink | Marked letter by letter, as they write |
| 4 | `04.png` | The remediation card — "Let's practice little i!", the word with the letter in red, the letter drawing itself | A letter drawn backwards gets taught on the spot |
| 5 | `05.png` | Journal home — action deck, points card, badges, entries with handwriting thumbnails | A page a day becomes a book |
| 6 | `06.png` | Entry detail, the child's handwriting on the ruled page | Their handwriting, kept exactly as they wrote it |
| 7 | `07.png` | Practice sheet, with today's earned letters in green and orange | Every letter shows you how it is written |
| 8 | `08.png` | Settings › Font, each face previewed at real size | Five faces, five sizes. You choose, not a level |

Rebuild after changing a raw capture or a caption:

```bash
python3 Go_To_Market/screenshots/compose_frames.py        # all eight
python3 Go_To_Market/screenshots/compose_frames.py 3 5    # just these
```

The composer needs Google Chrome; captions are set in `FRAMES` at the top of the script.

## Every raw capture (`raw/`)

| File | Screen | How it was reached |
|---|---|---|
| `01-writing-live.png` | Editor, "The dog wa" in green | Unfinished fixture › Write on this page › replayed strokes |
| `02-writing-settled.png` | Editor, line 3 settled, line 4 in hand | After the whole line and the lesson |
| `03-remediation.png` | Remediation card, letter demonstrated | The "i" of "with" was judged out of order |
| `03b-remediation-done.png` | Remediation card after a correct trace — *I did it — keep writing* | Traced the letter inside the card |
| `04-journal-home.png` | Journal Home | `-screen journal` |
| `05-entry-detail.png` | Entry detail, "I saw a red bird…" | Tap the entry |
| `06-practice-sheet.png` | Practice sheet | `-screen practice` |
| `07-settings.png` | Settings sheet | `-screen settings` |
| `07-settings-fonts.png` | Font picker | Settings › Font |
| `08-results.png` | Results — 98%, +228 points, new badge | *I'm finished* |
| `09-progress.png` | Progress sheet — accuracy over time, by mode and font | `-screen progress` |
| `10-profile-picker.png` | Profile picker | `-seed YES` with no `-screen` |
| `11-landscape-journal.png` | Journal Home, landscape (two columns) | Device rotated, `-screen journal` |
| `12-landscape-entry.png` | Entry detail, landscape (side column) | Device rotated, `-screen trace` |
| `13-export.png` | Export sheet over the entry | Entry › Share |
| `14-new-entry-stage.png` | New entry, the stage with the one microphone | `-screen write` |
| `15-landscape-practice.png` | Practice sheet, landscape | Device rotated, `-screen practice` |
| `16-writing-green-red.png` | Editor, "The" with the h deliberately off its stem | Replayed with a 12 pt offset |

## How the captures were made (to repeat them)

1. **Build and install** the Debug app on the *iPad Pro 13-inch (M5)* simulator
   (`xcodebuild build … -destination 'platform=iOS Simulator,id=<udid>'`, then
   `xcrun simctl install`).
2. **Seed and jump:** `xcrun simctl launch <udid> com.mattvorst.education.handwrittenjournal
   -seed YES -screen journal` (`BUILD_LOG.md` › Debug harness lists every screen). The seed
   is deterministic — the same text always produces the same handwriting.
3. **Capture** with `xcrun simctl io <udid> screenshot file.png` — native 2064 × 2752.
4. **Live ink** is real touch input. Launch once with `-dumpStrokes YES`; the app writes
   `Documents/demo_strokes.json` (find it with `xcrun simctl get_app_container <udid>
   <bundle> data`) holding every glyph box and every synthesised stroke for the unfinished
   fixture's page, in canvas points. On this device the writing canvas maps to the screen
   as **x → x, y → y + 104** when the page is unscrolled; feed each stroke to the
   simulator's touch injection as a path. Shifting a stroke sideways by ~12 pt puts it
   outside the letterform and turns it red.
5. **Landscape:** rotate the *device* (Simulator › Device › Rotate Left, with that
   simulator's window frontmost) before launching, and launch without `-orientation`.
   `simctl io screenshot` then returns the framebuffer in the portrait frame with the UI
   turned sideways; rotate the PNG a quarter turn (PIL `rotate(90, expand=True)` when the
   status bar sits on the right edge) to get the 2752 × 2064 image. Launching with
   `-orientation landscape` while the device is in portrait makes iPadOS 26 present the app
   as a floating window — and the window state then sticks to the app until the simulator
   is erased.
6. **Compose** with `compose_frames.py`.

## What still needs a real iPad

- Frames 1–3 with a real child's writing and a Pencil.
- The 30-second App Preview (storyboard in `APP_STORE_LISTING.md` §5.1).
- A landscape writing-page capture with the rail (v3.3) — needs the unfinished entry
  opened by hand while rotated.
