# Architecture Overview

Zepholume is designed as a lightweight, direct-path Minecraft Java shader pack. Its architecture favours predictable rendering cost, portability, and maintainability over stacking expensive effects simply because they exist.

## Core rendering boundary

The current shader source is built around GLSL 330 compatibility and a direct colour path. The project intentionally avoids heavyweight renderer subsystems such as:

- shadow-map passes
- composite/post-processing chains
- SSR
- SSAO
- temporal history/TAA
- volumetric pipelines
- ray tracing
- compute shaders
- geometry shaders
- tessellation shaders
- SSBO/image-based rendering paths
- unnecessary extra full-resolution colour targets

This boundary is a product decision, not an unfinished shopping list.

V1.0.1 keeps that boundary intact: its visual improvements come from better analytical lighting, atmosphere, water behaviour, compile-time tiering, and defensive shader maths rather than new render passes or buffer chains.

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

That keeps quality changes and bug fixes localised and reduces the chance of visually similar programs silently drifting apart.

## Continuous environmental response

V1.0.1 strengthens the shared environmental model around continuous sun elevation and twilight response.

Rather than treating terrain, sky, clouds, and fog as unrelated colour systems, the shader derives their day/twilight behaviour from a common directional context. This allows sunrise, sunset, night, horizon colour, cloud tone, fog, and scene lighting to transition more coherently without requiring temporal history or additional passes.

The same philosophy applies to weather and dimension treatment: rain desaturation and Overworld/Nether/End fog adjustments stay bounded and purpose-specific instead of becoming a separate atmospheric renderer.

## Scene treatment

The direct scene path is built around bounded operations such as:

1. preserve/sample Minecraft-provided colour and texture data
2. apply controlled lighting/material response
3. derive bounded environmental response from scene/directional inputs
4. apply controlled exposure, contrast, saturation, and temperature treatment
5. compress highlights without requiring a heavyweight tone-mapping pipeline
6. apply atmospheric/fog response
7. output the final colour through the primary target

Special paths such as sky, celestial geometry, clouds, water, weather, and first-person rendering can use purpose-specific treatment instead of pretending every surface is generic terrain.

## Water

Water remains part of the direct-path design rather than a separate reflection/refraction renderer.

From V1.0.1, **Balanced and higher profiles** can use subtle frame-time-driven water movement. Lower tiers avoid paying for that path. The goal is visible motion at bounded cost, not screen-space reflections, simulation, temporal accumulation, or another framebuffer hierarchy.

## Defensive shader maths

V1.0.1 also hardens shared maths against malformed or unusual geometry inputs. Normalization paths are written defensively so zero-length or invalid vectors are less likely to propagate NaNs or other invalid values into later lighting calculations.

This is especially important in a modded ecosystem where geometry and vertex data can come from code outside Zepholume's control.

## Quality profiles

Profile selection is intended to cap the amount of work a shader stage is allowed to perform.

- **Potato** removes or minimises optional detail work and compiles out additional analytical sky/cloud calculations.
- **Low** enables lightweight analytical treatment while keeping higher-tier animated-water work disabled.
- **Balanced** raises selected material/atmospheric quality and enables subtle animated water.
- **High** raises bounded analytical tiers.
- **Ultra** uses the highest Zepholume tiers without crossing into a fundamentally heavier renderer architecture.

Profile gates should remove avoidable work at compile time where practical. A lower tier executing all the same expensive code and merely multiplying the result by a smaller number would be fake scaling.

See [Quality Profiles](PROFILES.md).

## Performance philosophy

Zepholume optimises for both average rendering cost and frame-time behaviour. A shader that produces a pretty screenshot but stutters badly in motion has failed half the job.

Architectural priorities are therefore:

1. correctness
2. stable visual behaviour
3. frame-time consistency
4. portability
5. maintainability
6. visual improvement per unit of GPU cost

Raw feature count is intentionally not on that list.

V1.0.1 removes redundant shader work where identified, but no specific FPS gain should be inferred without controlled runtime benchmarking on a defined hardware/software stack.

## Portability

The source avoids depending on vendor-specific GLSL features and keeps the baseline compatible with the shader-loader ecosystem used by Iris and Oculus. Static validation can catch source/preprocessor/interface mistakes, but only real runtime testing can prove loader, driver, and visual behaviour on a specific machine.

Defensive maths, common-denominator GLSL, and compile-time capability selection are intended to reduce avoidable differences across NVIDIA, AMD, and Intel hardware without pretending that every driver/mod combination has been exhaustively tested.

## Source tree

The maintained implementation and developer tooling live under:

```text
/Zepholume-Shaders
```

That source area includes shader programs, shared libraries, validation/benchmark material, and deeper implementation documentation. This public architecture page is intentionally an overview rather than a duplicate of every internal technical note.
