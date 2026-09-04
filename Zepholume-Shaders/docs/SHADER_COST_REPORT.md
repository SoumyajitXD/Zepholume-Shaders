# Source-Level Shader Cost Report (V1.0.2-dev Pass 4)

## Evidence boundary

This report records evaluated GLSL source only. `scripts/generate-compiled-variants.ps1` expands includes and runs `glslangValidator -E`, so profile and dimension conditional branches have been selected before measurement. The resulting textual call sites are not GPU ISA instructions, GPU timings, or FPS measurements. Compiler inlining, dead-code removal, and driver lowering are UNKNOWN without driver/compiler evidence.

## Static architecture

| Resource | Confirmed source state |
| --- | --- |
| Program pairs / stage files | 24 / 48 |
| Colour outputs | One: `gl_FragData[0]` |
| Ordinary textured fragment sampling | One sample; untextured routes use zero |
| Shadow, composite, deferred, history, depth-copy, compute | 0 |
| Fragment loops / fragment trig / `pow` | 0 / 0 / 0 |
| Evaluated variants | 6,048 logical mappings; 154 unique stages |

## Evaluated source inventory

The following is a representative conservative-loader Overworld fragment inventory. Counts include surviving helper definitions and call sites in evaluated source; they are useful regression signals, not an executed-instruction total.

| Profile | Family | Samples | Normalization-like sites | `/` sites | `sqrt`/`inversesqrt` sites | `smoothstep` sites | Varyings | Outputs |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Potato | Terrain | 1 | 2 | 2 | 5 | 2 | 6 | 1 |
| Potato | Water | 1 | 2 | 2 | 5 | 2 | 6 | 1 |
| Low | Terrain | 1 | 10 | 3 | 5 | 4 | 6 | 1 |
| Balanced | Terrain | 1 | 10 | 4 | 5 | 4 | 6 | 1 |
| High | Terrain | 1 | 10 | 4 | 7 | 4 | 6 | 1 |
| Ultra | Terrain | 1 | 10 | 4 | 7 | 4 | 6 | 1 |
| Balanced | Water | 1 | 10 | 4 | 5 | 4 | 6 | 1 |
| Balanced | Clouds | 1 | 2 | 1 | 3 | 2 | 4 | 1 |
| Balanced | Sky basic | 0 | 3 | 1 | 4 | 6 | 4 | 1 |

Exact complete rows are generated in `artifacts/shader-source-metrics/stage-stats.json` and profile aggregates in `profile-stats.json`; generated artifacts are not release-package inputs.

## Profile and dimension checks

- Potato evaluates out the terrain normal consumer and analytical water markers. It retains only loader fog colour when the eye is underwater.
- Low adds restrained underwater fog tint; Balanced is the intended default; High and Ultra only increase bounded scalar/analytical tiers.
- The dimension-wrapper checks reject surviving `sunSpecular`, `moonSpecular`, analytical-sky, or celestial-glow markers in `world-1` and `world1` evaluated fragments.
- All profiles retain the same texture-sample and target budget. No profile adds a pass or framebuffer.

## Pass 3 claim correction

Pass 3's include-expanded corpus was not an evaluated preprocessor corpus, so its hot-path numbers cannot be retained as profile-specific proof. Pass 4 replaces those numbers with evaluated-source reporting. The changes are expected to reduce source-level work where branches disappear, but actual GPU instruction deltas and performance gains remain UNKNOWN.

## Water terminology

Potato has no analytical water path. Low and Balanced use a bounded fourth-power Fresnel-inspired approximation; High and Ultra intentionally use a fifth-power Fresnel-Schlick-shaped curve. The `F0 = 0.035` baseline is artistic tuning, not physical correctness. This is an output change by profile, not a performance claim.
