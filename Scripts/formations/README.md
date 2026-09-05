# Font-specific tracing routes

`LetterFormations.swift` contains 62 generated formations for each of the five
bundled fonts. `FormationFitter.placedStrokes(for:)` places those paths against the
selected font's actual CoreText ink bounds, at the current font size and location.
The legacy Jua templates remain available for older callers; runtime tracing uses
the font-specific API, which returns final points without a second smoothing pass.

To rebuild and visually review the data:

```sh
python3 -m venv /tmp/formation-tools
/tmp/formation-tools/bin/pip install -r Scripts/formations/requirements.txt
/tmp/formation-tools/bin/python Scripts/formations/generate.py --output /tmp/font-formations --write-swift
```

Use `--check` instead of `--write-swift` to verify that the checked-in coordinates
match a fresh generation. No Python or image-processing dependency ships in the app.
The generator also writes a JSON geometry report, input font/guide SHA-256 hashes,
and one labeled atlas per font. Reference atlases and the report are checked in here.

The pipeline renders each bundled TTF independently at 512 pixels per em, thins its
ink to a graph, removes short boundary artifacts, and trims the low-radius diagonal
tails caused by square terminals. The original Jua guides supply semantic stroke
order and direction; their points are projected onto the current font's graph.
Shared stems are protected when extending routes, so a bowl cannot acquire a second
trip around its loop. Terminal fragments merge into their original gesture. Sharp
V/W cusps are converted from graph spurs to two pen motions through the tip.

Structural overrides include serif I in Andika and Comic Neue, the baseline of 1
in Andika/Varela/Comic, the topbar of Jua J, diagonal y arms, and Varela's two-storey
a. Sniglet's very heavy S and e have manually reviewed smooth routes: their medial
axis contains broad branches that would be inappropriate pen gestures. Reviewed
incidental branches in Sniglet F/N are omitted. Jua 2 and Comic/Varela 3 visit their
base or waist tips within a single continuous gesture. Comic g uses a direct right
stem flowing downward and left into its hook, following the bowl as one second stroke.

Verification checks all 310 glyphs for:

- Dense, evenly spaced path samples inside the glyph mask (at least 99.9%).
- At least 98.5% coverage of the pruned centerline within the local stroke radius.
- At least 92% of glyph ink reconstructed by local-radius disks along the path.
  This is a geometric audit, not a requirement for the child to color in the glyph.
- For the manually reviewed Sniglet S/e routes and F's removed incidental twig,
  at least 95% ink reconstruction replaces the misleading medial-axis comparison;
  exact containment still applies. The reviewed F reconstructs 99.999% of its ink
  without requiring the internal twig; N also passes the standard centerline check.

Runtime `FontFormationTests` independently checks all 310 paths against CoreText
outlines and checks dots, crossbars, serif I variants, the legacy Jua a/t groups,
continuous 2/3/Z gestures, absence of extra Sniglet F/N lifts, and Comic g hook direction.
Scoring tests exercise complete/partial paths and missing essential parts separately.

The generated routes provide demonstrations and coverage targets for all fonts.
They are not a claim that skeletonization can discover classroom stroke order.
The application only applies its existing pedagogical order penalty to Jua; other
faces would need independent teaching review before such a penalty is appropriate.
