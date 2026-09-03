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
    ("line-done-2",   "That line looks great.", "Write — a line settles (3rd)"),
    ("line-done-3",   "Keep going.", "Write — a line settles (4th)"),
    ("finished-all",  "Outstanding work! You wrote everything you said.", "Results — *I'm finished*, everything written"),
    ("finished-some", "Great writing!", "Results — *I'm finished*, words still waiting (the screen adds the name)"),
    ("help-next",     "That's how it's done! Next letter.", "Formation help — a letter traced, more to come"),
    ("help-fixed",    "That's the way! You fixed it.", "Formation help — the last letter traced"),
    ("help-again",    "Almost! Watch the arrows again. Start where they start.", "Formation help — a wrong-order attempt is wiped"),
    ("voice-on",      "Voice feedback is on. I'll tell you when it's your turn to write.", "Settings — *Voice feedback* switched on"),
    ("why-pencil",    "This is a handwriting app. Your child writes with a pencil in their hand, just as they do on paper — the grip, the pressure, the hand resting on the page, every letter formed stroke by stroke. That is what the app teaches and what it grades, so it doesn't start without one.", "Welcome, frame 59 — *You'll need an Apple Pencil* appears (if a voice was chosen)"),
    ("nobody-here",   "Nobody is here yet. Make a profile for each person who writes. Everyone gets their own journal, font and size.", "Profile picker — empty, before the first profile (if a voice was chosen)"),
    ("home",          "Add a journal entry, or practice writing your letters.", "Journal Home — as it appears, once per visit from the picker"),
    ("new-entry-0",   "Tell me about your day.", "Write — a new entry opens on the empty page (alternates with the next)"),
    ("new-entry-1",   "Tell me a story.", "Write — a new entry opens on the empty page (alternates with the previous)"),
    ("start-talking", "Tap the microphone and start talking.", "Write — right after the invitation"),
    ("mic-permission", "Can we use the microphone? It allows us to write down what you tell us so you can trace the words.", "Write — the microphone explainer, before iPadOS asks"),
]

# (badge id, name, what earned it, what will) — mirrors BadgeEngine.all
BADGES = [
    ("first_entry",    "First Entry",    "You wrote your first entry.",              "Write your first entry."),
    ("sharp_shooter",  "Sharp Shooter",  "A tracing at 90% or better.",              "Trace an entry at 90% or better."),
    ("streak_5",       "5-Day Streak",   "You wrote five days in a row.",            "Write five days in a row."),
    ("ten_entries",    "Ten Entries",    "Ten entries in the journal.",              "Write ten entries."),
    ("perfect_week",   "Perfect Week",   "Seven days in a row.",                     "Write seven days in a row."),
    ("thousand_words", "1,000 Words",    "A thousand words in your own hand.",       "Write a thousand words in your own hand."),
    ("every_font",     "Every Font",     "You tried every handwriting style.",       "Try every handwriting style — pick a new one in Settings."),
    ("neat_writer",    "Neat Writer",    "Five entries in a row at 85% or better.",  "Write five entries in a row at 85% or better."),
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


def phrase(c, spoken):
    """The trace line names the letter with an article: *the big A*, *a little a*, *the 7*."""
    if c.isdigit():
        return name(c, spoken)
    return ("the " if c.isupper() else "a ") + name(c, spoken)


def lines():
    out = [{"id": i, "text": t, "say": t, "where": w} for i, t, w in FIXED]
    for bid, bname, detail, hint in BADGES:
        out += [
            {"id": f"badge-{bid}-earned", "text": f"You earned {bname}! {detail}", "say": f"You earned {bname}! {detail}",
             "where": f"Results — *{bname}* just earned; the badge card when it is earned"},
            {"id": f"badge-{bid}-hint", "text": f"{bname}. {hint}", "say": f"{bname}. {hint}",
             "where": f"The badge card for *{bname}* while it is not earned yet"},
        ]
    for c in CHARACTERS:
        shown, said = name(c, False), name(c, True)
        out += [
            {"id": f"trace-{code(c)}",
             "text": f"Your turn. Trace {phrase(c, False)}.",
             "say": f"Your turn. Trace {phrase(c, True)}.",
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
    fixed, badges, letters = rows[:len(FIXED)], rows[len(FIXED):len(FIXED) + 2 * len(BADGES)], rows[len(FIXED) + 2 * len(BADGES):]
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
        f"## The badges ({len(BADGES)} badges × 2 = {len(badges)} clips)",
        "",
        "| Clip | Where it plays | Transcript | Size |",
        "|---|---|---|---|",
        *badges,
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
        model = sys.argv[3] if len(sys.argv) > 3 else "gemini-2.5-flash-tts"
        sys.stdout.write(markdown(voice, model))
    else:
        json.dump(lines(), sys.stdout, indent=2, ensure_ascii=False)
        print()
