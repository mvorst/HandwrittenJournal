#!/usr/bin/env python3
"""Build the Handwritten Journal website into dist/ — a fully static site.

    python3 build.py            # writes dist/
    python3 build.py --clean    # wipes dist/ first

No dependencies beyond Python 3 and Pillow (for the images). Google Chrome, if present,
renders the Open Graph card; the build succeeds without it.

What it does:
  1. Wraps each page in src/pages/ with the head and foot partials and substitutes
     {{VARIABLES}} from site.config.json (plus TITLE / DESCRIPTION / PATH from the page's
     own header block).
  2. Minifies src/css/site.css and src/js/site.js into content-hashed files.
  3. Generates the animated hero page (inline SVG) from src/hero/ — the app's real letter
     outlines and the same synthesised strokes used for the screenshots.
  4. Resizes the screenshots in ../screenshots/raw/ for the web (PNG + WebP), exports the
     icon at the needed sizes, and copies the one-pager PDFs into dist/downloads/.
  5. Writes sitemap.xml, robots.txt and a 404 page.
"""
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")
DIST = os.path.join(HERE, "dist")
GTM = os.path.dirname(HERE)
RAW = os.path.join(GTM, "screenshots", "raw")
ICON = os.path.join(GTM, "assets", "app-icon-1024.png")
PDFS = os.path.join(GTM, "one-pagers")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

with open(os.path.join(HERE, "site.config.json")) as f:
    CONFIG = json.load(f)


# ----------------------------------------------------------------------------- minify
def minify_css(css):
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    css = re.sub(r"\s+", " ", css)
    css = re.sub(r"\s*([{};:,>])\s*", r"\1", css)
    css = css.replace(";}", "}")
    return css.strip()


def minify_js(js):
    js = re.sub(r"/\*.*?\*/", "", js, flags=re.S)
    lines = []
    for line in js.splitlines():
        line = re.sub(r"(^|\s)//.*$", "", line).strip()  # line comments (none of ours sit in strings)
        if line:
            lines.append(line)
    return "\n".join(lines)


def hashed(name, ext, content):
    digest = hashlib.sha256(content.encode()).hexdigest()[:8]
    return f"{name}.{digest}.{ext}"


# ----------------------------------------------------------------------------- hero
def hero_svg():
    with open(os.path.join(SRC, "hero", "hero-data.json")) as f:
        data = json.load(f)
    with open(os.path.join(SRC, "hero", "glyphs.json")) as f:
        glyphs = json.load(f)["glyphs"]

    width = data["width"]
    baselines = data["baselines"]
    ascent, descent = data["ascent"], data["descent"]
    inset = data["surfaceInset"]
    top, height = 24, 330
    out = [f'<svg class="hero-page" viewBox="0 {top} {width} {height}" role="img" '
           f'aria-label="The writing page: the child\'s words land on a ruled page, the ink is marked green as it is written, '
           f'and the finished line becomes their handwriting." data-write-end="{{WRITE_END}}">']

    # Ruled paper: dashed ascender and descender lines, a solid baseline.
    out.append('<g class="rules">')
    for b in baselines:
        for y, cls in ((b - ascent, "rule dashed"), (b, "rule"), (b + descent, "rule dashed")):
            out.append(f'<line class="{cls}" x1="{inset}" y1="{y:.1f}" x2="{width - inset}" y2="{y:.1f}"/>')
    out.append('</g>')

    # The guide text, one group per row, staggered by word so the words "land".
    rows = {}
    for g in data["glyphs"]:
        rows.setdefault(g["line"], []).append(g)
    for line in sorted(rows):
        cls = "guide row-%d%s" % (line, "" if line == 0 else " spoken")
        out.append(f'<g class="{cls}">')
        for g in rows[line]:
            if g["c"].strip() == "" or g["c"] not in glyphs:
                continue
            delay = 0.07 * g["word"]
            out.append(f'<path d="{glyphs[g["c"]]}" transform="translate({g["x"]:.2f} {baselines[line]})" style="--d:{delay:.2f}s"/>')
        out.append('</g>')

    # The row marker (a small pencil in the margin) and the handles of the rows below.
    out.append(f'<g transform="translate(12 {baselines[0] - 30})"><path class="marker" d="M2 18 L14 6 L18 10 L6 22 L1 23 Z M15 5 L17 3 L21 7 L19 9 Z"/></g>')
    for b in baselines[1:]:
        out.append(f'<circle class="handle" cx="21" cy="{b - 20}" r="2.6"/>')

    # The ink: one path per stroke, drawn in order with a pen-lift between strokes.
    speed, lift, word_gap = 240.0, 0.10, 0.22
    t = 0.0
    last_word = None
    out.append('<g class="ink">')
    word_of = {g["i"]: g["word"] for g in data["glyphs"]}
    for s in data["strokes"]:
        pts = s["points"]
        length = sum(math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]) for i in range(1, len(pts)))
        length = max(length, 2.0)
        word = word_of.get(s["i"])
        if last_word is not None and word != last_word:
            t += word_gap
        last_word = word
        duration = max(0.12, length / speed)
        d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts)
        out.append(f'<path d="{d}" style="--len:{length + 4:.1f};--t:{duration:.2f}s;--d:{t:.2f}s"/>')
        t += duration + lift
    out.append('</g></svg>')
    return "\n".join(out).replace("{WRITE_END}", f"{t:.2f}")


# ----------------------------------------------------------------------------- images
def build_images(dist_assets):
    from PIL import Image
    img_dir = os.path.join(dist_assets, "img")
    os.makedirs(img_dir, exist_ok=True)
    names = []
    for name in sorted(os.listdir(RAW)):
        if not name.endswith(".png"):
            continue
        src = os.path.join(RAW, name)
        stem = name[:-4]
        im = Image.open(src).convert("RGB")
        target_w = 1032 if im.width <= im.height else 1376
        if im.width > target_w:
            im = im.resize((target_w, round(im.height * target_w / im.width)), Image.LANCZOS)
        im.save(os.path.join(img_dir, stem + ".png"), optimize=True)
        im.save(os.path.join(img_dir, stem + ".webp"), quality=82, method=6)
        names.append(stem)

    icon = Image.open(ICON).convert("RGBA")
    for size, out in ((512, os.path.join(dist_assets, "icon-512.png")),
                      (96, os.path.join(dist_assets, "icon-96.png")),
                      (180, os.path.join(DIST, "apple-touch-icon.png")),
                      (64, os.path.join(DIST, "favicon.png"))):
        icon.resize((size, size), Image.LANCZOS).save(out, optimize=True)
    return names


def build_og(dist_assets, css_name):
    """A 1200 × 630 Open Graph card, rendered by headless Chrome from a tiny page."""
    if not os.path.exists(CHROME):
        print("  (Chrome not found — skipping the Open Graph image)")
        return
    html = f"""<!doctype html><html><head><meta charset="utf-8"><style>
    html,body{{margin:0;width:1200px;height:630px;background:#FAF5E8;font-family:ui-rounded,"SF Pro Rounded",-apple-system,"Helvetica Neue",Arial,sans-serif;color:#1C1C1E}}
    .wrap{{display:flex;align-items:center;gap:56px;padding:70px 80px;height:630px;box-sizing:border-box}}
    img{{width:220px;height:220px;border-radius:22%;box-shadow:0 8px 0 rgba(0,0,0,.10)}}
    h1{{font-size:74px;line-height:1.05;margin:0 0 18px;letter-spacing:-1px}} p{{font-size:30px;line-height:1.35;margin:0;color:#3A3A3C}}
    .free{{display:inline-block;margin-top:26px;background:#007AFF;color:#fff;font-weight:700;font-size:26px;border-radius:14px;padding:12px 22px}}
    </style></head><body><div class="wrap"><img src="{dist_assets}/icon-512.png"><div><h1>Say it. Write it. Keep it.</h1>
    <p>An iPad journal where a child says what happened today and writes it in their own hand. Every page is kept. The journal never leaves the iPad.</p>
    <span class="free">The basic app is always free · no ads · we never sell your data</span></div></div></body></html>"""
    tmp = os.path.join(DIST, "_og.html")
    with open(tmp, "w") as f:
        f.write(html)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
                    "--force-device-scale-factor=1", "--window-size=1200,630",
                    f"--screenshot={os.path.join(dist_assets, 'img', 'og.png')}", f"file://{tmp}"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.unlink(tmp)


# ----------------------------------------------------------------------------- analytics
def ga_snippet(measurement_id):
    """Google Analytics 4 (gtag.js). Loaded from Google's servers as Google's snippet does,
    except that it is skipped entirely when the browser sends the Global Privacy Control
    signal. Set ga_measurement_id in site.config.json; the placeholder still builds."""
    if not measurement_id:
        return ""
    if measurement_id.startswith("G-X"):
        print("  (ga_measurement_id is still the placeholder — set it in site.config.json)")
    return ("<script>(function(){if(navigator.globalPrivacyControl){return;}"
            "var s=document.createElement('script');s.async=true;"
            "s.src='https://www.googletagmanager.com/gtag/js?id=%s';document.head.appendChild(s);"
            "window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}window.gtag=gtag;"
            "gtag('js',new Date());gtag('config','%s',{anonymize_ip:true});})();</script>\n"
            % (measurement_id, measurement_id))


# ----------------------------------------------------------------------------- pages
def parse_page(text):
    """A page starts with a header block:  ---\\ntitle: …\\ndescription: …\\npath: /x/\\n---"""
    m = re.match(r"---\n(.*?)\n---\n(.*)", text, flags=re.S)
    if not m:
        raise SystemExit("page is missing its header block")
    meta = {}
    for line in m.group(1).splitlines():
        key, _, value = line.partition(":")
        meta[key.strip().upper()] = value.strip()
    return meta, m.group(2)


def render(template, variables):
    def sub(match):
        key = match.group(1)
        if key not in variables:
            raise SystemExit(f"unknown variable {{{{{key}}}}}")
        return variables[key]
    return re.sub(r"\{\{([A-Z_]+)\}\}", sub, template)


def main():
    if "--clean" in sys.argv and os.path.isdir(DIST):
        shutil.rmtree(DIST)
    assets = os.path.join(DIST, "assets")
    os.makedirs(assets, exist_ok=True)
    os.makedirs(os.path.join(DIST, "downloads"), exist_ok=True)

    with open(os.path.join(SRC, "css", "site.css")) as f:
        css = minify_css(f.read())
    with open(os.path.join(SRC, "js", "site.js")) as f:
        js = minify_js(f.read())
    css_name, js_name = hashed("site", "css", css), hashed("site", "js", js)
    for old in os.listdir(assets):
        if re.match(r"site\.[0-9a-f]{8}\.(css|js)$", old) and old not in (css_name, js_name):
            os.unlink(os.path.join(assets, old))
    with open(os.path.join(assets, css_name), "w") as f:
        f.write(css)
    with open(os.path.join(assets, js_name), "w") as f:
        f.write(js)
    print(f"  {css_name} ({len(css):,} bytes), {js_name} ({len(js):,} bytes)")

    print("  images…")
    images = build_images(assets)
    build_og(assets, css_name)
    for pdf in ("Parents", "Schools", "Therapists", "Press-Fact-Sheet"):
        src = os.path.join(PDFS, pdf + ".pdf")
        if os.path.exists(src):
            shutil.copy(src, os.path.join(DIST, "downloads", pdf + ".pdf"))

    base = {
        "SITE_URL": CONFIG["site_url"].rstrip("/"),
        "ROOT": CONFIG["root"],
        "APP_STORE_URL": CONFIG["app_store_url"],
        "SUPPORT_EMAIL": CONFIG["support_email"],
        "DEVELOPER": CONFIG["developer"],
        "UPDATED": CONFIG["updated"],
        "YEAR": CONFIG["year"],
        "CSS": css_name,
        "JS": js_name,
        "HERO_SVG": hero_svg(),
        "GA": ga_snippet(CONFIG.get("ga_measurement_id", "")),
        "ANALYTICS_PROVIDER": CONFIG.get("analytics_provider", "[analytics provider]"),
        "ANALYTICS_RETENTION": CONFIG.get("analytics_retention", "[retention period]"),
    }
    for badge in ("app-store-badge-black.svg", "app-store-badge-white.svg"):
        shutil.copy(os.path.join(SRC, "assets", badge), os.path.join(assets, badge))
    with open(os.path.join(SRC, "partials", "head.html")) as f:
        head = f.read()
    with open(os.path.join(SRC, "partials", "foot.html")) as f:
        foot = f.read()

    paths = []
    for name in sorted(os.listdir(os.path.join(SRC, "pages"))):
        if not name.endswith(".html"):
            continue
        with open(os.path.join(SRC, "pages", name)) as f:
            meta, body = parse_page(f.read())
        variables = dict(base, TITLE=meta["TITLE"], DESCRIPTION=meta["DESCRIPTION"], PATH=meta["PATH"])
        html = render(head + body + foot, variables)
        path = meta["PATH"]
        if name == "404.html":
            out = os.path.join(DIST, "404.html")
        else:
            out_dir = os.path.join(DIST, path.strip("/")) if path.strip("/") else DIST
            os.makedirs(out_dir, exist_ok=True)
            out = os.path.join(out_dir, "index.html")
        with open(out, "w") as f:
            f.write(html)
        if name != "404.html":
            paths.append(path)
        print(f"  {os.path.relpath(out, DIST)}  ({len(html):,} bytes)")

    site = base["SITE_URL"]
    with open(os.path.join(DIST, "sitemap.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
        for p in paths:
            f.write(f"  <url><loc>{site}{p}</loc></url>\n")
        f.write("</urlset>\n")
    with open(os.path.join(DIST, "robots.txt"), "w") as f:
        f.write(f"User-agent: *\nAllow: /\nSitemap: {site}/sitemap.xml\n")
    print(f"  {len(paths)} pages, {len(images)} images → {os.path.relpath(DIST, HERE)}/")


if __name__ == "__main__":
    main()
