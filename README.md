# Zepholume Shaders

**Atmospheric lighting. Polished visuals. Practical performance.**

Zepholume Shaders is a performance-conscious shader pack for **Minecraft Java Edition**. It is built to make Minecraft feel richer, deeper, and more atmospheric without treating frame rate as disposable.

![Vanilla vs Zepholume — Comparison 01](Screenshots/01-vanilla-vs-zepholume.png)

## Current release

**Zepholume Shaders V1.0.2**  
Release archive: `Zepholume-Shaders-1.0.2.zip`

V1.0.2 targets **Minecraft Java 1.20.1** and is designed for the Iris/Fabric/Sodium and Oculus/Forge/Embeddium shader ecosystems.

Prepared validation environments currently use:

- **Iris 1.7.6 + Sodium 0.5.13** on Minecraft 1.20.1
- **Oculus 1.8.0 + Embeddium 0.3.31 + Forge 47.4.22** on Minecraft 1.20.1
- **Java 17**

> Runtime verification for the final V1.0.2 package is still pending. Static GLSL compilation and isolated environment/package checks do **not** prove Iris/Oculus-patched compilation, real-GPU rendering, screenshots, FPS, or cross-vendor behaviour.

OptiFine is not a supported target for Zepholume.

## What's new in V1.0.2

V1.0.2 focuses on making the existing direct-path renderer behave more intelligently rather than adding heavyweight new pipelines.

Highlights include:

- skylight-grounded sun/moon directional lighting to reduce cave and interior celestial leakage
- relative block-light warmth based on block light versus skylight, reducing daytime orange tinting
- tuned fourth-power Fresnel-inspired water response with dual-lobe celestial specular, horizon extinction, and storm softening
- profile-gated underwater fog tint from Low through Ultra while Potato preserves loader fog colour
- sun/moon directional cloud rim lighting, underside shaping, and restrained twilight warmth
- analytical sky/horizon and fog alignment to reduce twilight/night seam artifacts
- Nether and End lighting isolation that compiles out irrelevant Overworld celestial work
- hot-path cleanup: one shared surface-normal normalization, fewer sky direction normalizations, and faster elevation helpers
- stronger generated-source and structural regression checks for profile compile-outs and renderer-boundary violations

Water's reflectance model is deliberately a **tuned fourth-power Fresnel-inspired approximation**, not conventional fifth-power Fresnel-Schlick and not a physically based water simulation.

No FPS uplift is claimed without controlled runtime benchmarking. Static shader complexity is useful engineering evidence; it is not a benchmark wearing a fake moustache.

## What Zepholume focuses on

- Atmospheric lighting and environmental colour
- Controlled exposure, contrast, temperature, and scene depth
- Refined fog, sky, cloud, weather, water, and underwater treatment
- Multiple quality profiles with real compile-time capability boundaries
- Stable frame pacing and bounded rendering cost
- A deliberately maintainable shared-GLSL architecture
- Broad GLSL portability rather than vendor-specific tricks

Zepholume does **not** chase a feature checklist at any cost. The rendering design stays intentionally lean: no shadow-map pipeline, SSR, SSAO, bloom pipeline, temporal history/TAA, volumetric pipeline, ray tracing, compute shaders, geometry/tessellation stages, SSBO/image pipeline, or a pile of extra full-resolution colour buffers.

## Quality profiles

| Profile | Intended use | Direct-path behaviour |
| --- | --- | --- |
| **Potato** | Weak/integrated GPUs and compatibility triage | Direct grade and loader sky/fog; analytical face/material/cloud/water/weather/underwater-colour work compiled out |
| **Low** | Lower-end hardware | Directional face/cloud response, bounded analytical water/weather, subtle underwater fog tint |
| **Balanced** | General gameplay | Default; adds stronger material response, atmospheric depth, continuous time transitions, and animated low-amplitude water |
| **High** | Systems with more headroom | Higher bounded face/cloud/water/weather detail within the same architecture |
| **Ultra** | Maximum current Zepholume quality | Highest bounded analytical tiers; still no shadow/post/temporal renderer expansion |

`Balanced` is the default and recommended starting point. `Ultra Lite` remains a deprecated compatibility alias for Low. See [Profiles](docs/PROFILES.md).

## Installation

1. Use a **Minecraft 1.20.1** instance with a compatible Iris or Oculus shader setup.
2. Download `Zepholume-Shaders-1.0.2.zip`.
3. Put the ZIP directly in that instance's `shaderpacks` folder.
4. Open Minecraft's shader-pack menu and select **Zepholume Shaders**.
5. Start with the **Balanced** profile, then tune down or up for your hardware.

Do not extract the release ZIP. For compatibility testing, prefer a disposable or isolated instance over an irreplaceable modpack save.

Full instructions: [Installation Guide](docs/INSTALLATION.md)

## Compatibility and validation status

V1.0.2 currently has strong **static/source validation** but incomplete **runtime validation**.

The maintained source validation covers the declared profile/dimension matrix and standalone compilation of **210 unique expanded GLSL stages**. That can catch source, preprocessor, interface, and architecture regressions; it cannot establish loader-patched compilation, driver behaviour, visual correctness, or measured performance.

See [Compatibility](docs/COMPATIBILITY.md) for the public compatibility boundary.

## Documentation

- [Installation](docs/INSTALLATION.md)
- [Compatibility](docs/COMPATIBILITY.md)
- [Quality Profiles](docs/PROFILES.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Development](docs/DEVELOPMENT.md)
- [Shader source and developer tooling](Zepholume-Shaders/)

## Repository layout

```text
Zepholume-Shaders/
├─ README.md                 Project overview
├─ docs/                     Public project documentation
├─ Screenshots/              Comparison screenshots
├─ Releases/                 Release area
├─ Zepholume-Shaders/        Shader source and development tooling
├─ curseforge-description.html
├─ LICENSE
└─ NOTICE
```

## Design philosophy

A beautiful still image is not enough if moving the camera turns the game into a slideshow. Zepholume treats performance, stability, portability, and maintainability as part of visual quality—not cleanup work for later.

The project prefers bounded analytical effects, shared GLSL libraries, compile-time quality control, and simple rendering paths over architecture cosplay and expensive effects with poor visual return.

## Development status

Zepholume is actively developed. Visual tuning, optimisation, compatibility work, and architecture improvements may continue between releases. Screenshots represent the shader at the time they were captured and can differ slightly from later builds.

## License

Copyright © 2026 Soumyajit Biswas.

Licensed under the [Apache License 2.0](LICENSE).
