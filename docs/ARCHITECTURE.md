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

## Scene treatment

The direct scene path is built around bounded operations such as:

1. preserve/sample Minecraft-provided colour and texture data
2. apply controlled lighting/material response
3. apply bounded exposure, contrast, saturation, and temperature treatment
4. compress highlights without requiring a heavyweight tone-mapping pipeline
5. apply atmospheric/fog response
6. output the final colour through the primary target

Special paths such as sky, celestial geometry, clouds, water, weather, and first-person rendering can use purpose-specific treatment instead of pretending every surface is generic terrain.

## Quality profiles

Profile selection is intended to cap the amount of work a shader stage is allowed to perform.

- **Potato** removes or minimises optional detail work.
- **Low** enables lightweight analytical treatment.
- **Balanced** raises selected material/atmospheric quality.
- **High** raises bounded analytical tiers.
- **Ultra** uses the highest Zepholume tiers without crossing into a fundamentally heavier renderer architecture.

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

## Portability

The source avoids depending on vendor-specific GLSL features and keeps the baseline compatible with the shader-loader ecosystem used by Iris and Oculus. Static validation can catch source/preprocessor/interface mistakes, but only real runtime testing can prove loader, driver, and visual behaviour on a specific machine.

## Source tree

The maintained implementation and developer tooling live under:

```text
/Zepholume-Shaders
```

That source area includes shader programs, shared libraries, validation/benchmark material, and deeper implementation documentation. This public architecture page is intentionally an overview rather than a duplicate of every internal technical note.