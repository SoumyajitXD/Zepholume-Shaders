# Profile guide

Balanced is Zepholume's default and is intentionally not a disguised High profile. Profile selection is authoritative: `profile.glsl` caps capability macros at the selected baseline, while the menus allow conservative reductions and bounded scene-grade adjustments.

| Profile | Feature baseline | Intended use |
|---|---|---|
| Potato | Tier 0: direct grade, loader sky/fog only | Integrated/weak GPUs and compatibility triage |
| Low | Tier 1: face/cloud/water/weather basics; no vertex water motion | Original lightweight target |
| Balanced | Tier 2: material response, atmospheric depth, two-wave water motion | General gameplay default |
| High | Tier 3: refined face/cloud/water/weather detail | Stronger systems; runtime validation required |
| Ultra | Tier 4: maximum bounded analytical detail | Visual evaluation; no temporal/framebuffer expansion |

`Water movement` controls water vertex displacement and is disabled on Potato. Foliage movement uses a separate shader path. If an old configuration selects Ultra Lite, select Low.
