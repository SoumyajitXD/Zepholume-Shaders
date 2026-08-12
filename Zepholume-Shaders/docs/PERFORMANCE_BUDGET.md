# Performance budget

## Current static facts

| Resource | Current |
|---|---|
| Shadow passes | 0 |
| Composite/final passes | 0 |
| Extra colour buffers | 0 |
| Fragment texture samples | 1 textured; 0 untextured |
| Fragment loops | 0 |
| Water animation | One sine and one cosine per water vertex in Balanced; none in Ultra Lite |
| Temporal/custom resources | 0 |

These are source-level facts, not GPU measurements.

## Current strict limits

- Ordinary textured fragment paths use one required texture sample.
- Fragment paths use zero loops and zero trigonometric operations.
- One main colour output; no temporal storage, shadow workload, or extra render targets.
- Profile differences are compile-time branches; Ultra Lite removes disabled water and fog-quality work.
- Validation limits include depth to eight (current maximum: three).

## Targets

One main colour attachment; no full-screen pass unless a measured visual benefit justifies it; no texture samples in loops; no dynamic loops (static loops must be 4 or fewer); disabled effects must compile out; no history, depth copy, noise/LUT, shadow, or auxiliary full-resolution allocations; keep GLSL 330 compilation small and shared.

No FPS, utilisation, VRAM, or frame-time result is claimed before controlled runtime measurement.

## Audit result

No fragment loop, dynamic loop, repeated matrix calculation, or extra texture read was found. The only trigonometry is vertex-stage water motion behind the `ZEPH_WATER_PROGRAM` and `ZEPH_WATER_MOTION` compile-time conditions. `water.glsl` is included in the shared sources but its calls compile out for non-water wrappers; this is retained for a single consistent source rather than duplicated programs. Fog work is suppressed for sky and cloud wrappers. No source change beyond the corrected malformed sky directive was justified without runtime measurement.

## 2026-07-31 static cost delta

Sky: before, zero extra texture samples for basic sky and one for textured sky, plus generic lighting/grade; after, the same sample counts, no normalisations, and one bounded weather mix. Iris upper sky adds one interpolated height and a few `smoothstep`/mix operations; stage-specific branches are uniform per draw. Clouds: still one texture sample, no loops, no normalisations, and one added distance varying; fog now uses loader fog endpoints rather than arbitrary constants. Ordinary paths remove one luma dot and multiply-equivalent lighting shaping. No measurement is claimed.
