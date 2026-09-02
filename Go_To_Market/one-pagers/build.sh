#!/bin/zsh
# Render every one-pager to PDF (and a PNG preview) with headless Chrome.
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p preview
for f in Parents Schools Therapists Press-Fact-Sheet; do
  [ -f "$f.html" ] || continue
  "$CHROME" --headless=new --disable-gpu --no-sandbox --no-pdf-header-footer \
    --print-to-pdf="$f.pdf" "file://$PWD/$f.html" >/dev/null 2>&1
  "$CHROME" --headless=new --disable-gpu --no-sandbox --hide-scrollbars --force-device-scale-factor=2 \
    --window-size=816,1056 --screenshot="preview/$f.png" "file://$PWD/$f.html" >/dev/null 2>&1
  echo "built $f.pdf"
done
