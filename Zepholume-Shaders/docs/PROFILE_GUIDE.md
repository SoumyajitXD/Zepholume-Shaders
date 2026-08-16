# Profile guide

Balanced is Zepholume's default and is intentionally not a disguised High profile. Profile selection is authoritative: `profile.glsl` caps capability macros at the selected baseline, while the menus allow conservative reductions and bounded scene-grade adjustments.

| Profile | Feature baseline | Intended use |
|---|---|---|
| Potato | Tier 0: direct grade, loader sky/fog only | Integrated/weak GPUs and compatibility triage |
| Low | Tier 1: face/cloud/water/weather basics | Original lightweight target |
| Balanced | Tier 2: material response, atmospheric depth, two-wave water | General gameplay default |
| High | Tier 3: refined face/cloud/water/weather detail | Stronger systems; runtime validation required |
| Ultra | Tier 4: maximum bounded analytical detail | Visual evaluation; no temporal/framebuffer expansion |

`Water movement` is vertex-only, is disabled on Potato, and is intentionally not vegetation waving: Zepholume has no safe universal plant/material classifier across modded content. Ultra Lite is retained as a deprecated Low alias so old selections remain meaningful. Shadows, bloom, SSR, SSAO, and volumetrics are intentionally absent rather than exposed as non-functional switches.
