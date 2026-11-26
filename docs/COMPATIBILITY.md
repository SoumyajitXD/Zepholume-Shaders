# Compatibility and evidence — V1.0.8

The development target is Minecraft Java 1.20–26.3 with Iris as the primary loader and an Oculus compatibility path. The finalized source and [local export record](../Zepholume-Shaders/docs/V1.0.8_RELEASE.md) do not establish support for every version in that range.

| Evidence | V1.0.8 status |
| --- | --- |
| Local export | Finalized November 25, 2026; SHA-256 recorded in the release record |
| Iris 1.7.6 / Minecraft 1.20.1 | Standalone patcher fixture exercised |
| Oculus 1.8.0 / Minecraft 1.20.1 | Standalone patcher fixture exercised |
| Iris 1.10.7 / Minecraft 1.21.11 | Standalone patcher fixture exercised |
| Iris 1.10.9 / Fabric 26.1.2 fixture | Standalone patcher fixture exercised; JAR labelled 26.1.1 |
| Exact final ZIP in Minecraft | Not gameplay- or visually qualified |
| Cross-vendor GPUs, additional versions and loaders | Not established |
| Gameplay FPS and frame times | Not measured for this release |
| OptiFine | Unsupported |

The patcher probe uses pre-expanded shaders and fixture geometry in a standalone JVM. It cannot demonstrate the full Minecraft loader path, profile menu, dimension transitions, graphics-driver behavior or rendered scenes. Synthetic GPU results likewise do not establish gameplay performance.

Retest covered nighttime water, flowing water, held items, clouds and fog on the exact ZIP. Local skylight is an exposure proxy, not directional raytraced occlusion. See [known issues](../Zepholume-Shaders/docs/KNOWN_ISSUES.md), [installation](INSTALLATION.md), and [CI qualification](CI_AND_RELEASE_QUALIFICATION.md).

---

## Historical V1.0.7 evidence

**Archived release:** [Zepholume-Shaders-1.0.7.zip](../Releases/Zepholume-Shaders-1.0.7.zip) is present in the GitHub Releases directory. A final-named ZIP and offline compiler passes do not prove all Minecraft versions, GPUs or shader loaders are supported.

## V1.0.7 qualification summary

| Environment / evidence | V1.0.7 status | Limit |
| --- | --- | --- |
| Final ZIP / deterministic archive | **EXPORTED; INTEGRITY CHECKS REPORTED PASS** | 67,750 bytes, 137 entries; SHA-256 `79CF6F63E7BA609D734FE653A34321BB79DC5EBAFCC80C1FD5A190471EC5BEB8` recorded by release engineer |
| Standalone GLSL 330 | **OFFLINE PASS (reported)** | 320 stages / 420 links; 5,040 logical configurations; not loader-patched compilation |
| Minecraft 26.1.2 / Fabric 0.19.3 / Iris 1.10.9 / Sodium 0.8.12 / Intel UHD 730 | **LOCAL RELEASE-CANDIDATE RUNTIME EVIDENCE** | Ultra pipeline and sunset/night horizon comparison; inspected log reported no GLSL/OpenGL errors |
| Final distributable ZIP in Minecraft | **INSTALLED; FULL EXACT-ZIP MATRIX NOT VERIFIED** | Copying the exported ZIP to shaderpacks does not independently prove all profile/scene/dimension outcomes |
| NVIDIA / AMD, Forge / Oculus, other game versions | **UNQUALIFIED FOR V1.0.7** | Historical lanes, mocked GPU labels and cross-compilation are not real runtime acceptance |
| OptiFine | **UNSUPPORTED** | Not a target loader |

V1.0.7 gates celestial water glints by **local skylight exposure**, reducing enclosed-cave leaks; its analytical model is not full raytraced directional terrain occlusion. Other known limitations include specialized short-range fog and extreme cloud-viewing geometries. **No official V1.0.7 FPS improvement is established.**

See [V1.0.7 release notes](../Zepholume-Shaders/docs/V1.0.7_RELEASE_NOTES.md), [final release report](../Zepholume-Shaders/docs/V1.0.7_FINAL_RELEASE.md), [Installation](INSTALLATION.md) and [Troubleshooting](TROUBLESHOOTING.md).

---

## Historical V1.0.6 qualification (archived for reference)

The remainder of this document describes the **historical V1.0.6 release**, not V1.0.8. Statements that the V1.0.6 final ZIP was not runtime-tested must not be applied to the V1.0.7 release-candidate evidence.

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

**Historical hosted CI:** V1.0.6 had a failing clean-tree check. See [CI qualification](CI_AND_RELEASE_QUALIFICATION.md) for dated evidence rather than treating historical failures as the current status.

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
