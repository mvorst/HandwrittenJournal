#!/usr/bin/env python3
"""Every line the app says, as a JSON manifest for build-clips.sh.

Mirrors `Voice.Cue` in HandwrittenJournal/Services/VoiceFeedback.swift — `id` is the
cue's clip id (the bundled file is Resources/Voice/<id>.m4a), `text` is what the cue
reads as in the app, and `say` is what Gemini is asked to speak. They differ only for
letter names: lower-case letters are spelled in capitals so the voice says the letter
("little A"), not the article ("little uh"). VoiceFeedbackTests checks the manifest
against the cues, so a new cue is added in both places or the tests fail.
"""
import json
import os
import string
import sys

# (clip id, what it says, where it plays — DESIGN_DOCUMENT.md §4.12)
FIXED = [
    ("preview",       "Hi! I'm your journal. I'll tell you when it's your turn to write.", "Welcome, frame 56 — *Hear it*"),
    ("pencil-intro",  "Watch the arrows, then trace the big A with the Apple Pencil.", "Welcome, frame 57 — the pencil check appears (if a voice was chosen)"),
    ("pencil-found",  "That's an Apple Pencil. You're ready to write!", "Welcome, frame 57 — an Apple Pencil inks"),
    ("finger",        "That was a finger. Try the Apple Pencil.", "Welcome, frame 58 — a finger inks"),
    ("your-turn",     "Your turn. Write it!", "Write — a take ends and the first line comes up"),
    ("line-done-0",   "Nice line.", "Write — a line settles (1st in rotation)"),
    ("line-done-1",   "Lovely writing.", "Write — a line settles (2nd)"),
    ("line-done-2",   "That line is yours now.", "Write — a line settles (3rd)"),
    ("line-done-3",   "Keep going.", "Write — a line settles (4th)"),
    ("finished-all",  "You wrote everything you said!", "Results — *I'm finished*, everything written"),
    ("finished-some", "Great writing!", "Results — *I'm finished*, words still waiting (the screen adds the name)"),
    ("help-next",     "That's the way! Next letter.", "Formation help — a letter traced, more to come"),
    ("help-fixed",    "That's the way! Your word is fixed.", "Formation help — the last letter traced"),
    ("help-again",    "Almost! Watch the arrows again. Start where they start.", "Formation help — a wrong-order attempt is wiped"),
]

CHARACTERS = string.ascii_uppercase + string.ascii_lowercase + string.digits


def code(c):
    if c.isdigit():
        return f"digit-{c}"
    return f"upper-{c}" if c.isupper() else f"lower-{c}"


def name(c, spoken):
    if c.isdigit():
        return f"the {c}"
    if c.isupper():
        return f"big {c}"
    return f"little {c.upper() if spoken else c}"


def lines():
    out = [{"id": i, "text": t, "say": t, "where": w} for i, t, w in FIXED]
    for c in CHARACTERS:
        shown, said = name(c, False), name(c, True)
        out += [
            {"id": f"trace-{code(c)}",
             "text": f"Your turn. Trace {shown}.",
             "say": f"Your turn. Trace {said}.",
             "where": f"Practice sheet / formation help — the demo of {shown} hands over"},
            {"id": f"traced-good-{code(c)}",
             "text": f"Nice {shown}! Pick another letter.",
             "say": f"Nice {said}! Pick another letter.",
             "where": f"Practice sheet — {shown} flips green, in the arrow order"},
            {"id": f"traced-order-{code(c)}",
             "text": f"Good {shown}. Try the strokes in the arrow order.",
             "say": f"Good {said}. Try the strokes in the arrow order.",
             "where": f"Practice sheet — {shown} flips green, out of order"},
        ]
    return out


def markdown(voice, model):
    """CLIPS.md — every clip, where it plays and what it says, with a link to the file."""
    here = os.path.dirname(os.path.abspath(__file__))
    clips = os.path.join(here, "..", "..", "HandwrittenJournal", "Resources", "Voice")
    rows = []
    for line in lines():
        path = os.path.join(clips, f"{line['id']}.m4a")
        size = f"{os.path.getsize(path) / 1024:.0f} KB" if os.path.exists(path) else "not cut yet"
        said = "" if line["say"] == line["text"] else f" (spoken as *{line['say']}*)"
        rows.append(f"| [`{line['id']}.m4a`](../../HandwrittenJournal/Resources/Voice/{line['id']}.m4a) | {line['where']} | {line['text']}{said} | {size} |")
    fixed, letters = rows[:len(FIXED)], rows[len(FIXED):]
    return "\n".join([
        "# Voice clips",
        "",
        f"Every line the app says (DESIGN_DOCUMENT.md §4.12), as recorded: one clip each in",
        f"`HandwrittenJournal/Resources/Voice/`, cut from `lines.json` by `build-clips.sh` with the",
        f"Gemini voice **{voice}** on `{model}`, spoken *warmly and unhurried, like a kind teacher",
        "talking to a five-year-old*. Mono AAC, 48 kb/s, silence trimmed. The app never uses a",
        "system voice: a cue with no clip is silent.",
        "",
        "This file is generated — edit `lines.py`, not this. Lower-case letters are spelled in",
        "capitals in the spoken text so the voice says the letter, not the article.",
        "",
        f"## The moments ({len(FIXED)} clips)",
        "",
        "| Clip | Where it plays | Transcript | Size |",
        "|---|---|---|---|",
        *fixed,
        "",
        f"## The letters ({len(CHARACTERS)} characters × 3 = {len(letters)} clips)",
        "",
        "| Clip | Where it plays | Transcript | Size |",
        "|---|---|---|---|",
        *letters,
        "",
    ])


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--markdown":
        voice = sys.argv[2] if len(sys.argv) > 2 else "Leda"
        model = sys.argv[3] if len(sys.argv) > 3 else "gemini-2.5-pro-preview-tts"
        sys.stdout.write(markdown(voice, model))
    else:
        json.dump(lines(), sys.stdout, indent=2, ensure_ascii=False)
        print()
