# Architecture

## Render route

Zepholume contains 24 GLSL 330 compatibility vertex/fragment program pairs. Every program writes only `gl_FragData[0]`; there are no composite, shadow, history, image, SSBO, compute, geometry, or tessellation paths. This is deliberate: all profiles retain bounded memory use and the direct paths avoid loader-dependent framebuffer choreography.

- Generic terrain, entities, blocks, hand, weather, and water use `vertex.glsl` and `fragment.glsl`.
- Sky and textured celestial geometry use `sky_vertex.glsl` and `sky_fragment.glsl`.
- Clouds use their own vertex/fragment pair.
- Nether and End wrapper pairs select a dimension tone while retaining the same shared route.

## Shared libraries and colour spaces

`profile.glsl` is the sole quality-capability authority: it reads raw options, selects a Potato/Low/Balanced/High/Ultra baseline, and exports capped `ZEPH_EFFECTIVE_*` values. A lower override can disable/reduce work; it cannot enable work above the chosen profile. `settings.glsl` is raw bounded input only.

The generic scene route is: sample and multiply vanilla vertex data → approximate display-to-working decode → face/material/weather response → bounded exposure, contrast, saturation, temperature, dimension tone, and rational highlight compression → display encode → atmosphere fog → source alpha. The complete scene grade now remains in working space, avoiding a redundant decode/encode cycle. First-person hand follows a separate low-saturation grade so a red hand cannot be amplified by the scene contrast path.

`colour_space.glsl`, `lighting.glsl`, `materials.glsl`, `weather.glsl`, `atmosphere.glsl`, `fog.glsl`, and `water.glsl` have guards and explicit responsibilities. The visual code uses no material-name guessing: ice-specific treatment awaits a safe material-ID path and is not faked from texture colour.

## Quality tiers

Potato compiles out face, material, analytic cloud, water, weather, and analytic-sky helpers. Low enables their lowest direct-path tiers. Balanced raises face/material, cloud, and water quality. High and Ultra raise only bounded analytical tiers (water vertex motion, face response, cloud underside/sun response, and weather); they do not silently create a shadow or post-processing pipeline.

Sky is a low-order elevation/horizon blend with continuous sun-elevation twilight, loader sky/fog colour integration, weather desaturation, and a direction-derived sun/moon halo on the untextured background. Textured celestial sprites remain intact for compatibility; this avoids treating their rectangular texture as a glow source. Clouds retain one texture sample and gain profile-gated underside/directional response. Water uses a bounded frame-time vertex wave plus a tuned fourth-power Fresnel-inspired sky-reflection/transmission approximation, with no depth texture or SSR. Its 0.035 base reflectance is artistic tuning, not a physical-water claim.

For an underwater camera, the ordinary fragment fog path reads the compatibility-surface `isEyeInWater` and `nightVision` uniforms. Low through Ultra keep loader `fogColor` as the anchor, apply a restrained red-reducing tint to the fog endpoint, and slightly strengthen the already monotonic fog factor. This is not volumetric lighting or Beer-Lambert attenuation: it adds no texture read, depth input, pass, or exponential/power operation. Potato preserves loader fog colour and does not compile this colour math.

## Validation boundary

Structural validation checks 48 stages, includes, guards, pair varyings, profile matrices, option ranges, and one-colour-output policy. Generated source expands includes and uses `glslangValidator -E` to evaluate all declared profiles, dimensions, and two loader macro models; it also rejects a Potato analytical-water/terrain-normal regression and celestial shading surviving a dimension wrapper. Standalone `glslangValidator` then compiles that evaluated corpus, but neither it nor the mocked portability matrix validates Iris/Oculus patched source, a real GPU, or visual output.
