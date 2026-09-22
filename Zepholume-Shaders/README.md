# Zepholume Shaders

Zepholume is an original, direct-path Minecraft Java shader pack for clean survival play. It focuses on controlled exposure, atmospheric depth, and stable frame pacing—not heavyweight cinematic effects.

## Status and supported evidence

**V1.0.4 final release.** It retains the V1.0.3 development baseline and avoids unnecessary water celestial-specular calculations when their contribution is exactly zero. This is not an FPS claim: Iris/Oculus compilation, shader activation, rendering, screenshots, performance, and cross-vendor behaviour remain unverified. The isolated test lanes are Fabric/Iris 1.7.6 + Sodium 0.5.13 and Forge/Oculus 1.8.0 + Embeddium 0.3.31, using Java 17.

Minecraft 26.1.2 installations exist locally but no Zepholume evidence is associated with them. OptiFine is not supported or tested.

## Profiles

Balanced is the default. Selecting a profile applies its full baseline; the grouped UI provides bounded reductions/scene-grade overrides without enabling work above the selected tier. `Ultra Lite` remains as a deprecated alias for Low.

| Profile | Direct-path features |
|---|---|
| Potato | Direct grade and loader sky; above-water atmospheric fog colour remains, underwater fog colour preserves the loader value; no analytical water, cloud, or face work |
| Low | Directional face/cloud response, bounded fourth-power water reflectance, weather, and subtle underwater fog tint |
| Balanced | Adds material orientation response, animated low-amplitude water, underwater depth tint, and continuous time transitions |
| High | Higher face/cloud/water/weather tiers; still one colour target and no shadows/temporal effects |
| Ultra | Highest bounded analytical tiers; no SSR, TAA, volumetrics, bloom, or extra colour buffers |

## Install

1. Use an isolated disposable 1.20.1 Iris or Oculus instance.
2. Copy `Zepholume-Shaders-1.0.4.zip` into `shaderpacks`.
3. Select Zepholume and choose Balanced, then use the Profile menu for other baselines.
4. Retain complete `latest.log` and patched shaders after every loader test.

## Rendering boundary

The pack has 24 program pairs and writes only `gl_FragData[0]`. Potato, Low, and Balanced remain a direct one-colour-target route; High/Ultra only raise analytical quality within that same architecture. There are no shadows, SSR, SSAO, bloom, volumetrics, ray tracing, temporal history, compute, geometry/tessellation stages, images, or SSBOs. Water uses a tuned fourth-power grazing response through Balanced; High and Ultra intentionally use a fifth-power Fresnel-Schlick-shaped curve. Neither is a physically based water model.

See [architecture](docs/ARCHITECTURE.md), [profile guide](docs/PROFILE_GUIDE.md), [benchmark protocol](docs/BENCHMARK_PROTOCOL.md), and [visual regression protocol](docs/VISUAL_REGRESSION.md).
