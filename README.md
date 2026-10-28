# Zepholume Shaders

**Atmospheric lighting. Polished visuals. Practical performance.**

Zepholume Shaders is a performance-conscious shader pack for **Minecraft Java Edition**. Its direct-path renderer focuses on atmospheric light, restrained colour, water and environmental detail without adding expensive shadow, reflection or post-processing pipelines.

![Archived vanilla vs Zepholume comparison](Screenshots/01-vanilla-vs-zepholume.png)

> Archival visual comparison; not a verified V1.0.6 before/after capture.

## Current version: V1.0.6

**V1.0.6 source and the final-named ZIP are present in this repository.** The [GitHub archive](Releases/Zepholume-Shaders-1.0.6.zip) has passed extensive offline checks, but **Minecraft runtime and visual qualification remain incomplete**. Final packaging is not proof of universal compatibility.

- **Archive:** [Zepholume-Shaders-1.0.6.zip](Releases/Zepholume-Shaders-1.0.6.zip)
- **Size:** 55,248 bytes; **135 entries**
- **SHA-256:** `F72C149F44E6EE026025215D27886CD50D73252A4FE046E184DDBBB8E552331C`
- **Source:** [Zepholume-Shaders/](Zepholume-Shaders/)
- **Release notes:** [V1.0.6 release notes](Zepholume-Shaders/docs/V1.0.6_RELEASE_NOTES.md)
- **Evidence:** [Final release report](Zepholume-Shaders/docs/V1.0.6_FINAL_RELEASE.md) and [compatibility audit](Zepholume-Shaders/docs/V1.0.6_FINAL_COMPATIBILITY.md)
- **CurseForge:** [Check actual available files](https://www.curseforge.com/minecraft/shaders/zepholume-shaders/files). A GitHub ZIP does not establish that the same version has been uploaded there.

### What's new in V1.0.6

- **Water interpolation:** corrected normalized view-ray and distance interpolation errors that produced triangle-diagonal discontinuities in GPU fixtures. The photographed waterfall still needs a matched Minecraft retest.
- **Hand lightmap:** restored a missing lightmap-routing flag in four hand shader paths. Synthetic hand rendering responds to environmental irradiance instead of remaining full-bright; real held-item behaviour still needs qualification.
- **Camera and fog:** corrected world-up/view-space calculations and preserved short positive fog ranges, with defined handling for equal or reversed endpoints.
- **Stable architecture:** retained water-only material handling, dimensions, profiles and the lightweight renderer, without speculative global brightness adjustments.

The final offline report records **272 GLSL stages, 420 links, 630 mocked portability cases, 63 native hand draws and 52 native water draws** passing, plus other regressions. These do **not** establish Minecraft FPS improvements or cross-loader support.

**Known limitation:** analytical reflections on covered/nighttime water lack reliable local directional skylight occlusion; the gameplay severity remains unverified. The final ZIP also lacks matched hand/water screenshots, loader-patched GLSL, in-game profile/dimension checks and controlled Minecraft frame-time measurements.

**Hosted CI is currently red.** Recent runs failed the regression clean-tree check because tests modified three tracked files inside the shader source folder. Other jobs passed, but the required aggregate failed. See [CI and release qualification](docs/CI_AND_RELEASE_QUALIFICATION.md).

## What Zepholume focuses on

- Atmospheric sky, lighting, fog, clouds and weather
- Controlled exposure, contrast, colour temperature and material response
- Restrained water shading and optional low-amplitude waves
- Five compile-time quality tiers
- Maintainable shared GLSL 330-compatible source
- Portability as an engineering goal, not a blanket GPU guarantee

The renderer intentionally avoids shadow maps, SSR, SSAO, bloom pipelines, temporal history/TAA, volumetric pipelines, ray tracing, compute shaders and additional full-resolution colour passes.

## Quality profiles

| Profile | Intended use | Highlights |
| --- | --- | --- |
| **Potato** | Minimal work / compatibility triage | Scene grade, loader sky and fog; optional analytical work disabled |
| **Low** | Weaker hardware | Bounded face, cloud, weather and water treatment |
| **Balanced** | **Default / recommended** | Material response, atmospheric depth and subtle water waves |
| **High** | More GPU headroom | Refined water, ambient and cloud response |
| **Ultra** | Maximum analytical quality | Highest detail within the same direct-path renderer |

`Ultra Lite` remains a deprecated alias for Low, not a sixth selectable profile. Configuration tests pass; final-ZIP menu visibility in Minecraft is unverified. See [Profiles](docs/PROFILES.md).

## Installation

1. Prepare a Minecraft Java instance with an appropriate **Iris** shader loader (or test the separately unqualified Oculus path).
2. Download the [V1.0.6 ZIP from GitHub](Releases/Zepholume-Shaders-1.0.6.zip), or choose a version **actually listed** on [CurseForge Files](https://www.curseforge.com/minecraft/shaders/zepholume-shaders/files).
3. Copy the intact ZIP to **that instance's** `shaderpacks` directory. Do **not** extract it.
4. Select Zepholume in the shader menu and start with **Balanced**.
5. On errors or visual corruption, keep the full `latest.log` and retest in an isolated instance.

A prior Minecraft **26.1.2 Fabric/Iris** session was observed and the Phase 8 development ZIP was installed, but the **final V1.0.6 ZIP was not tested there**. Historical 1.20.1 Iris/Fabric and Oculus/Forge lanes were staged only. Those facts do not imply that every Minecraft version between 1.20 and 26.3 is supported. OptiFine is not supported or tested.

See [Installation](docs/INSTALLATION.md), [Compatibility](docs/COMPATIBILITY.md) and [Troubleshooting](docs/TROUBLESHOOTING.md).

## Documentation

- [Installation](docs/INSTALLATION.md)
- [Compatibility & evidence](docs/COMPATIBILITY.md)
- [Quality Profiles](docs/PROFILES.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Development](docs/DEVELOPMENT.md)
- [CI and release qualification](docs/CI_AND_RELEASE_QUALIFICATION.md)
- [V1.0.6 release notes](Zepholume-Shaders/docs/V1.0.6_RELEASE_NOTES.md)
- [Source and developer tooling](Zepholume-Shaders/)

## Repository layout

```text
Zepholume-Shaders/
├─ README.md                 Public overview
├─ docs/                     Guides and qualification status
├─ Screenshots/              Archival comparison images
├─ Releases/                 Versioned ZIP archives
├─ Zepholume-Shaders/        Shader source and developer tooling
├─ curseforge-description.html
├─ LICENSE
└─ NOTICE
```

## Reporting a bug

Provide Minecraft and loader versions, profile, GPU/driver, Java, rendering mods, reproduction steps and full `latest.log`. Supply matched images for visual issues when possible. Use [GitHub Issues](https://github.com/SoumyajitXD/Zepholume-Shaders/issues).

## License

Copyright © 2026 Soumyajit Biswas. Licensed under [Apache License 2.0](LICENSE).
