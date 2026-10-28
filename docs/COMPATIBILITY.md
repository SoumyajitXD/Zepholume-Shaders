# Compatibility and evidence — V1.0.6

Zepholume targets **Minecraft Java Edition** and requires a separate shader loader. **Game-version tags, static compiler coverage and a final-named ZIP are not runtime compatibility tests.**

## Final V1.0.6 qualification

The [final ZIP](../Releases/Zepholume-Shaders-1.0.6.zip) was released with source and offline validation **without full Minecraft qualification**. The packaging decision was deliberate; it does not turn unperformed tests into passes.

| Environment / evidence | Final V1.0.6 status | Scope |
| --- | --- | --- |
| Standalone GLSL, profile/dimension and mocked loader/vendor matrix | **OFFLINE PASS** | Compilation, linking and regression fixtures; no real Minecraft loader |
| Native Intel UHD 730 standalone fixtures | **GPU HARNESS PASS** | Synthetic water, hand and camera draws on one physical GPU |
| Minecraft 26.1.2 / Fabric 0.19.3 / Iris 1.10.9 / Sodium 0.8.12 | **FINAL ZIP NOT TESTED** | Historical Phase 7 gameplay activity and Phase 8 ZIP installation only |
| Minecraft 1.20.1 / Fabric / Iris 1.7.6 / Sodium 0.5.13 / Java 17 | **FINAL ZIP NOT TESTED** | Previously staged lane |
| Minecraft 1.20.1 / Forge / Oculus 1.8.0 / Embeddium 0.3.31 / Java 17 | **FINAL ZIP NOT TESTED** | Previously staged lane |
| Minecraft 26.2 Iris Fabric / NeoForge | **FINAL ZIP NOT TESTED** | Historical static target lanes |
| Minecraft 26.2 experimental Oculus Community Port | **UNQUALIFIED / EXPERIMENTAL** | Earlier partial world-program coverage prevented reliable qualification |
| Other Minecraft 1.20–26.3 combinations, GPUs and custom dimensions | **NOT TESTED** | No universal support claim |
| OptiFine | **UNSUPPORTED / NOT TESTED** | Not a maintained target |

Historical environment details and loader contracts: [V1.0.6 source compatibility audit](../Zepholume-Shaders/docs/V1.0.6_FINAL_COMPATIBILITY.md). Historical activity must not be relabeled as a final-archive runtime test.

## What passed offline

The [final verification report](../Zepholume-Shaders/docs/V1.0.6_FINAL_RELEASE.md) records **272/272 GLSL stages, 420/420 links and 630/630 mocked portability cases**. Native fixtures passed **63 hand, 52 water and 24 camera draws**, alongside source-bound profile/dimension regressions. The portability matrix does not represent 630 real computers or shader-loader runs.

**Hosted CI is separate:** GitHub Actions' latest main-branch aggregate is failing a clean-tree check. Do not describe hosted CI as passing solely because the final local source suite passed.

## Known visual and runtime limitations

- Triangle-diagonal interpolation errors were corrected in source/GPU fixtures. The original waterfall Minecraft scene has **not** been retested using the final ZIP.
- Hand lightmap configuration was corrected in all four hand wrappers. Actual hand, held-item, translucent/emissive-item behaviour is **unverified** in game.
- Analytical sky reflections and celestial water highlights lack a reliable local **directional skylight-occlusion** signal. Covered/nighttime water may look too bright; actual severity is unverified.
- Loader-patched GLSL, transparency/depth composition, option-menu visibility, shader reloads, dimension transitions and real gameplay frame times remain **unverified**.

Do not claim FPS benefits from synthetic timings or assume the shader has passed all supported-version checks.

## Loader and graphics guidance

Zepholume uses **GLSL 330 compatibility-profile** source and Iris-style interfaces and fallback routes. Existing Oculus paths remain conservative but unqualified for this final release. OptiFine is not a tested target. Earlier 26.2 notes targeted OpenGL rather than Vulkan; Vulkan behaviour remains outside the evidence boundary.

Results may vary with the specific Iris/Oculus build, graphics API, GPU driver, Java, rendering mods and resource packs. Intel standalone GPU fixtures do not establish NVIDIA/AMD parity.

For a modpack issue, first reproduce it in an isolated minimal instance. Then reintroduce rendering/resource-pack mods in small groups.

## Reporting issues

Include Minecraft version, Java, Fabric/Forge/NeoForge version, Iris/Oculus and Sodium/Embeddium versions, GPU/driver, chosen profile, full `latest.log`, steps to reproduce and a screenshot or video for visual problems.

See [Installation](INSTALLATION.md), [Troubleshooting](TROUBLESHOOTING.md) and [final release notes](../Zepholume-Shaders/docs/V1.0.6_RELEASE_NOTES.md).
