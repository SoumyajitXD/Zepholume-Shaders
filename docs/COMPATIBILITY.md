# Compatibility

Zepholume Shaders targets **Minecraft Java Edition** and requires a compatible shader loader.

## V1.0.3 compatibility boundary

V1.0.3 has several test lanes, but they do **not** all have equal evidence.

| Loader path | Prepared/target environment | Current evidence |
| --- | --- | --- |
| **Iris / Fabric** | Minecraft 1.20.1, Iris 1.7.6, Sodium 0.5.13, Java 17 | **STAGED ONLY** — static validation passes and the local environment/package is staged; no completed real launch/render qualification |
| **Oculus / Forge** | Minecraft 1.20.1, Forge 47.4.22, Oculus 1.8.0, Embeddium 0.3.31, Java 17 | **STAGED ONLY** — static validation passes and the local environment/package is staged; no completed real launch/render qualification |
| **Iris / Fabric** | Minecraft 26.2, Iris 1.11.2+26.2-fabric | **STATIC ONLY** — intended target lane; runtime not yet qualified |
| **Iris / NeoForge** | Minecraft 26.2, Iris 1.11.2+26.2-neoforge | **STATIC ONLY** — intended target lane; runtime not yet qualified |
| **Oculus Community Port / Forge** | Minecraft 26.2, Forge 65.1.0, Oculus Community Port 0.3.0-beta.1 | **EXPERIMENTAL / PARTIAL** — static validation passes, but shader activation/world rendering are currently blocked by the port's declared partial program subset |
| **OptiFine** | — | Not supported or tested |

Zepholume does not include a shader loader. Install the appropriate loader separately.

## What is actually verified

The V1.0.3 source pipeline validates declared profile/dimension behaviour, standalone GLSL compilation, direct-path architectural constraints, and deterministic mathematical regressions for release-sensitive shader arithmetic.

That is useful evidence for source correctness, preprocessing, interfaces, profile isolation, and numerical behaviour. It does **not** prove:

- Iris/Oculus-patched shader compilation
- shader activation in a real game session
- real GPU driver behaviour
- visual correctness
- profile switching in-game
- shader reload/dimension-transition behaviour
- FPS or frame-time results
- NVIDIA/AMD/Intel runtime parity

Static validation is not a graphics card with excellent self-confidence.

## Minecraft 26.2 notes

Minecraft 26.2 introduces a more complicated rendering compatibility picture than 1.20.1.

- The current Iris 26.2 lanes are **static targets only** until Zepholume is actually launched, activated, rendered, and visually checked in disposable Fabric/NeoForge instances.
- Zepholume qualification on Minecraft 26.2 should use OpenGL while the Vulkan path remains outside the current evidence boundary.
- The Oculus Community Port 0.3.0-beta.1 lane is experimental. Its declared partial support does not cover the ordinary `gbuffers_*` world-program set Zepholume relies on, so shader activation/world rendering are currently blocked rather than merely untested.

Do not flatten those states into a generic “supports 26.2” badge. Evidence has levels for a reason.

## Graphics hardware

Zepholume is designed around broadly portable GLSL rather than vendor-specific features. The project avoids requiring compute shaders, geometry/tessellation stages, SSBO/image pipelines, ray tracing, or vendor-specific extensions.

Current hardware evidence remains limited. Do not interpret the architecture as a claim that every NVIDIA, AMD, or Intel GPU/driver combination has been tested.

Runtime behaviour can vary with:

- GPU model and driver version
- operating system and Java runtime
- Iris/Oculus release
- Sodium/Embeddium version
- Minecraft graphics settings
- resource packs
- rendering-related mods
- modpack composition

## Modpack compatibility

Zepholume can be used in modded Minecraft, but large rendering stacks can create interactions that do not exist in a clean instance.

When diagnosing a problem, first reproduce it with the smallest practical setup using one of the documented target lanes. For the strongest current baseline, use:

- Minecraft 1.20.1
- Fabric + Iris + Sodium, or Forge + Oculus + Embeddium
- Zepholume Shaders V1.0.3

Then reintroduce rendering/resource-pack mods until the conflict appears.

## Version policy

For **V1.0.3**, Minecraft **1.20.1** is the strongest staged evidence baseline.

Minecraft **26.2** has explicit static/experimental target lanes, but those are not equivalent to completed runtime support. Do not infer that every Minecraft version between 1.20.1 and 26.2 is validated merely because the endpoints appear in project metadata.

Older or intermediate versions may work, but they are not guaranteed by this release unless separately tested and documented.

## Reporting a compatibility problem

Include:

- Minecraft version
- Iris or Oculus version
- Fabric/Forge/NeoForge version
- Sodium/Embeddium version when applicable
- GPU model
- GPU driver version
- Java version
- Zepholume version/profile
- complete `latest.log`
- whether the issue reproduces in a minimal instance
- screenshot or short capture when the problem is visual

See [Troubleshooting](TROUBLESHOOTING.md) for a practical isolation process.
