#!/usr/bin/env python3
"""Transcribe every bundled clip back (Gemini) and compare it with the line it should say.

    Scripts/voice/verify-clips.py [--workers 4] [id ...]

Prints a match ratio per clip and lists the doubtful ones with their transcripts. The
transcriber is not perfect on two-second clips — it drops or adds a small word now and
then — so a low ratio means *listen to it*, not *re-cut it*. Numbers are compared as words
("90%" ~ "ninety percent"), punctuation and case are ignored.
"""
import argparse, base64, concurrent.futures, difflib, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from lines import lines as all_lines  # noqa: E402

CLIPS = os.path.join(HERE, "..", "..", "HandwrittenJournal", "Resources", "Voice")
MODEL = "gemini-3.6-flash"
NUMBERS = {"0": "zero", "1": "one", "2": "two", "3": "three", "4": "four", "5": "five", "6": "six",
           "7": "seven", "8": "eight", "9": "nine", "10": "ten", "90": "ninety", "85": "eighty five",
           "1,000": "one thousand", "1000": "one thousand", "5": "five", "%": " percent "}


def normal(text):
    text = text.lower().replace("’", "'").replace("'", "")
    text = re.sub(r"1,000|1000", " one thousand ", text)
    text = re.sub(r"\b(\d+)\b", lambda m: NUMBERS.get(m.group(1), m.group(1)), text)
    text = text.replace("%", " percent ").replace("-", " ")
    return " ".join(re.sub(r"[^a-z ]+", " ", text).split())


def transcribe(path):
    data = base64.b64encode(open(path, "rb").read()).decode()
    body = {"contents": [{"parts": [
        {"text": "Transcribe this audio exactly, word for word. Output only the transcript."},
        {"inlineData": {"mimeType": "audio/mp4", "data": data}}]}]}
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as t:
        json.dump(body, t); req = t.name
    try:
        for _ in range(3):
            r = subprocess.run(["gcp-api.sh", "POST", f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent", f"@{req}"],
                               capture_output=True, text=True)
            try:
                return json.loads(r.stdout)["candidates"][0]["content"]["parts"][0]["text"].strip()
            except (ValueError, KeyError, IndexError):
                continue
    finally:
        os.unlink(req)
    return "(no transcript)"


def check(line):
    path = os.path.join(CLIPS, f"{line['id']}.m4a")
    if not os.path.exists(path):
        return line["id"], 0.0, "(missing)", line["text"]
    heard = transcribe(path)
    ratio = difflib.SequenceMatcher(None, normal(line["say"]).split(), normal(heard).split()).ratio()
    return line["id"], ratio, heard, line["text"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("ids", nargs="*")
    args = ap.parse_args()
    todo = [l for l in all_lines() if not args.ids or l["id"] in args.ids]
    results = []
    with concurrent.futures.ThreadPoolExecutor(args.workers) as pool:
        for r in pool.map(check, todo):
            results.append(r)
            print(f"{r[1]:.2f}  {r[0]}: {r[2]}", flush=True)
    doubtful = sorted([r for r in results if r[1] < 0.9], key=lambda r: r[1])
    print(f"\n{len(results)} clips; {len(results) - len(doubtful)} match (ratio ≥ 0.90); {len(doubtful)} to listen to:")
    for id_, ratio, heard, text in doubtful:
        print(f"  {ratio:.2f} {id_}\n       should say: {text}\n       heard:      {heard}")


if __name__ == "__main__":
    main()
