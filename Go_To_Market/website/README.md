# Website

The marketing site for Handwritten Journal: a home page, pages for schools, specialists and
press, a support page, a privacy policy and terms of use. **Entirely static** — HTML, one
minified stylesheet, one minified script, images and PDFs. No server-side code, no forms,
no cookies, no analytics, no third-party requests; the site keeps the app's own privacy
promise.

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

## Before it goes live

- `site.config.json`: the real **App Store URL** (the placeholder id is zeros), the
  **domain**, and the **support email**. Rebuild.
- `src/pages/terms.html` §13: fill in the **governing-law state**. §5 commits that written
  pages will never sit behind a future purchase — keep it or remove it, but decide.
- Have a lawyer read the privacy policy and the terms. They are plain-language drafts
  written to match how the app actually works (`APP_STORE_LISTING.md` §8 is the source).
- The App Store listing needs the privacy URL (`/privacy/`) and the support URL
  (`/support/`); the marketing URL is the home page.
- Replace the simulator screenshots in `../screenshots/raw/` with device captures and
  rebuild; the site picks them up automatically.

## The hero animation

The page in the hero is the app's own: `src/hero/glyphs.json` holds Jua's letter outlines
at 72 pt as SVG paths (extracted with CoreText by `tools/glyph_paths.swift`), and
`src/hero/hero-data.json` holds the glyph positions and the synthesised child's strokes the
screenshots were made with. `build.py` turns them into one inline SVG; `site.js` runs the
cycle — words land, ink draws in green, the line settles to graphite — and holds still when
the visitor prefers reduced motion or the hero is off screen.

To change the sentence, launch the app with `-dumpStrokes YES` (see
`../screenshots/SCREENSHOTS.md`), slim the dump as `hero-data.json`, and re-run the Swift
script with the new text.
