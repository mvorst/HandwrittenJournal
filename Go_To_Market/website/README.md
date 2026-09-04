# Website

The marketing site for Handwritten Journal: a home page, pages for schools, specialists and
press, a support page, a privacy policy and terms of use. **Entirely static** — HTML, one
minified stylesheet, one minified script, images and PDFs. No server-side code, forms,
analytics, or third-party tracking scripts.

```
website/
  site.config.json   ← site URL, App Store URL, support email, developer, dates
  src/
    pages/           ← one file per page; a header block, then the page body
    partials/        ← head.html (everything before <main>) and foot.html (footer, script)
    css/site.css     ← the stylesheet, readable; minified at build
    js/site.js       ← navigation toggle + the hero animation; minified at build
    hero/            ← the hero page's data: the app's Jua glyph outlines and stroke paths
  build.py           ← builds dist/ (Python 3 + Pillow; Chrome optional for the OG image)
  tools/             ← glyph_paths.swift, which produced src/hero/glyphs.json with CoreText
  dist/              ← the deployable site (regenerated; safe to delete)
```

## Build

```bash
python3 Go_To_Market/website/build.py --clean
```

Then upload `dist/` to any static host. Clean URLs are directories (`/privacy/index.html`),
which every static host serves as `/privacy/`.

| Host | Notes |
|---|---|
| Cloudflare Pages / Netlify / Vercel | Point at `dist/` (or run `build.py` as the build command); custom domain and HTTPS are automatic |
| GitHub Pages | Publish `dist/` from a branch; for a project site under a subpath set `"root": "/repo-name/"` in `site.config.json` |
| Amazon S3 + CloudFront | Static website hosting with `index.html` as the index document and `404.html` as the error document; CloudFront for HTTPS |

This site is deployed to the S3 + CloudFront stack in this account with `Website/deploy.sh`
(`--build` rebuilds first); the hosting details, URL rules and the domain steps are in
[`../../Website/README.md`](../../Website/README.md).

## The App Store badge

`src/assets/app-store-badge-black.svg` and `-white.svg` are Apple's own artwork, fetched
from Apple's badge service, and are used the way Apple's marketing guidelines ask: only as
the link to the App Store page, never recolored or reshaped, at least 40 px tall on
screen (56 px in the hero), with clear space of a quarter of the badge height on every side
(`.badge-link` in the stylesheet), and with the trademark line in the footer. Re-read the
guidelines at developer.apple.com/app-store/marketing/guidelines/ before launch; the
badge may only be shown once the app is live, or with "Coming soon" wording Apple permits.

## Before it goes live

- `site.config.json`: the **domain** and **support email** if they change (the App Store
  URL is the real one, id 6807460004). Rebuild.
- `src/pages/terms.html` §13 names Ohio as the governing law. §5 commits that written
  pages will never sit behind a future purchase — keep it or remove it, but decide.
- Have a lawyer read the privacy policy and the terms, particularly the children's
  privacy obligations in the markets where the app is available.
- The App Store listing needs the privacy URL (`/privacy/`) and the support URL
  (`/support/`); the marketing URL is the home page.
- Replace the simulator screenshots in `../screenshots/raw/` with device captures and
  rebuild; the site picks them up automatically.

## The hero animation

The page in the hero is the app's own: `src/hero/glyphs.json` holds Jua's letter outlines
at 72 pt as SVG paths (extracted with CoreText by `tools/glyph_paths.swift`), and
`src/hero/hero-data.json` holds the glyph positions and the synthesized child's strokes the
screenshots were made with. `build.py` turns them into one inline SVG; `site.js` runs the
cycle — words land, ink draws in green, the line settles to graphite — and holds still when
the visitor prefers reduced motion or the hero is off screen.

To change the sentence, launch the app with `-dumpStrokes YES` (see
`../screenshots/SCREENSHOTS.md`), slim the dump as `hero-data.json`, and re-run the Swift
script with the new text.
