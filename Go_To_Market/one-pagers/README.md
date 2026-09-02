# One-pagers

Four print-ready US Letter pages, one per audience. Edit the HTML, run `build.sh`, and the
PDFs and the PNG previews in `preview/` are rebuilt with headless Google Chrome.

| Audience | Source | Output |
|---|---|---|
| Parents and grandparents | `Parents.html` | `Parents.pdf` |
| K–2 teachers and school leaders | `Schools.html` | `Schools.pdf` |
| Occupational therapists, tutors, specialists | `Therapists.html` | `Therapists.pdf` |
| Press and reviewers | `Press-Fact-Sheet.html` | `Press-Fact-Sheet.pdf` |

Shared styling is in `onepager.css` (the app's own palette from `STYLE_GUIDE.md`). Images
in `img/` are downscaled copies of `../screenshots/raw/`; refresh them after a reshoot with
`sips -Z 1200`.

## Before printing or sending

- Replace the **web address and email** — `handwrittenjournal.app` is a placeholder.
- Set the **pilot dates** on the schools page.
- Swap the simulator screenshots for device captures and delete the draft line in the
  footer of each page (`.draft` in the HTML).
- Replace the black "Download on the App Store" pill with Apple's official badge artwork
  once the app is live (Apple's marketing guidelines require the official badge).

## Rebuilding

```bash
Go_To_Market/one-pagers/build.sh
```
