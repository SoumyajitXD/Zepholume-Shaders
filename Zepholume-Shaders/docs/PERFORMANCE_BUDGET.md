# Performance budget

## Current static facts

| Resource | Current |
|---|---|
| Shadow passes | 0 |
| Composite/final passes | 0 |
| Extra colour buffers | 0 |
| Fragment texture samples | 1 textured; 0 untextured |
| Fragment loops | 0 |
| Water animation | Two sine/cosine waves per water vertex in Balanced; none in Potato, Low, or Ultra Lite |
| Underwater treatment | Existing fog interpolation plus bounded arithmetic; no texture/depth/pass/exp/pow |
| Temporal/custom resources | 0 |

These are source-level facts, not GPU measurements.

## Current strict limits

- Ordinary textured fragment paths use one required texture sample.
- Fragment paths use zero loops and zero trigonometric operations.
- One main colour output; no temporal storage, shadow workload, or extra render targets.
- Profile differences are evaluated with the GLSL preprocessor before source metrics are recorded; Potato removes analytical water and terrain-normal consumers.
- Validation limits include depth to eight (current maximum: three).

## Targets

One main colour attachment; no full-screen pass unless a measured visual benefit justifies it; no texture samples in loops; no dynamic loops (static loops must be 4 or fewer); disabled effects must compile out; no history, depth copy, noise/LUT, shadow, or auxiliary full-resolution allocations; keep GLSL 330 compilation small and shared.

No FPS, utilisation, VRAM, or frame-time result is claimed before controlled runtime measurement.

## Static-evidence boundary

No fragment loop, dynamic loop, extra texture read, extra target, or extra pass is intentionally present. The only trigonometry is profile-gated water vertex motion. `water.glsl` remains a shared include, but its analytical call is preprocessed out of Potato and non-water routes. The underwater treatment reuses fragment fog distance and adds only bounded arithmetic at Low through Ultra. These are source/preprocessor facts; source calls are not native GPU instruction counts, and no runtime performance result follows from them.

## 2026-07-31 static cost delta

Sky: before, zero extra texture samples for basic sky and one for textured sky, plus generic lighting/grade; after, the same sample counts, no normalisations, and one bounded weather mix. Iris upper sky adds one interpolated height and a few `smoothstep`/mix operations. Clouds: still one texture sample, no loops, no normalisations, and one added distance varying; fog uses loader fog endpoints rather than arbitrary constants. Ordinary paths remove one luma dot and multiply-equivalent lighting shaping. These are evaluated-source facts; branch lowering and native instruction changes are unknown. No measurement is claimed.
