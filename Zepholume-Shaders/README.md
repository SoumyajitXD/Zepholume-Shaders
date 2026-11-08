# Zepholume Shaders

Zepholume is an original, direct-path Minecraft Java shader pack for clean survival play. It focuses on controlled exposure, atmospheric depth, and stable frame pacing—not heavyweight cinematic effects.

## Status and supported evidence

**V1.0.7 final release.** This release incorporates the validated horizon seam blend, directional fog ray correction, Potato dark fog preservation, cave/enclosed water skylight gating, flat waterfall classification, block cloud layering, and hand lightmap lighting. The final production ZIP is `Zepholume-Shaders-1.0.7.zip`. It is exported under the user's explicit decision to finalize V1.0.7 with the strongest available, technically defensible implementation. Horizon blend, pipeline loading, and profile smoke testing are verified in local Fabric 26.1.2 / Iris 1.10.9; broad multi-loader, multi-vendor, and extended gameplay performance remain limited. See [release notes](docs/V1.0.7_RELEASE_NOTES.md) and [final release report](docs/V1.0.7_FINAL_RELEASE.md).

The analytical water reflection model has been gated by local skylight exposure to suppress celestial highlights in caves and enclosed areas. Waterfall interpolation is flat-gated to eliminate diagonal shearing. OptiFine is unsupported. Other Minecraft version families and GPU vendors carry no runtime compatibility guarantee.

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
2. Copy `Zepholume-Shaders-1.0.7.zip` directly into your Minecraft Java instance's `shaderpacks` directory; keep the ZIP intact.
3. Select the pack in the shader menu and choose Balanced, the recommended default. Potato, Low, High and Ultra are available through the Profile control.
4. If checking a rendering problem, retain the exact ZIP hash, `latest.log` and loader-patched shader output. Installation and pack selection alone do not establish visual correctness.

## Rendering boundary

The pack has 14 root program pairs, with complete wrappers for three dimensions, and writes only `gl_FragData[0]`. Potato, Low, and Balanced remain a direct one-colour-target route; High/Ultra only raise analytical quality within that same architecture. There are no shadows, SSR, SSAO, bloom, volumetrics, ray tracing, temporal history, compute, geometry/tessellation stages, images, or SSBOs. Water uses a tuned fourth-power grazing response through Balanced; High and Ultra intentionally use a fifth-power Fresnel-Schlick-shaped curve. Neither is a physically based water model.

Standalone GLSL compilation supports an explicit trusted native backend, a configurable Kali/WSL backend, and a controlled Linux CI backend using distribution-maintained `glslang-tools`. It compiles generated profile/dimension/loader-model variants in OpenGL GLSL mode, records supported vertex/fragment link checks, and rejects warnings. This does not emulate Iris/Oculus patched sources or establish loader, visual, or performance compatibility. See the [Phase 7 development report](docs/PHASE7_REPORT.md), [architecture](docs/ARCHITECTURE.md), [profile guide](docs/PROFILE_GUIDE.md), [benchmark protocol](docs/BENCHMARK_PROTOCOL.md), and [visual regression protocol](docs/VISUAL_REGRESSION.md).
