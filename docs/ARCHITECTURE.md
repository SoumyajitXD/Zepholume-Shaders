# Architecture Overview

Zepholume is designed as a lightweight, direct-path Minecraft Java shader pack. Its architecture favours predictable rendering cost, portability, and maintainability over stacking expensive effects simply because they exist.

## Core rendering boundary

The current shader source is built around **GLSL 330 compatibility**, **14 root vertex/fragment program pairs** (with complete Overworld/Nether/End wrapper sets; 112 program files total), and a **single colour target** (`gl_FragData[0]`).

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

V1.0.6 keeps that boundary intact. It preserves V1.0.5's scene lightmap, skylight, material, dimension and settings corrections, and adds verified source-level repairs for first-person hand lightmap routing, affine view-ray/fragment-local distance interpolation, camera-space world-up handling, and short positive fog ranges. The exact-zero water celestial-specular gate from V1.0.4 is retained.

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

## Lighting model (V1.0.6)

V1.0.6 retains the established direct environmental model without temporal state or extra passes. The key new work corrects camera-basis calculations, fog input handling and first-person lightmap routing rather than globally changing contrast.

### Sun, moon, and skylight gating

Overworld directional lighting uses loader-provided sun and moon directions with storm-softened response. Directional contribution remains modulated by skylight so caves and enclosed interiors do not behave as though celestial light passes through solid terrain.

V1.0.6 preserves the exact Hermite `smoothstep` skylight-gate behaviour and named compile-time reciprocal range constants established by the current baseline. The intent remains mathematical correctness and clear validation, not an unsupported FPS claim.

Balanced, High, and Ultra retain skylight occlusion for downward-facing facets and partial overhangs, improving depth where orientation and exposure imply less direct sky contribution.

### Block-light warmth

Warmth is based on **block-light dominance relative to skylight** rather than applying a fixed orange bias whenever block light exists. V1.0.6 preserves the exact Hermite `smoothstep` transition used by that response.

### Ambient irradiance

High and Ultra add a bounded dual-hemisphere ambient term: cooler sky-dome fill for upward-facing surfaces and restrained warmer ground bounce for downward-facing surfaces. This remains an analytical direct-path approximation; there is no GI buffer, ray tracing, temporal accumulation, or extra pass.

### Nether and End

Dimension wrappers isolate Nether and End lighting from Overworld celestial calculations. The Nether uses a bounded cavern-style ambient gradient; the End uses a restrained void-grounded ambient fill. Irrelevant Overworld sun/moon work is compiled out.

## Scene treatment

The generic scene route remains bounded:

1. sample/preserve Minecraft-provided texture and vertex data, applying the loader lightmap in lit program routes
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

Clouds retain one texture sample and use profile-gated directional response. High and Ultra retain top-facet solar rim highlighting while preserving the bounded direct-path treatment.

Unreachable fog-scattering and foliage-response branches were removed rather than carried forward as dead profile code.

## Water

Water remains part of the direct path rather than a separate reflection/refraction renderer.

V1.0.6 retains the earlier removal of the redundant working-space encode/decode round trip and the V1.0.4 exact-zero gate around inactive water celestial-specular lobes. It also limits analytical water shading to classified Minecraft water rather than other translucent geometry. When the existing draw-uniform sun or moon contribution is exactly zero, lobe-only work can be skipped while the non-zero path keeps its established arithmetic order.

Lower water tiers retain the V1.0.2 **tuned fourth-power Fresnel-inspired approximation**. High and Ultra refine that response to a **fifth-power Fresnel-Schlick-shaped curve**. This is an intentional higher-tier visual change, not a claim that the entire water model is physically based.

Balanced and higher profiles can use bounded frame-time-driven vertex waves. The implementation still uses no depth texture, SSR, simulation buffer, temporal accumulation, or extra render pass.

## V1.0.6 first-person, interpolation and fog correctness

V1.0.6 moves the hand lightmap flag ahead of the shared fragment include in all four hand fragment routes. The shared lit path applies environmental lightmap multiplication before hand grading. Offline synthetic irradiance behaves correctly; actual empty-hand and held-item rendering still requires Minecraft verification.

Water/scene view rays now interpolate affine information and calculate distance per fragment, avoiding the reproducible triangle-diagonal discontinuities caused by interpolating normalized corner rays or their lengths. The correction passed synthetic GPU fixtures; a real waterfall image has not been requalified.

Camera-space world-up computations align with normals and directions in view space. Fog preserves small, valid positive loader ranges and defines safe equal/reversed-endpoint behavior. No new pass, buffer or speculative global exposure correction was added.

**Known model limitation:** analytical water sky reflections and celestial highlights have no dependable local directional skylight-occlusion input. Covered/nighttime water can receive such terms even when blocked from the sky; severity in the final Minecraft build remains unverified. See [V1.0.6 release evidence](../Zepholume-Shaders/docs/V1.0.6_FINAL_RELEASE.md).

## Underwater fog

Low through Ultra can apply a restrained underwater fog tint using the shader-loader compatibility inputs already available to the fragment path and the existing fog distance. Potato preserves the loader fog colour exactly.

This is a colour/fog adjustment, not volumetric lighting or Beer-Lambert simulation. It adds no texture read, depth input, extra pass, or heavy attenuation model.

## Hot-path and source cleanup

V1.0.6 continues the project's bias toward targeted correctness fixes instead of speculative micro-optimisations:

- V1.0.4's inactive-water celestial-specular exact-zero gate remains retained
- V1.0.5 corrected lightmap multiplication on generic lit scene paths; V1.0.6 additionally enables the lightmap route for four hand programs
- skylight and contrast processing changes target previously reported black crush and full-bright bugs, pending in-game proof
- the non-zero water path preserves its established arithmetic order rather than substituting an approximation
- the active water fragment path retains the earlier removal of its redundant working-space encode/decode round trip
- exact Hermite transition behaviour remains preserved with named reciprocal constants that are easier to validate
- profile/dimension compile-outs continue to prevent irrelevant analytical work from reaching final variants
- the experimental fog endpoint hoist remains deferred rather than being promoted without runtime evidence

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

V1.0.6 retains mathematical/source regressions. Its final offline validation reported 272 standalone GLSL stages, 420 links and 630 mocked portability cases, with native Intel GPU fixture draws for hand, water and camera. The latest hosted V1.0.6 main-branch CI runs are **red**: the regression clean-tree check detects test-driven modifications to three tracked shader-subtree files. Other jobs passed, but the required aggregate did not. No runtime compatibility or FPS claim follows from the offline checks.

Those checks can catch source, preprocessing, and numerical regressions. They cannot prove:

- Iris/Oculus-patched source compilation
- GPU driver behaviour
- visual correctness
- runtime profile switching
- gameplay performance
- cross-vendor parity

V1.0.6 still requires real loader/runtime visual qualification and controlled benchmarking before those claims are justified.

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
