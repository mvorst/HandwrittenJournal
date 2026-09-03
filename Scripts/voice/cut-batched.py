#!/usr/bin/env python3
"""Cut the voice clips several lines to a request — for a day when the TTS quota is short.

Gemini's preview TTS models allow 100 requests a day each, and there are 224 lines. This
asks for six lines per request with a pause between them, splits the audio on those
pauses, checks that the split gave one clip per line and that each clip is about as
long as its words should take, and writes the same trimmed mono AAC clips
build-clips.sh does. A batch that does not split cleanly is retried line by line.

    Scripts/voice/cut-batched.py --model gemini-2.5-pro-preview-tts --voice Leda --out DIR

`--verify` also transcribes each clip back (gemini-3.6-flash) and re-cuts any whose
transcript does not match — a stricter gate, but the transcriber drops words on short
clips and reads "90%" as "ninezero", so it rejects good clips too; off by default.
Clips already in DIR are skipped, so a run can resume. Needs gcp-api.sh / gcp-tts.sh on
PATH, jq and ffmpeg.
"""
import argparse, base64, json, os, re, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from lines import lines as all_lines, markdown  # noqa: E402

STYLE = "Say this warmly and unhurried, like a kind teacher talking to a five-year-old. "
BATCH_INSTRUCTION = "Read these lines one after another, leaving a silent pause of two full seconds between lines:\n\n"
TRANSCRIBE_MODEL = "gemini-3.6-flash"
API = "https://generativelanguage.googleapis.com/v1beta"
DIGITS = {str(i): w for i, w in enumerate("zero one two three four five six seven eight nine".split())}


def sh(*cmd, check=True, **kw):
    return subprocess.run(cmd, check=check, text=True, capture_output=True, **kw)


def tts(text, wav, voice, model):
    for attempt in range(1, 5):
        r = sh("gcp-tts.sh", text, wav, voice, model, check=False)
        if r.returncode == 0:
            return True
        msg = (r.stderr or r.stdout).strip()[-300:]
        print(f"    tts attempt {attempt}: {msg}", flush=True)
        if "per_day" in msg or "retry in" in msg and "h" in msg.split("retry in")[-1][:6]:
            raise SystemExit("daily quota spent — resume tomorrow")
        time.sleep(10 * attempt)
    return False


def transcribe(wav):
    with open(wav, "rb") as f:
        data = base64.b64encode(f.read()).decode()
    body = json.dumps({"contents": [{"parts": [
        {"text": "Transcribe this audio exactly, word for word. Output only the transcript."},
        {"inlineData": {"mimeType": "audio/wav", "data": data}}]}]})
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as t:
        t.write(body); path = t.name
    try:
        for attempt in range(1, 4):
            r = sh("gcp-api.sh", "POST", f"{API}/models/{TRANSCRIBE_MODEL}:generateContent", f"@{path}", check=False)
            try:
                return json.loads(r.stdout)["candidates"][0]["content"]["parts"][0]["text"]
            except (ValueError, KeyError, IndexError):
                print(f"    transcribe attempt {attempt}: {(r.stderr or r.stdout).strip()[-200:]}", flush=True)
                time.sleep(10 * attempt)
    finally:
        os.unlink(path)
    return ""


def normal(text):
    text = text.lower().replace("'", "")
    text = "".join(DIGITS.get(c, c) for c in text)
    return " ".join(re.sub(r"[^a-z0-9 ]+", " ", text).split())


def expected_seconds(text):
    """A kind teacher's pace, about 2.4 words a second, plus a breath."""
    return 0.5 + 0.42 * len(text.split())


def plausible(seconds, text):
    return 0.5 * expected_seconds(text) <= seconds <= 1.8 * expected_seconds(text)


def silences(wav, min_len):
    r = sh("ffmpeg", "-i", wav, "-af", f"silencedetect=noise=-40dB:d={min_len}", "-f", "null", "-", check=False)
    starts = [float(m) for m in re.findall(r"silence_start: ([\d.]+)", r.stderr)]
    ends = [float(m) for m in re.findall(r"silence_end: ([\d.]+)", r.stderr)]
    dur = float(re.search(r"Duration: (\d+):(\d+):([\d.]+)", r.stderr).group(3)) \
        + 60 * float(re.search(r"Duration: (\d+):(\d+):([\d.]+)", r.stderr).group(2))
    return list(zip(starts, ends)), dur


def segments(wav, count):
    """Speech spans between the longest pauses — exactly `count` of them, or None."""
    for min_len in (1.2, 0.9, 0.7, 0.55, 0.45):
        sil, dur = silences(wav, min_len)
        spans, cursor = [], 0.0
        for s, e in sil:
            if s - cursor > 0.25:
                spans.append((cursor, s))
            cursor = e
        if dur - cursor > 0.25:
            spans.append((cursor, dur))
        if len(spans) == count:
            return spans
    return None


def encode(wav, start, end, out):
    pad = 0.08
    sh("ffmpeg", "-loglevel", "error", "-y", "-i", wav,
       "-ss", f"{max(0, start - pad):.3f}", "-to", f"{end + pad:.3f}",
       "-af", "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,"
              "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,areverse",
       "-c:a", "aac", "-b:a", "48k", "-ac", "1", out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="gemini-2.5-pro-preview-tts")
    ap.add_argument("--voice", default="Leda")
    ap.add_argument("--out", required=True)
    ap.add_argument("--batch", type=int, default=6)
    ap.add_argument("--verify", action="store_true", help="also transcribe every clip back and re-cut mismatches")
    ap.add_argument("--pace", type=float, default=6.5, help="seconds between requests (10 a minute allowed)")
    ap.add_argument("--limit", type=int, default=0, help="cut only the first N missing clips (a trial run)")
    ap.add_argument("--all", action="store_true", help="re-cut every clip, not only the missing ones (one voice, one model, one day)")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    todo = [l for l in all_lines() if args.all or not os.path.exists(os.path.join(args.out, f"{l['id']}.m4a"))]
    if args.limit: todo = todo[:args.limit]
    print(f"{len(todo)} clips to cut with {args.voice} on {args.model}, {args.batch} a request", flush=True)
    tmp = tempfile.mkdtemp()
    requests, singles = 0, []

    def cut_single(line):
        nonlocal requests
        wav = os.path.join(tmp, f"{line['id']}.wav")
        if not tts(STYLE + line["say"], wav, args.voice, args.model):
            return False
        requests += 1; time.sleep(args.pace)
        sil, dur = silences(wav, 0.3)
        if not plausible(dur, line["say"]):
            print(f"  ! {line['id']}: {dur:.1f}s for {len(line['say'].split())} words", flush=True)
            return False
        if args.verify:
            text = normal(transcribe(wav))
            if normal(line["say"]) not in text:
                print(f"  ! {line['id']}: transcript was '{text}'", flush=True)
                return False
        encode(wav, 0, dur, os.path.join(args.out, f"{line['id']}.m4a"))
        print(f"  {line['id']} (single)", flush=True)
        return True

    for i in range(0, len(todo), args.batch):
        batch = todo[i:i + args.batch]
        if len(batch) == 1:
            if not cut_single(batch[0]): singles.append(batch[0]["id"])
            continue
        wav = os.path.join(tmp, f"batch-{i}.wav")
        prompt = STYLE + BATCH_INSTRUCTION + "\n\n".join(l["say"] for l in batch)
        print(f"[{i + 1}-{i + len(batch)}/{len(todo)}] {', '.join(l['id'] for l in batch)}", flush=True)
        if not tts(prompt, wav, args.voice, args.model):
            singles += [l["id"] for l in batch]; continue
        requests += 1; time.sleep(args.pace)
        spans = segments(wav, len(batch))
        if spans is None:
            print("  ! did not split into \(len(batch)) — retrying line by line".replace("\\(len(batch))", str(len(batch))), flush=True)
            for l in batch:
                if not cut_single(l): singles.append(l["id"])
            continue
        # Each split clip must be about as long as its words take — a merged pair is
        # twice too long, a line cut in two half — and, with --verify, say its line.
        report = []
        for l, (s, e) in zip(batch, spans):
            ok = plausible(e - s, l["say"])
            heard = f"{e - s:.1f}s for {len(l['say'].split())} words"
            if ok and args.verify:
                piece = os.path.join(tmp, f"{l['id']}.wav")
                sh("ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-ss", f"{max(0, s - 0.08):.3f}", "-to", f"{e + 0.08:.3f}", piece)
                heard = normal(transcribe(piece))
                ok = heard == normal(l["say"])
            if ok:
                encode(wav, s, e, os.path.join(args.out, f"{l['id']}.m4a"))
                report.append(f"{e - s:.1f}s")
            else:
                print(f"  ! {l['id']}: heard '{heard}'", flush=True)
                if not cut_single(l): singles.append(l["id"])
                report.append("redone")
        print(f"  {', '.join(report)}", flush=True)

    have = len([f for f in os.listdir(args.out) if f.endswith(".m4a")])
    print(f"{requests} TTS requests; {have} of {len(all_lines())} clips in {args.out}")
    if os.path.abspath(args.out) == os.path.abspath(os.path.join(HERE, "..", "..", "HandwrittenJournal", "Resources", "Voice")):
        with open(os.path.join(HERE, "CLIPS.md"), "w") as f:
            f.write(markdown(args.voice, args.model))
        print("CLIPS.md updated")
    if singles:
        print("NOT CUT: " + " ".join(singles)); sys.exit(1)


if __name__ == "__main__":
    main()
