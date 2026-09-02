#!/usr/bin/env python3
"""Compose App Store screenshot frames from raw simulator captures.

Each frame is 2064 x 2752 (iPad 13-inch portrait): a caption band on paper cream, and the
device capture inset below it in a rounded frame with a cut-paper shadow — the app's own
look (STYLE_GUIDE.md). Rendering is done by headless Chrome so the type is real.

    python3 compose_frames.py            # builds every frame in FRAMES into app-store/
    python3 compose_frames.py 3          # just frame 3

Requires Google Chrome. Captions live in FRAMES below; the caption voice rules are in
APP_STORE_LISTING.md §5 — sentence case, no full stop, never an exclamation mark.
"""
import base64
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "app-store")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

W, H = 2064, 2752

# (number, raw file, headline, sub-line, crop)  — crop is (x, y, w, h) in capture pixels
# or None for the whole screen. A crop is scaled to fill the same inset width.
FRAMES = [
    (1, "01-writing-live.png",
     "They say it. It appears. They write it.",
     "Their own words, on a ruled page, in their own hand", None),
    (2, "02-writing-settled.png",
     "Finish a line and the guide disappears",
     "What is left is their handwriting, exactly where they wrote it", None),
    (3, "16-writing-green-red.png",
     "Marked letter by letter, as they write",
     "Green inside the letter, red outside — never afterwards", (0, 440, 1060, 1000)),
    (4, "03-remediation.png",
     "A letter drawn backwards gets taught on the spot",
     "Stroke order, not just shape — one lesson, then carry on", None),
    (5, "04-journal-home.png",
     "A page a day becomes a book",
     "Newest first, dated, with their points and stars", None),
    (6, "05-entry-detail.png",
     "Their handwriting, kept exactly as they wrote it",
     "Every page stays in the journal and exports as a PDF", None),
    (7, "06-practice-sheet.png",
     "Every letter shows you how it is written",
     "Aa to Zz and 0 to 9, each one drawing itself stroke by stroke", None),
    (8, "07-settings-fonts.png",
     "Five faces, five sizes. You choose, not a level",
     "Settings for grown-ups. Nothing has to be earned", None),
]

PAGE = """<!doctype html><html><head><meta charset="utf-8"><style>
  html,body{{margin:0;width:{W}px;height:{H}px;overflow:hidden;background:#FAF5E8;}}
  body{{font-family:"SF Pro Rounded","SF Pro Display",-apple-system,"Helvetica Neue",Arial,sans-serif;color:#1C1C1E;}}
  .band{{position:absolute;left:0;top:0;width:{W}px;height:{band}px;display:flex;flex-direction:column;
         justify-content:flex-end;align-items:center;text-align:center;padding:0 140px 0;box-sizing:border-box;}}
  h1{{font-size:104px;line-height:1.12;font-weight:700;margin:0 0 26px;letter-spacing:-0.5px;}}
  p{{font-size:52px;line-height:1.3;margin:0;color:#6C6C70;font-weight:500;}}
  .device{{position:absolute;left:{dx}px;top:{dy}px;width:{dw}px;height:{dh}px;border-radius:64px;
           overflow:hidden;background:#fff;box-shadow:0 12px 0 rgba(0,0,0,0.10);border:6px solid #E5DCC6;}}
  .device img{{position:absolute;left:{ix}px;top:{iy}px;width:{iw}px;height:{ih}px;}}
  .num{{position:absolute;right:56px;bottom:40px;font-size:34px;color:#B8AE98;font-weight:600;}}
</style></head><body>
  <div class="band"><h1>{headline}</h1><p>{sub}</p></div>
  <div class="device"><img src="data:image/png;base64,{b64}"></div>
</body></html>"""


def build(number, raw, headline, sub, crop):
    src = os.path.join(RAW, raw)
    if not os.path.exists(src):
        print(f"frame {number}: missing {src}")
        return
    with open(src, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()

    band = 620                      # caption band height
    margin = 120
    dw = W - margin * 2             # device frame width
    dx = margin
    dy = band + 40
    if crop:
        cx, cy, cw, ch = crop
        scale = dw / cw
        dh = int(ch * scale)
        ix, iy, iw, ih = -int(cx * scale), -int(cy * scale), int(W * scale), int(H * scale)
    else:
        scale = dw / W
        dh = H - dy + 160           # runs off the bottom, like a page in hand
        ix, iy, iw, ih = 0, 0, int(W * scale), int(H * scale)

    html = PAGE.format(W=W, H=H, band=band, dx=dx, dy=dy, dw=dw, dh=dh, ix=ix, iy=iy, iw=iw, ih=ih,
                       headline=headline, sub=sub, b64=b64)
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as t:
        t.write(html)
        path = t.name
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, f"{number:02d}.png")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
                    "--force-device-scale-factor=1", f"--window-size={W},{H}",
                    f"--screenshot={out}", f"file://{path}"],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.unlink(path)
    print(f"frame {number}: {out}")


if __name__ == "__main__":
    wanted = {int(a) for a in sys.argv[1:]} or None
    for frame in FRAMES:
        if wanted is None or frame[0] in wanted:
            build(*frame)
