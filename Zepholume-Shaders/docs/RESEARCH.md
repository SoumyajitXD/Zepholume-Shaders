# Research notes

Research date: 2026-07-30. Findings were verified through primary project documentation and repositories. This is research, not runtime validation.

| Source | Learned | Zepholume decision |
|---|---|---|
| [Iris overview](https://shaders.properties/current/reference/overview/) | Iris documents conventional shader programs, buffers, attributes, and debug-mode patched shader output. | Use normal `shaders/` programs and reproducible debug guidance. |
| [Iris shader settings](https://shaders.properties/current/reference/shadersproperties/shader_settings/) | `screen`, `profile.<name>`, and `.lang` configure option UI and profiles. | Use two real profiles and only functional preprocessor options. |
| [Compatibility vs. core](https://shaders.properties/current/how-to/compatibility_vs_core/) | Iris recommends compatibility profile and patches relevant 1.17+ code. | Use `#version 330 compatibility`. |
| [Programs overview](https://shaders.properties/current/reference/programs/overview/) | Compute is optional. | Use only conventional vertex/fragment programs. |
| [Iris example shaderpack](https://github.com/IrisShaders/Iris-Example-Shaderpack) | Normal root contains `shaders/`; the example is Iris-exclusive. | Study layout only, reuse no code or flags. |
| [Iris debugging shaders](https://shaders.properties/current/reference/miscellaneous/debugging_shaders/) | `Ctrl+D` enables debug mode; restarting exposes compiler errors. Patched output and compiler line numbers need special handling. | Enable debug only on the test instance, restart, and map errors against `patched_shaders`. |
| [Iris patcher](https://shaders.properties/current/reference/miscellaneous/patcher/) | Iris patches source before it reaches the GPU. Reserved `iris_`, `irisMain`, and `moj_import` naming must be avoided. | Keep Zepholume namespaced `zeph*`; inspect patched source for loader-specific faults. |
| [Iris compatibility profile guidance](https://shaders.properties/current/how-to/compatibility_vs_core/) | Compatibility profile is recommended and patched for modern Minecraft rendering. | Retain `#version 330 compatibility`; do not infer failure from an OpenGL 3.2 game context alone. |
| [Oculus repository](https://github.com/Asek3/Oculus) | Oculus is an unofficial Iris fork for Forge and describes shader-pack backward compatibility as a goal. | Test independently with exact Forge/Embeddium versions; do not claim parity from Iris results. |
| [Embeddium repository](https://github.com/FiniteReality/embeddium) | Embeddium prioritises compatibility while deriving from Sodium-era rendering code. | Treat third-party RenderType and renderer warnings as environment evidence, not a Zepholume pass. |

The common OptiFine/Iris format is used only for root layout, `gbuffers_*` naming, properties, includes, and language files.

## Sky/cloud research update, 2026-07-31

| Source | Finding | Zepholume decision |
|---|---|---|
| [Iris gbuffers reference](https://shaders.properties/current/reference/programs/gbuffers/) | `gbuffers_skybasic` covers sky/horizon, stars and void; `gbuffers_skytextured` covers sun/moon; `gbuffers_clouds` covers vanilla clouds, each with documented fallbacks. | Keep all three explicit, rather than let them inherit terrain/textured processing. |
| [Iris render stages](https://shaders.properties/current/reference/macros/render_stages/) | Iris identifies sky, sunset, custom sky, sun, moon, stars, void, and clouds through `renderStage` macros. | Refine only supported basic-sky stages; preserve custom/celestial source data. |
| [Iris world/weather uniforms](https://shaders.properties/current/reference/uniforms/world/) | `sunAngle`, rain and thunder are bounded; sun/moon positions are view-space length 100. | Use bounded time/weather transitions; do not add atmospheric simulation. |
| [Iris rendering uniforms](https://shaders.properties/current/reference/uniforms/rendering/) | `skyColor` is upper sky, `fogColor` horizon fog, and fog endpoints are supplied by the loader. | Blend upper sky toward those authoritative colours and use the supplied fog range. |
| [Iris shader properties features](https://shaders.properties/current/reference/shadersproperties/features/) | `clouds=` overrides the player's cloud setting. | Do not set it. |

Iris warns that debug mode plus a no-error OpenGL context can prevent loading on some AMD drivers. The inspected test hardware is Intel UHD Graphics 730, so no AMD-specific setting was touched. If an AMD test host is used later, record and back up the existing `use_no_error_g_l_context` value before changing it.
