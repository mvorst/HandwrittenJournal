# Go_To_Market

Everything needed to take Handwritten Journal 1.0 to market, drafted 2026-09-02. Start
with the plan; everything else hangs off it.

| File | What it is |
|---|---|
| `GO_TO_MARKET_PLAN.md` | Positioning, audiences, pricing recommendation, channels, launch calendar (September 2026 → Back to School 2027), metrics, budget, risks, and the decisions Matt needs to make |
| `MESSAGING.md` | The message in layers, audience-specific copy, proof points in exact wording, objections and answers, voice rules, boilerplate |
| `one-pagers/` | Print-ready US Letter PDFs for parents, schools, therapists, and a press fact sheet — HTML sources, one command to rebuild |
| `outreach/OUTREACH_TEMPLATES.md` | Emails for OTs, school pilots and administrators; press pitch; creator brief; Common Sense and App Store featuring submissions; community post; five social posts; the outreach log template |
| `screenshots/` | App Store screenshot set (eight captioned iPad 13-inch frames) plus every raw capture, and `SCREENSHOTS.md` on how they were made and what to reshoot on a device |
| `assets/` | App icon at 1024 and 512 px |
| `website/` | The marketing site — home, schools, specialists, press kit, support, privacy policy, terms of use — as editable sources plus a built `dist/` that any static host can serve. `website/README.md` has the build and deploy notes |

Companions elsewhere in the repo: `APP_STORE_LISTING.md` (every App Store field, review
notes, privacy policy, support page), `COMPETITION.md` (the landscape), `DESIGN_DOCUMENT.md`
(what the app does — the source of every claim here).

## Status

- **Ready to use now:** plan, messaging, outreach templates, one-pagers (as drafts marked
  with the date in the footer), and the website (`website/dist/`, once the App Store URL
  and domain are set in `website/site.config.json`).
- **Decided 2026-09-02:** the app is free; upgrades may be sold later. The plan's §4 has
  the principles that keep today's copy true when they arrive.
- **Placeholders to confirm before anything goes out:** the web address
  (`handwrittenjournal.app` is assumed, not registered), the support email, the pilot dates.
- **Reshoot on a real iPad before submission:** the writing-page screenshots (frames 1–3)
  and the App Preview video. The current set comes from the iPad simulator with
  synthesised handwriting — see `screenshots/SCREENSHOTS.md`.

## Regenerating

```bash
# one-pagers → PDF + PNG preview (needs Google Chrome)
Go_To_Market/one-pagers/build.sh

# App Store frames from the raw captures
python3 Go_To_Market/screenshots/compose_frames.py

# the website → website/dist/
python3 Go_To_Market/website/build.py --clean
```
