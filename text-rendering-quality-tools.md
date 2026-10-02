# Quantifying wezterm's rendered-text quality from screen grabs

Research notes from 2026-09-30, while chasing the terminal font problem (see the
last entries in `customizations.md`).

## The hard constraint

**Everything must work from a screen grab.** The terminal's own rendering —
wezterm's glyph atlas, cell-metric rounding, subpixel positioning, font fallback,
and which config it actually loaded — has to be inside the check. Nothing that
renders the font "in a vacuum" counts.

This constraint is not fussiness. Every failure in this investigation was a
**terminal-level** failure, invisible to any tool that rasterises a font itself:

- the running window was rendering a **two-day-old config** (the config file was
  perfect; the window was stale) — no font tool can see this;
- glyph crowns flattened by the **hinting mode actually in effect**;
- a **cell height of 21px** from `line_height` × ascent rounding, which is what
  left no room for a curve;
- **fractional pixel sizes** from `pt × dpi/72` at 96 dpi (11pt → 14.67px em);
- clipping against **cell bounds / atlas** rather than the glyph's own box;
- which font **actually served** each codepoint via fallback.

`ftlint` at 11ppem on Hack would have reported healthy acutance the whole time,
because it never touches wezterm's atlas or its config. That is exactly the
"render in a vacuum" trap.

## What this rules out (keep these for *diagnosis*, not for the check)

Useful for understanding a cause; **never** as the acceptance test:

- **`ftlint`** (`freetype2-demos`) — numeric X/Y *acutance* per ppem plus per-glyph
  bitmap MD5 for regression. Genuinely a quantitative renderer metric, and the
  best scalar found — but it measures FreeType directly, not wezterm.
- **`ftgrid`** — shows outlines over bitmaps on the pixel grid with interactive
  hinting toggles; great for *seeing* what hinting did to a curve.
- **`ftdiff`** — three-column hinting-mode comparison in one window.
- **`fontquant`** — quantifies a font's appearance (e.g.
  `appearance.weight.value`) via HarfBuzz shaping; measures the design, not the
  rasteriser.
- **`fontbakery` / `fontspector` / `diffenator2` / `diffenator3`** — inspect font
  files, or diff FreeType bitmaps of two fonts. `diffenator2`'s multi-size bitmap
  diffing is conceptually the closest to what we want, but it diffs *two fonts*,
  not *two renders of the same terminal*.

## What qualifies: image metrics computed from the grabbed pixels

| what we want to know | metric | notes |
| --- | --- | --- |
| bottoms aligned? | per-glyph ink-bottom row histogram | modal bottom row = baseline; deviation >1px is a defect. Also `baseline_delta` below. |
| stroke width consistent? | **Stroke Width Transform** (SWT), or modal horizontal ink-run length per glyph | SWT: Epshtein et al., Microsoft Research, *Detecting Text in Natural Scene with Stroke Width Transform*. JS impl `image-js/stroke-width-transform` (has a `scaleInvariant` option). |
| smaller render a faithful shrink? | **ink-height ÷ cell-height must be scale-invariant**; plus scaled **SSIM** | see "core metric" below — this is the one that directly replaces the "11pt is the first bad size" folklore. |
| where on the cell did the glyph land? | bbox ratios, per-word aspect | catches drift and clipping |
| is the text actually there / uniform? | ink coverage, glyph density, optical density per line | the compositor's "grey value" check |

### Reference implementation to crib thresholds from

`software-mansion/argent`, `packages/tool-server/src/tools/screenshot-diff/font-diff.ts`
— part of a **screenshot**-diff tool, so it already operates on grabbed pixels.
It emits named reason codes with thresholds:

    addReason(ssim < 0.86,                          "ssim_delta");
    addReason(hogDistance > 0.18,                   "hog_delta");
    addReason(widthRatio > 0.08 || heightRatio > 0.08 || aspectRatioDelta > 0.12,
                                                    "bbox_geometry_delta");
    addReason(glyphDensityDelta > 0.045,            "glyph_density_delta");
    addReason(strokeWidthDelta > 0.16,              "stroke_width_delta");
    addReason(textColorDistance > 32,               "text_color_delta");
    addReason(textContrastDelta > 24,               "text_contrast_delta");
    addReason(baselineDelta > Math.max(2, region.bounds.height * 0.12),
                                                    "baseline_delta");
    addReason(componentDelta > 0.18,                "component_shape_delta");
    addReason((perWordAspectDelta ?? 0) > 0.12,     "per_word_aspect_delta");

Mapping: bottoms -> `baseline_delta`; stroke width -> `stroke_width_delta`;
shrink fidelity -> `bbox_geometry_delta` / `per_word_aspect_delta` /
`component_shape_delta` / `ssim_delta`. The value here is the metric choice plus
plausible thresholds, not the code.

Also image-based and portable: **Leptonica** has baseline detection
(`src/baseline.c`, `pixFindBaselines`) for real bitmap text.

Perceptual comparison of rendered text (both operate on images, so both qualify):
Microsoft/Stanford *Optimizing subpixel rendering using a perceptual metric*
(Farrell, Eldar, Larson, Matskewich, Wandell, JSID 2011) and *Prediction of
preferred ClearType filters using the S-CIELAB metric*. And *Measuring and
Enhancing the Legibility of GPU-rendered Text* (Eurographics 2008), which ships a
benchmark set plus renders — relevant because AA on a dark background is a
gamma-correctness problem.

## Recommended harness

Screen grab only. Nine steps, in order — every one of them exists because
skipping it produced a wrong answer during this investigation.

1. **Locate the window from the X tree**, never assume: `xwininfo -root -tree`,
   read id, geometry, title. (Wrong crop origin bit me repeatedly.)
2. **Crop the content area** from those coordinates, excluding borders.
3. **Recover the cell grid from the image itself** — autocorrelate the column ink
   profile to find the cell pitch. Do **not** trust `wezterm cli list` for this:
   a disagreement between the claimed grid and the actual pixels is itself a bug
   worth detecting. (Autocorrelation worked reliably here: it found 8px and 9px
   cells correctly when every other method was lying.)
4. **Slice glyphs by cell pitch**, not by gap detection — monospace glyphs touch
   at 9px cells, so gap-based splitting finds one giant "glyph". (Also bit me.)
5. **Threshold with the correct polarity** — the background is already black; do
   not `-negate` or the background becomes the ink. (Bit me twice.)
6. **Per glyph**: ink box, top row, bottom row, modal ink-run length (stem width),
   ink area.
7. **Aggregate**: baseline histogram, stem-width distribution, ink-height ÷
   cell-height ratio.
8. **Compare across sizes** on identical text: the ratio in step 7 must be
   scale-invariant. A *lower* ratio at a smaller size than at a larger one means
   glyph tops (or bottoms) are being clipped or flattened — a screen-grab-only,
   self-referential test, needing no reference render at all.
9. **Validate the harness**: run it on a known-bad input and a known-good input and
   assert it *distinguishes* them. A metric that cannot fail on bad input is not a
   metric.

### The core metric, spelled out

For text rendered at sizes S1 < S2 < ... on the same screen:

    ratio(S) = (glyph ink height at S) / (cell height at S)

If rendering were a faithful scale, `ratio` would be constant. It is not, because
of hinting and integer cell rounding — and the *shape of the deviation curve* is
precisely the thing we want, because it names which sizes are safe to sweep
through. That replaces "11pt is the first bad one" (true but anecdotal) with data
covering the whole range.

## Failure modes only a screen grab catches

Worth stating explicitly, because each one is invisible from a vacuum tool:

- **stale window / wrong config loaded** — the config parses, the file is right,
  the window is rendering something else (runtime font-size overrides survive
  config reloads, with no error anywhere);
- glyphs clipped to **cell bounds** rather than their own box;
- the hinting/AA mode **actually in effect** vs the one requested;
- **cell metric rounding** (ascent × `line_height` → integer px);
- **fractional em pixel sizes** (only multiples of 3pt are integer em at 96 dpi);
- **font fallback** — which face really drew a codepoint.

## Theory worth reading first

FreeType, *On Slight Hinting, Proper Text Rendering, Stem Darkening and LCD
Filters*: <https://freetype.org/freetype2/docs/hinting/text-rendering-general.html>

- "(s)light hinting [...] snaps glyphs to the pixel grid **only vertically** [...]
  a compromise between design fidelity and sharpness that preserves inter-glyph
  spacing."
- "**Slight hinting will result in consistent font rendering.**" — a direct
  recommendation for "sweep sizes and have them all look good", pointing at
  `freetype_load_target = "Light"`. wezterm accepts it and it visibly changes the
  render, but it was never judged by eye. **This is the obvious next experiment**,
  as an alternative to the full `NO_HINTING` currently in use: keep vertical
  crispness, drop the horizontal distortion.
- Stem darkening is off by default because "no library supports linear alpha
  blending and gamma correction out of the box on X11" (Qt5 and Skia both disable
  gamma correction on X11). That is why thin AA text on a dark background looks
  weaker than it should, and why enabling stem darkening alone makes glyphs "heavy
  and fuzzy".

## The gap

There is no turnkey tool that takes screen grabs of a terminal and scores text
quality; the entire font-QA ecosystem inspects font files or renders fonts itself,
and is therefore on the wrong side of the constraint. The realistic build is a
small purpose-made script: window geometry -> crop -> autocorrelated cell grid ->
per-glyph boxes -> the aggregates in step 7. Roughly 100-150 lines, and it must be
validated against known-bad/known-good before it is believed.
