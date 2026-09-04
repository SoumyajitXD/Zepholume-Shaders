# Architecture Overview

Zepholume is designed as a lightweight, direct-path Minecraft Java shader pack. Its architecture favours predictable rendering cost, portability, and maintainability over stacking expensive effects simply because they exist.

## Core rendering boundary

The current shader source is built around **GLSL 330 compatibility**, **24 vertex/fragment program pairs**, and a **single colour target** (`gl_FragData[0]`).

The project intentionally avoids heavyweight renderer subsystems such as:

- shadow-map passes
- composite/deferred post-processing chains
- SSR
- SSAO
- bloom pipelines
- temporal history/TAA
- volumetric pipelines
- ray tracing
- compute shaders
- geometry shaders
- tessellation shaders
- SSBO/image-based rendering paths
- unnecessary extra full-resolution colour targets

This boundary is a product decision, not an unfinished shopping list.

V1.0.3 keeps that boundary intact. Its improvements come from tighter direct lighting, better ambient depth, refined higher-tier water/cloud response, dead-code removal, and stronger regression validation rather than new framebuffer choreography.

## Shared shader design

Zepholume uses shared GLSL libraries so common behaviour is defined once instead of copied across dozens of stages. Responsibilities are separated across areas such as:

- colour-space and grading logic
- lighting response
- material response
- atmospheric treatment
- fog
- weather
- water
- profile/quality capability selection

Profile selection is authoritative: the selected Potato/Low/Balanced/High/Ultra baseline caps the capability macros available to later code. Lower user overrides can reduce work but cannot enable capabilities above that baseline.

## V1.0.3 lighting model

V1.0.3 strengthens the direct environmental model without adding temporal state or extra passes.

### Sun, moon, and skylight gating

Overworld directional lighting uses loader-provided sun and moon directions with storm-softened response. Directional contribution remains modulated by skylight so caves and enclosed interiors do not behave as though celestial light passes through solid terrain.

V1.0.3 restores exact Hermite `smoothstep` behaviour for the skylight gate while retaining named compile-time reciprocal range constants. The intent is mathematical equivalence and clearer validation, not an unsupported FPS claim.

Balanced, High, and Ultra also add skylight occlusion for downward-facing facets and partial overhangs, improving depth where orientation and exposure imply less direct sky contribution.

### Block-light warmth

Warmth is based on **block-light dominance relative to skylight** rather than applying a fixed orange bias whenever block light exists. V1.0.3 restores the exact Hermite `smoothstep` transition for that response as well.

### Ambient irradiance

High and Ultra add a bounded dual-hemisphere ambient term: cooler sky-dome fill for upward-facing surfaces and restrained warmer ground bounce for downward-facing surfaces. This remains an analytical direct-path approximation; there is no GI buffer, ray tracing, temporal accumulation, or extra pass.

### Nether and End

Dimension wrappers isolate Nether and End lighting from Overworld celestial calculations. The Nether uses a bounded cavern-style ambient gradient; the End uses a restrained void-grounded ambient fill. Irrelevant Overworld sun/moon work is compiled out.

## Scene treatment

The generic scene route remains bounded:

1. sample/preserve Minecraft-provided texture and vertex data
2. decode into the working colour space
3. apply bounded face/material/weather response
4. apply controlled exposure, contrast, saturation, temperature, dimension tone, and highlight compression
5. encode back to display space
6. apply atmosphere/fog
7. preserve source alpha and write the single colour target

First-person rendering uses a restrained separate grade so scene contrast does not over-amplify hand colours.

## Sky, clouds, and fog

The analytical Overworld sky uses low-order elevation and horizon blending, loader sky/fog colour integration, weather desaturation, and direction-derived celestial glow.

Sky/horizon and fog curves remain aligned to reduce visible atmospheric seams through twilight and night transitions.

Clouds retain one texture sample and use profile-gated directional response. High and Ultra add top-facet solar rim highlighting in V1.0.3 while preserving the bounded direct-path treatment.

Unreachable fog-scattering and foliage-response branches were removed rather than carried forward as dead profile code.

## Water

Water remains part of the direct path rather than a separate reflection/refraction renderer.

V1.0.3 removes the active water fragment path's redundant working-space encode/decode round trip so water feeds the existing linear scene grade directly.

Lower water tiers retain the V1.0.2 **tuned fourth-power Fresnel-inspired approximation**. High and Ultra refine that response to a **fifth-power Fresnel-Schlick-shaped curve**. This is an intentional higher-tier visual change, not a claim that the entire water model is physically based.

Balanced and higher profiles can use bounded frame-time-driven vertex waves. The implementation still uses no depth texture, SSR, simulation buffer, temporal accumulation, or extra render pass.

## Underwater fog

Low through Ultra can apply a restrained underwater fog tint using the shader-loader compatibility inputs already available to the fragment path and the existing fog distance. Potato preserves the loader fog colour exactly.

This is a colour/fog adjustment, not volumetric lighting or Beer-Lambert simulation. It adds no texture read, depth input, extra pass, or heavy attenuation model.

## Hot-path and source cleanup

V1.0.3 continues the project's bias toward removing unnecessary work instead of adding speculative micro-optimisations:

- the active water fragment path no longer performs a redundant working-space encode/decode round trip
- exact Hermite transition behaviour is preserved with named reciprocal constants that are easier to validate
- unreachable fog-scattering and foliage-response branches were deleted
- profile/dimension compile-outs continue to prevent irrelevant analytical work from reaching final variants

No specific FPS gain should be inferred from these changes without controlled runtime benchmarking.

## Quality profiles

- **Potato**: direct grade and loader sky/fog; optional analytical systems compiled out
- **Low**: lowest bounded face/cloud/water/weather tiers and restrained underwater tint
- **Balanced**: default material/atmospheric baseline, animated low-amplitude water, and skylight occlusion for downward/overhung facets
- **High**: adds dual-hemisphere ambient fill, refined fifth-power water response, and cloud solar-rim treatment
- **Ultra**: maximum current Zepholume analytical tiers without renderer expansion

`Ultra Lite` remains a deprecated Low compatibility alias.

See [Quality Profiles](PROFILES.md).

## Validation boundary

Structural validation covers shader stages, recursive includes, guards, pair interfaces, profile matrices, option ranges, and the one-colour-output policy. Generated source is evaluated across declared profiles, dimensions, and loader macro models before standalone `glslangValidator` compilation.

V1.0.3 also adds deterministic mathematical regression coverage for release-sensitive shader arithmetic and keeps compatibility/benchmark documentation explicitly scoped to the evidence collected.

Those checks can catch source, preprocessing, and numerical regressions. They cannot prove:

- Iris/Oculus-patched source compilation
- GPU driver behaviour
- visual correctness
- runtime profile switching
- gameplay performance
- cross-vendor parity

V1.0.3 still requires real loader/runtime visual qualification and controlled benchmarking before those claims are justified.

## Performance philosophy

Zepholume optimises for both rendering cost and frame-time behaviour. A shader that produces a pretty screenshot but stutters badly in motion has failed half the job.

Architectural priorities are:

1. correctness
2. stable visual behaviour
3. frame-time consistency
4. portability
5. maintainability
6. visual improvement per unit of GPU cost

Raw feature count is intentionally not on that list.

## Source tree

The maintained implementation and developer tooling live under:

```text
/Zepholume-Shaders
```

That source area contains shader programs, shared libraries, validation/benchmark material, and deeper implementation documentation. This public architecture page is intentionally an overview rather than a duplicate of every developer note.
