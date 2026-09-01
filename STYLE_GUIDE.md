# HandwrittenJournal — Style Guide (Reconciled)

This document reconciles the proposed "lined paper / crayon" style guide against what the
app actually ships today. The source of truth for current values is
[`AppConstants.swift`](HandwrittenJournal/App/AppConstants.swift) (`Tokens`), which is
itself generated from `WIREFRAME_SPEC.md` §5–§9. Where the two differ, both values are
shown so adoption can be a deliberate token change rather than a drift.

**Legend:** ✅ already matches (or close enough) · 🔀 differs — app value shown ·
🆕 proposed, no current equivalent · ⛔ conflicts with how the app works (see note)

**Decisions to date:**

- **Fonts stay as shipped** (SF Pro Rounded UI; Jua & co. journal faces — see §2).
- **Writing rules stay as the app draws them** — dashed ascender/descender, solid
  baseline, neutral gray, no margin rule. The proposed cyan/blue/margin-red rule
  treatment is not adopted (§3.1).
- **Blue stays the primary action color.** Pencil Yellow is repositioned as a
  highlight/decorative accent, not the primary button fill (§1.2).
- **Crayon Red `#D64541` added to the palette** for destructive/danger roles, so
  Eraser Pink can stay purely playful (§1.2).

**Adopted and shipped (spec v2.8, 2026-09-01)** in `WIREFRAME_SPEC.md` §5/§8, the
Penpot file, and `AppConstants.swift`: warm paper (`paper` `#FAF5E8`, `paper-sunk`
`#F1E8D3`), `danger` → Crayon Red, `success` → Meadow Green `#43A047`, `star-on` →
Tangerine `#F28522`, cut-paper shadows (y 3/4/6, 0 blur), `shadow-card` on primary
buttons, and the three decorative accents as reserved tokens. The accuracy inks kept
their original values throughout. Still open: grain texture and the sticker/doodle
asset pass.

---

## 1. Color Palette

### 1.1 Foundational (paper & rules)

| Role | Proposed | Current app | Status |
|---|---|---|---|
| Primary background | Lined Paper Cream `#FAF5E8` | `Tokens.Colour.paper` `#FAF5E8` | ✅ **Adopted (v2.8).** |
| Sunken surface | — | `paperSunk` `#F1E8D3` | ✅ Retinted to a warm step down from the cream (v2.8). |
| Raised surface / cards | — | `paperRaised` `#FFFFFF` | ✅ Kept white — cards read as bright paper against the cream ground. |
| Left-margin rule | ~~Warm Margin Red `#E76F6F`~~ | *(none — app draws no margin rule)* | ✅ **Decided: not adopted.** The app draws no margin rule and this stays as-is. |
| Guide rules (all) | ~~Guide Rule Cyan `#5CAAD9` / Dotted Midline Blue `#7DBCE8`~~ | `ruleLine` `#E5E5EA` (neutral gray, 1 px) | ✅ **Decided: the app's treatment is the spec.** All writing rules are neutral gray; structure per §3.1. |

### 1.2 Accent & lettering

| Role | Proposed | Current app | Status |
|---|---|---|---|
| Headers / prompts / traced lines | Story Blue `#2F6EB5` | Headers use `textPrimary` `#1C1C1E`; traced guide is `guideText` black @ 80% | 🔀 |
| Traced letter fill / active ink | Pencil Lead Navy `#243647` | `inkNatural` `#2C2C2E` (graphite near-black) | 🔀 Close in spirit; navy is a small warm-to-cool shift. Note the app also colors ink **green/red by accuracy** (`inkInside` `#34C759`, `inkOutside` `#FF3B30`, color-blind alternates blue/orange) — the guide has no equivalent for the accuracy channel, which must be preserved. |
| Primary buttons | `action` Blue `#007AFF` (pressed `#0060D0`, disabled `#B4D5FA`) | Same | ✅ **Decided: Blue stays primary.** Pencil Yellow `#F6C33E` is kept in the palette as a highlight/decorative accent only (badges, star fills, callout backgrounds) — never the primary button fill. |
| Destructive / danger | **Crayon Red `#D64541`** *(added to the guide)* | `danger` `#D64541` | ✅ **Adopted (v2.8).** Crayon Red is a warm tomato red picked to sit with the palette: clearly red next to Eraser Pink `#E35882` (which shifts magenta) and Tangerine `#F28522` (which shifts orange), and softer than iOS `#FF3B30` against the cream paper. `inkOutside` (outside-the-lines accuracy ink) keeps `#FF3B30` — the teaching channel did not follow. |
| Playful pink | Eraser Pink `#E35882` | *(no equivalent)* | 🆕 **Repositioned: playful only** — highlights, badges, stickers. No longer proposed for destructive/clear actions (Crayon Red owns that). |
| Success / completed | Meadow Green `#43A047` | `success` `#43A047` | ✅ **Adopted (v2.8).** `inkInside` keeps `#34C759` — the accuracy channel did not follow. |
| Stars | Tangerine Orange `#F28522` | `starOn` `#F28522`; `streakFlame` stays `#FF9500` | ✅ **Adopted (v2.8)** for earned stars. The streak flame keeps its orange (`#FF9500`, shared with `inkOutsideCB`) — decorative tangerine and the color-blind accuracy orange stay distinct hues. |
| Secondary playful accent | Lilac Star `#8E75C8` | `practicePath` `#AF52DE` | 🔀 Nearest current purple. It is deliberately the *only* purple in the app (stroke-order path has no competing meaning) — if lilac becomes a general accent, the practice path needs to stay visually distinct. |

### 1.3 Colors the app has that the guide doesn't cover

Keep these regardless of palette adoption — they carry meaning, not decoration:

- `spokenText` `#5B6B8C` @ 42% — dictated words waiting to be written ("not yet real").
- `inkInsideCB` `#007AFF` / `inkOutsideCB` `#FF9500` — color-blind accuracy pair.
- `overlayScrim` black @ 40%, `divider` `#E5E5EA`, `textSecondary` `#6C6C70`,
  `starOff` `#D1D1D6`.

---

## 2. Typography & Lettering

**Decision: fonts remain as they are in the app.** The mapping below records how the
proposal lands on the current stack.

| Slot | Proposed | Current app | Status |
|---|---|---|---|
| Body / system text | Nunito or SF Pro Rounded | **SF Pro Rounded** (system, `design: .rounded`) — full scale in `Font.hj*` (13–60 pt) | ✅ Direct match. The wireframes substitute Nunito; the app already uses the real thing. |
| Header / display | Baloo 2, Quicksand Bold, or Fredoka | SF Pro Rounded Bold (`hjDisplay` 44, `hjTitle1` 34, `hjTitle2` 28) | 🔀 Acceptable per decision above. Note Baloo 2 is listed in `WIREFRAME_SPEC` §7.2 as a *journal* face but is **not bundled** (Varela Round ships in that slot instead). |
| Tracing typeface | KG Primary Dots, Print Clearly, or Escolar (single-stroke, dashed variants) | **Jua** (default), Andika Bold, Varela Round, Sniglet ExtraBold, Comic Neue Bold — per-profile setting | ⛔ **Do not swap — see the warning below.** |

### ⚠️ Tracing-font warning (the discrepancy that would cause issues)

The proposed single-stroke / dotted educational fonts are **incompatible with the app's
tracing engine**:

1. **The mask renderer needs filled letterforms.** Scoring works by testing whether the
   pencil stays *inside* the glyph's ink (thick strokes, open counters — the vetting rule
   in `WIREFRAME_SPEC` §7.2). A single-stroke or dotted font like KG Primary Dots has
   essentially no interior area, so inside/outside scoring, the green/red ink coloring,
   and the traced-guide reveal would all stop working.
2. **Formation guides are hand-fitted to Jua.** Every stroke-order path in
   `LetterFormations.swift` is eyeballed against Jua's outlines, and `PracticeView`
   locks to Jua for that reason. A new tracing face means re-fitting all formations.
3. The **dashed-guide look is already achieved in rendering**, not in the font: the app
   draws the guide text faint and reveals it as it's traced. The "dashed letter" aesthetic
   can be approximated with rendering changes if ever wanted, without touching fonts.

Adding any face remains a product decision vetted against the mask renderer first
(§7.2), not a style preference.

---

## 3. UI & Component Styling

### 3.1 Paper surfaces & writing rules

| Aspect | Proposed | Current app | Status |
|---|---|---|---|
| Texture | Subtle warm grain | Flat color | 🆕 |
| Rule pattern | **Dashed** ascender & descender lines + **solid baseline** | Same (`TracingSurface.drawRules`, dash `[6,4]`, 1 px, `ruleLine` neutral gray) | ✅ **Decided: the app's pattern is the spec.** The original proposal (solid cyan top/bottom + dashed blue midline) is superseded — the app's rules are derived from CoreText's actual baselines, and the dashed-outer/solid-baseline structure stays. |
| Margin rule | None | None | ✅ **Decided: no margin rule.** |

### 3.2 Buttons & containers

| Aspect | Proposed | Current app | Status |
|---|---|---|---|
| Corner radius | 16–24 px | `Radius`: chip 8, button 14, card 20, sheet 28 | 🔀 Card (20) already in range; buttons (14) slightly tighter, chips (8) well below. |
| Shadow | Hard cut-paper: `y: 3px, blur: 0` | Cut-paper via `Tokens.Elevation`: card (y 3, blur 0, 8%), raised (y 4, 0, 12%), modal (y 6, 0, 18%); `PrimaryButton` carries the card shadow (disabled lies flat) | ✅ **Adopted (v2.8).** |
| Fills | Solid color | Solid color | ✅ |
| Press feedback | — | `PressableStyle`: scale 0.98 + opacity 0.75, easeOut 0.12 s | ✅ Current-only, keep. |
| Min tap targets | — | 44 pt minimum; child primary button 280×64 | ✅ Current-only, keep. |

### 3.3 Borders & dividers

| Aspect | Proposed | Current app | Status |
|---|---|---|---|
| Weights | Hand-drawn organic 2–3 px | `Stroke`: hairline 1, emphasis 2, selected 3 | ✅ Weights already match (2–3 px for anything emphasized); dividers/rules are 1 px hairlines. "Hand-drawn organic" line quality would be new asset/rendering work. |

### 3.4 Stickers & doodles

| Aspect | Proposed | Current app | Status |
|---|---|---|---|
| Crayon-textured micro-illustrations (stars, suns, flowers) | 🆕 | SF Symbols only today: `star.fill` (gold/gray) in `StarsView`, `flame` for streaks | Would require illustrated assets in `Assets.xcassets`. |

---

## 4. Motion & Tactile Feedback

| Aspect | Proposed | Current app | Status |
|---|---|---|---|
| Trace progress fill | Dashed `#7DBCE8` → filled `#2F6EB5` on contact | Faint guide revealed to `guideText` as traced (`tracedGuideAlpha`), ink colored live by accuracy (green inside / red outside) | 🔀 Mechanism exists; only the colors differ. The accuracy-coloring channel is a teaching feature the proposal must not replace. |
| Completion burst | Pop `scale 1.05 → 1.0` + floating doodle stars | Spring `response 0.4, damping 0.7` (`Tokens.Motion.spring`); star awards via `StarsView`; no particle/doodle burst | 🔀 Pop is a close cousin of the existing spring; floating doodles are 🆕. |
| Timing tokens | — | `Motion`: standard 0.30, pageFlip 0.35, guideFade 0.50, settle 0.45 | ✅ Current-only, keep. |
| Haptics | Light tick per completed letter stroke | `Haptics.tap()` (light impact) on stroke events, plus `success`, `warning`, `settle` (medium); per-profile enable toggle | ✅ Already implemented and richer than proposed. |

---

## 5. Adoption notes

1. **Token pass — ✅ shipped (v2.8).** `paper`/`paperSunk`, `success`, `starOn`, and
   `danger` retinted in `WIREFRAME_SPEC.md` §5, the Penpot library, and
   `AppConstants.swift`. `action` stayed Blue; the accuracy-ink pair
   (`inkInside`/`inkOutside`) and its color-blind alternates are untouched.
2. **Rendering pass — ✅ shipped (v2.8).** Cut-paper shadows in `Tokens.Elevation`
   and on `PrimaryButton`. The writing rules and (absent) margin rule are settled —
   `TracingSurface.drawRules` did not change.
3. **Asset pass — still open.** Grain texture, crayon sticker illustrations, doodle
   burst (where Pencil Yellow, Eraser Pink, and Lilac Star — now reserved tokens in
   §5.6 of the spec — will live).

Per the header of `AppConstants.swift`, token values are generated from
`WIREFRAME_SPEC.md` — change the spec first, then the tokens, so the two never disagree.

**Fonts stay as shipped:** SF Pro Rounded for all UI text; Jua / Andika / Varela Round /
Sniglet / Comic Neue as the curated journal faces. See §2 for why the proposed tracing
typefaces cannot be adopted.
