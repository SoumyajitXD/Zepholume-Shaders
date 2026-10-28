# Zepholume Shaders

Zepholume is an original, direct-path Minecraft Java shader pack for clean survival play. It focuses on controlled exposure, atmospheric depth, and stable frame pacing—not heavyweight cinematic effects.

## Status and supported evidence

**V1.0.6 final release.** This release incorporates the validated hand-lightmap, triangle-interpolation, camera-space and fog-range corrections. The final production ZIP is `Zepholume-Shaders-1.0.6.zip`. It is exported under the user's explicit decision to ship with incomplete Minecraft runtime qualification. Offline compilation and synthetic GPU fixtures verify their stated source contracts; **Minecraft runtime qualification: NOT TESTED** for this final artifact. See the [final verification report](docs/V1.0.6_FINAL_RELEASE.md), [release notes](docs/V1.0.6_RELEASE_NOTES.md) and [compatibility notes](docs/V1.0.6_FINAL_COMPATIBILITY.md).

The analytical water reflection model has no local skylight occlusion, so reflected sky and celestial highlights can remain in covered water. The source limitation is confirmed; its appearance in actual Minecraft scenes is unverified. Waterfall and hand/item visual outcomes, transparency composition, loader transformation and game FPS remain unverified. Historical Phase 7 Fabric 26.1.2/Iris evidence does not qualify this final artifact. OptiFine is unsupported. Other Minecraft version families and GPU vendors carry no runtime compatibility guarantee.

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

1. Use a Minecraft Java instance with a matching Iris installation. Oculus uses the legacy compatibility path but remains unqualified for this release; see the compatibility notes for the exact evidence boundary.
2. Copy `Zepholume-Shaders-1.0.6.zip` directly into that instance's `shaderpacks` directory; keep the ZIP intact.
3. Select the pack in the shader menu and choose Balanced, the recommended default. Potato, Low, High and Ultra are available through the Profile control.
4. If checking a rendering problem, retain the exact ZIP hash, `latest.log` and loader-patched shader output. Installation and pack selection alone do not establish visual correctness.

## Rendering boundary

The pack has 14 root program pairs, with complete wrappers for three dimensions, and writes only `gl_FragData[0]`. Potato, Low, and Balanced remain a direct one-colour-target route; High/Ultra only raise analytical quality within that same architecture. There are no shadows, SSR, SSAO, bloom, volumetrics, ray tracing, temporal history, compute, geometry/tessellation stages, images, or SSBOs. Water uses a tuned fourth-power grazing response through Balanced; High and Ultra intentionally use a fifth-power Fresnel-Schlick-shaped curve. Neither is a physically based water model.

Standalone GLSL compilation supports an explicit trusted native backend, a configurable Kali/WSL backend, and a controlled Linux CI backend using distribution-maintained `glslang-tools`. It compiles generated profile/dimension/loader-model variants in OpenGL GLSL mode, records supported vertex/fragment link checks, and rejects warnings. This does not emulate Iris/Oculus patched sources or establish loader, visual, or performance compatibility. See the [Phase 7 development report](docs/PHASE7_REPORT.md), [architecture](docs/ARCHITECTURE.md), [profile guide](docs/PROFILE_GUIDE.md), [benchmark protocol](docs/BENCHMARK_PROTOCOL.md), and [visual regression protocol](docs/VISUAL_REGRESSION.md).
