# Trace scoring

Journal writing and practice share `TraceGeometryScorer`. A letter has three separate
measurements: containment, coverage, and completion. Touch frequency, pressure and
stroke order do not determine its geometric score.

## Containment

The scorer subdivides actual pen segments into short, distance-weighted pieces and
tests their midpoints against the specific laid-out CoreText glyph outline. The
margin is 2 points at 72-point type, scaled with type size with a 1-point minimum.
This uses the pen centerline: pressing harder does not make the same trace worse.
Neighboring glyphs cannot supply inside credit. Excursions outside every letter box
remain assigned to the current letter; they do not disappear from the denominator.
Separate pen gestures are never joined, and crayon doodles are excluded.

## Coverage and completion

Each bundled font has its own fitted paths for A–Z, a–z and 0–9. These paths are used
both by the practice demonstration and by the coverage scorer. The source data and
reproducible generation/verification tools live in `Scripts/formations`.

Targets are spaced along each path and weighted by their length. A target is covered
when the child's ink comes within its local stroke-width allowance and travels broadly
along that part, in either direction. Directions are averaged over a short distance
so touch jitter cannot make a vertical stem count as a missing horizontal crossbar.
Dots accept a tap. Each target is counted once, so repeating a small mark cannot cover
the rest of a letter. The width
allowance lets a thin pencil trace a broad font without coloring in the entire glyph.
Dots are separate required parts. Characters outside the teaching alphabet, such as
punctuation, use connected skeleton samples of their own glyph outline for coverage.
These fallback samples do not imply a taught stroke order.

The initial completion thresholds are:

- Containment of at least 85%.
- Total coverage of at least 85%.
- Coverage of at least 70% of every formation part; a dot needs its own hit.

These are product calibration values, not a validated assessment of handwriting
development. They are centralized in `TraceGeometryScorer` for further tuning with
real traces. Synthetic tests cover complete and partial letters, missing parts,
repeated marks, different sampling rates, font sizes and screen scales.

## Scores, progress and persistence

Final shape accuracy is the harmonic mean of containment and coverage:

```
shapeAccuracy = 2 * containment * coverage / (containment + coverage)
```

Empty letters score zero. Incomplete letters are capped at 89%, so omitting a small
essential part cannot earn the highest letter award. Jua's existing 20% formation
order discount is applied afterward; the other fonts receive geometric scoring
without an order penalty. Order and direction remain separate from shape completion.

The live percentage describes containment while the child is still writing. Final
accuracy includes coverage. Practice completion, automatic row advancement and
whole-word bonuses require geometric completion. Partial letters count as incomplete
in the finish message.

Any attempted writing is still saved. The existing record boundary remains based on
which letters have ink, so a new completeness rule cannot discard partial writing or
make it editable as if it had never been written. Erase, undo, clear and restoration
recompute spatial measurements from the remaining ink. Entries reopened and left
without changing their archived ink retain their previously awarded points/stars.

`ScoringEngine.Tally.record` retains its count-only fallback for old scalar aggregation
tests and utilities. Both production canvases supply spatial metrics; the fallback
must not be used to grade new handwriting.
