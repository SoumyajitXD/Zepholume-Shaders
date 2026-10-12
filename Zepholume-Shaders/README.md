# Zepholume Shaders

Zepholume is an original, direct-path Minecraft Java shader pack for clean survival play. It focuses on controlled exposure, atmospheric depth, and stable frame pacing—not heavyweight cinematic effects.

## Status and supported evidence

**V1.0.5 development.** The preserved **V1.0.4 final release** remains available unchanged. V1.0.5 restores the missing per-surface Minecraft lightmap multiplication, complete legacy dimension-wrapper topology, texture-matrix routing, water-only translucent treatment, and loader-owned lava/powder-snow fog. It is not release-ready until loader-rendered cave/night, dimension, water, and profile QA completes. The exact-zero water celestial-specular gate remains retained, but neither it nor V1.0.5 has a measured FPS claim. The isolated test lanes are Fabric/Iris 1.7.6 + Sodium 0.5.13 and Forge/Oculus 1.8.0 + Embeddium 0.3.31, using Java 17.

Minecraft 26.1.2 installations exist locally but no Zepholume evidence is associated with them. OptiFine is not supported or tested.

## Profiles

Balanced is the default. Selecting a profile applies its full baseline; the grouped UI provides bounded reductions/scene-grade overrides without enabling work above the selected tier. The five selectable profiles are Potato, Low, Balanced, High, and Ultra. Older `Ultra Lite` selections should be changed to Low.

| Profile | Direct-path features |
|---|---|
| Potato | Direct grade and loader sky; above-water atmospheric fog colour remains, underwater fog colour preserves the loader value; no analytical water, cloud, or face work |
| Low | Directional face/cloud response, bounded fourth-power water reflectance, weather, and subtle underwater fog tint |
| Balanced | Adds material orientation response, animated low-amplitude water, underwater depth tint, and continuous time transitions |
| High | Higher face/cloud/water/weather tiers; still one colour target and no shadows/temporal effects |
| Ultra | Highest bounded analytical tiers; no SSR, TAA, volumetrics, bloom, or extra colour buffers |

## Install

1. Use an isolated disposable 1.20.1 Iris or Oculus instance.
2. For the frozen release, copy `Zepholume-Shaders-1.0.4.zip` into `shaderpacks`; use the current V1.0.5 development ZIP only in separately provisioned disposable test instances.
3. Select Zepholume and choose Balanced, then use the Profile menu for other baselines. Confirm the selected ZIP name and hash before collecting test evidence.
4. Retain complete `latest.log` and patched shaders after every loader test.

## Rendering boundary

The pack has 24 program pairs and writes only `gl_FragData[0]`. Potato, Low, and Balanced remain a direct one-colour-target route; High/Ultra only raise analytical quality within that same architecture. There are no shadows, SSR, SSAO, bloom, volumetrics, ray tracing, temporal history, compute, geometry/tessellation stages, images, or SSBOs. Water uses a tuned fourth-power grazing response through Balanced; High and Ultra intentionally use a fifth-power Fresnel-Schlick-shaped curve. Neither is a physically based water model.

Standalone GLSL compilation supports an explicit trusted native backend, a configurable Kali/WSL backend, and a controlled Linux CI backend using distribution-maintained `glslang-tools`. It compiles generated profile/dimension/loader-model variants in OpenGL GLSL mode, records supported vertex/fragment link checks, and rejects warnings. This does not emulate Iris/Oculus patched sources or establish loader, visual, or performance compatibility. See the [Phase 7 development report](docs/PHASE7_REPORT.md), [architecture](docs/ARCHITECTURE.md), [profile guide](docs/PROFILE_GUIDE.md), [benchmark protocol](docs/BENCHMARK_PROTOCOL.md), and [visual regression protocol](docs/VISUAL_REGRESSION.md).
