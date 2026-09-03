#!/usr/bin/env bash
# Cuts every line in lines.json with a Gemini voice and bundles it as an AAC clip in
# HandwrittenJournal/Resources/Voice/<id>.m4a (DESIGN_DOCUMENT.md §4.12, v3.7).
#
#   Scripts/voice/build-clips.sh            # cut whatever is missing
#   Scripts/voice/build-clips.sh --all      # re-cut everything (a new voice, a new line)
#   VOICE=Sulafat Scripts/voice/build-clips.sh --all
#   TTS=cloud Scripts/voice/build-clips.sh --all   # Cloud Text-to-Speech: same voice, no daily cap
#
# Needs gcp-tts.sh on PATH (Gemini API key), jq and ffmpeg — or, with TTS=cloud,
# gcp-cloud-tts.sh (a signed-in gcloud account and a project with billing; the AI
# Studio key's models allow only 50–100 requests a day each). One voice for the whole
# app; the style prefix is an instruction to the model and is not spoken (checked by
# transcribing a clip back). Gemini returns 24 kHz PCM; the clip is trimmed of the
# silence the model pads it with and encoded mono AAC at 48 kb/s — about 15 KB a line.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$ROOT/HandwrittenJournal/Resources/Voice"
LINES="$HERE/lines.json"
# cloud = Cloud Text-to-Speech via gcp-cloud-tts.sh (OAuth, per-character billing, no daily cap —
# what the shipped set was cut with); gemini = the AI Studio key via gcp-tts.sh (50–100 a day).
TTS="${TTS:-cloud}"
VOICE="${VOICE:-Leda}"
if [[ "$TTS" == "cloud" ]]; then MODEL="${MODEL:-gemini-2.5-flash-tts}"; else MODEL="${MODEL:-gemini-2.5-pro-preview-tts}"; fi
STYLE="${STYLE:-Say this warmly and unhurried, like a kind teacher talking to a five-year-old: }"
# The preview TTS models allow 10 requests a minute (and 2.5-flash 100 a day); a pause
# after each request keeps under the minute limit, and a failed request backs off.
PACE="${PACE:-4}"; [[ "$TTS" == "cloud" ]] && PACE="${PACE_CLOUD:-2}"
FORCE=0; [[ "${1:-}" == "--all" ]] && FORCE=1
mkdir -p "$OUT"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

python3 "$HERE/lines.py" > "$TMP/lines.json"
if ! cmp -s "$TMP/lines.json" "$LINES"; then
  echo "lines.json is out of date — regenerating from lines.py" >&2
  cp "$TMP/lines.json" "$LINES"
fi

total=$(jq length "$LINES"); n=0; cut=0; failed=()
while IFS=$'\t' read -r id say; do
  n=$((n + 1))
  clip="$OUT/$id.m4a"
  if [[ $FORCE -eq 0 && -s "$clip" ]]; then continue; fi
  wav="$TMP/$id.wav"; ok=0
  # Vertex meters the Cloud Gemini-TTS model per minute; a quota refusal is waited out
  # (up to ~5 minutes), anything else is retried a few times with a growing pause.
  for attempt in $(seq 1 20); do
    if [[ "$TTS" == "cloud" ]]; then
      if gcp-cloud-tts.sh "$say" "$wav" "$VOICE" "$MODEL" "${STYLE%: }" >/dev/null 2>"$TMP/err"; then ok=1; break; fi
    elif gcp-tts.sh "$STYLE$say" "$wav" "$VOICE" "$MODEL" >/dev/null 2>"$TMP/err"; then ok=1; break; fi
    if grep -q "RESOURCE_EXHAUSTED\|Quota exceeded\|quota" "$TMP/err"; then
      [[ $attempt -eq 1 ]] && echo "[$n/$total] $id: per-minute quota — waiting" >&2
      sleep 15; continue
    fi
    echo "[$n/$total] $id: attempt $attempt failed: $(tail -c 200 "$TMP/err")" >&2
    [[ $attempt -ge 4 ]] && break
    sleep $((attempt * 20))
  done
  if [[ $ok -eq 0 ]]; then failed+=("$id"); continue; fi
  # Trim leading/trailing silence (below -45 dB), keep 120 ms of air either side.
  ffmpeg -loglevel error -y -i "$wav" \
    -af "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,areverse" \
    -c:a aac -b:a 48k -ac 1 "$clip"
  cut=$((cut + 1))
  echo "[$n/$total] $id ($(wc -c < "$clip" | tr -d ' ') bytes)"
  sleep "$PACE"
done < <(jq -r '.[] | [.id, .say] | @tsv' "$LINES")

python3 "$HERE/lines.py" --markdown "$VOICE" "$MODEL" > "$HERE/CLIPS.md"
echo "Cut $cut clip(s) with $VOICE ($MODEL); $(ls "$OUT"/*.m4a 2>/dev/null | wc -l | tr -d ' ') of $total bundled; CLIPS.md updated."
if [[ ${#failed[@]} -gt 0 ]]; then echo "FAILED: ${failed[*]}" >&2; exit 1; fi
