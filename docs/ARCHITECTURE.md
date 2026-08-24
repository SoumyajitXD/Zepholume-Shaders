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

V1.0.2 keeps that boundary intact. Its improvements come from better direct lighting, atmospheric behaviour, water response, profile compile-outs, and hot-path cleanup rather than new framebuffer choreography.

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

## V1.0.2 lighting model

V1.0.2 strengthens the direct environmental model without adding temporal state or extra passes.

### Sun and moon

Overworld directional lighting uses loader-provided sun and moon directions with a storm-softened response. Crucially, the directional term is modulated by **skylight**, reducing unrealistic sun/moon shading inside caves and dark interiors.

### Block-light warmth

Warmth is based on **block-light dominance relative to skylight** rather than applying a fixed orange bias whenever block light exists. This keeps daylight scenes from being unnecessarily warmed while allowing genuinely block-lit interiors to retain richer incandescent character.

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

V1.0.2 aligns analytical sky/horizon and fog curves more closely so twilight and night transitions are less likely to expose horizon seams.

Clouds retain one texture sample and use profile-gated directional response. V1.0.2 adds sun/moon rim treatment, underside density shaping, and restrained twilight flank warmth without turning clouds into a volumetric renderer.

## Water

Water remains part of the direct path rather than a separate reflection/refraction renderer.

V1.0.2 uses a **tuned fourth-power Fresnel-inspired approximation** with an intentionally artistic base reflectance around 0.035, dual-lobe celestial specular response, horizon extinction, and storm softening.

This is **not** conventional fifth-power Fresnel-Schlick and is not presented as a physically based water model.

Balanced and higher profiles can use bounded frame-time-driven vertex waves. The implementation still uses no depth texture, SSR, simulation buffer, temporal accumulation, or extra render pass.

## Underwater fog

Low through Ultra can apply a restrained underwater fog tint using the shader-loader compatibility inputs already available to the fragment path and the existing fog distance. Potato preserves the loader fog colour exactly.

This is a colour/fog adjustment, not volumetric lighting or Beer-Lambert simulation. It adds no texture read, depth input, extra pass, or heavy attenuation model.

## Hot-path cleanup

V1.0.2 reduces redundant vector work:

- the shared surface normal is normalised once on the generic fragment path and reused across lighting/material/water logic
- redundant sky direction normalisations were removed
- daylight/twilight elevation helpers use faster bounded inverse-square-root-based calculations
- profile/dimension compile-outs prevent some irrelevant analytical work from reaching final variants

No specific FPS gain should be inferred from these changes without controlled runtime benchmarking.

## Quality profiles

- **Potato**: direct grade and loader sky/fog; optional analytical systems compiled out
- **Low**: lowest bounded face/cloud/water/weather tiers and restrained underwater tint
- **Balanced**: default material/atmospheric baseline plus animated low-amplitude water
- **High**: higher bounded analytical detail
- **Ultra**: maximum current Zepholume analytical tiers without renderer expansion

`Ultra Lite` remains a deprecated Low compatibility alias.

See [Quality Profiles](PROFILES.md).

## Validation boundary

Structural validation covers shader stages, recursive includes, guards, pair interfaces, profile matrices, option ranges, and the one-colour-output policy. Generated source is evaluated across declared profiles, dimensions, and loader macro models before standalone `glslangValidator` compilation.

Those checks can catch source and preprocessing regressions. They cannot prove:

- Iris/Oculus-patched source compilation
- GPU driver behaviour
- visual correctness
- runtime profile switching
- gameplay performance
- cross-vendor parity

The final V1.0.2 package still requires real loader/runtime validation before those claims are justified.

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
