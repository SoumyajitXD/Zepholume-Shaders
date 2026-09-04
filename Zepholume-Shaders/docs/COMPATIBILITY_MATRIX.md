# Compatibility matrix

`STATIC ONLY` means Zepholume source/preprocessor/standalone GLSL validation only. `STAGED ONLY` adds an isolated local directory and exact file/hash checks. Neither label means loader compilation, shader activation, world rendering, visual quality, or performance has been verified.

| Minecraft | Mod loader | Shader loader | Exact loader version tested/staged | Graphics API | Static validation | Game launch | Shader activation | World rendering | Visual QA | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| 1.20.1 | Fabric | Iris | Iris 1.7.6 + Sodium 0.5.13 staged locally | OpenGL | PASS | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | STAGED ONLY |
| 1.20.1 | Forge | Oculus | Oculus 1.8.0 + Embeddium 0.3.31 staged locally | OpenGL | PASS | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | STAGED ONLY |
| 26.2 | Fabric | Iris | Iris 1.11.2+26.2-fabric target; artifact/hash not staged | Prefer OpenGL (required for qualification) | PASS | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | STATIC ONLY |
| 26.2 | NeoForge | Iris | Iris 1.11.2+26.2-neoforge target; artifact/hash not staged | Prefer OpenGL (required for qualification) | PASS | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | STATIC ONLY |
| 26.2 | Forge 65.1.0 | Oculus Community Port | 0.3.0-beta.1 target; not staged | OpenGL only | PASS | NOT TESTED | BLOCKED | BLOCKED | NOT TESTED | EXPERIMENTAL / PARTIAL LOADER COMPATIBILITY |

## Authoritative compatibility boundary

- Mojang documents 26.2's Vulkan renderer as experimental and currently makes `Default` equivalent to `Prefer OpenGL`; Zepholume's planned Iris tests therefore require `Prefer OpenGL`. Iris-on-Vulkan is **NOT TESTED** and must not be claimed. [Minecraft 26.2 release notes](https://feedback.minecraft.net/hc/en-us/articles/46690753273997-Minecraft-Java-Edition-26-2)
- Iris publishes 1.11.2 builds for both [Fabric 26.2](https://modrinth.com/mod/iris/version/oaD6KQls) and [NeoForge 26.2](https://modrinth.com/mod/iris/version/1.11.2%2B26.2-neoforge). This establishes intended modern test lanes, not Zepholume runtime compatibility.
- Oculus Community Port is an unofficial beta. Its own README limits 0.3.0-beta.1 to a partial fullscreen deferred/composite/final subset; Zepholume requires ordinary `gbuffers_*` world programs. Shader activation and world rendering are therefore **BLOCKED by the port's declared subset**, not merely untested. [Community Port README](https://github.com/Khaliiid0/Oculus-Community-Port)

The pack uses standard forward `gbuffers_*` programs and one colour output, but that architecture is only an **inference** about possible fit; it is not loader support evidence. Qualification requires a disposable instance, exact JAR/package hashes, complete logs and patched shaders, profile switching, rendered-world scene matrix, and raw frame-time capture.
