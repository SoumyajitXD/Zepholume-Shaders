# Compatibility

Zepholume Shaders targets **Minecraft Java Edition** and requires a compatible shader loader.

## V1.0.2 target stack

V1.0.2 targets **Minecraft 1.20.1**. The prepared validation environments currently use:

| Loader path | Prepared environment | Current evidence |
| --- | --- | --- |
| **Iris** | Minecraft 1.20.1, Iris 1.7.6, Sodium 0.5.13, Java 17 | Isolated directory/package checks and static GLSL validation; no completed real launch/render test for the final V1.0.2 package |
| **Oculus** | Minecraft 1.20.1, Forge 47.4.22, Oculus 1.8.0, Embeddium 0.3.31, Java 17 | Isolated directory/package checks and static GLSL validation; no completed real launch/render test for the final V1.0.2 package |
| **OptiFine** | — | Not supported or tested |

Zepholume does not include a shader loader. Install Iris or Oculus separately.

## What is actually verified

The V1.0.2 source pipeline currently validates the declared profile/dimension matrix and standalone-compiles **210 unique expanded GLSL stages**. Structural checks also guard the direct one-colour-target architecture and reject accidental composite/deferred/shadow families.

That is useful evidence for source correctness, preprocessing, interfaces, and compile-time profile isolation. It does **not** prove:

- Iris/Oculus-patched shader compilation
- real GPU driver behaviour
- visual correctness
- profile switching in-game
- shader reload/dimension-transition behaviour
- FPS or frame-time results
- NVIDIA/AMD/Intel runtime parity

Static validation is not a graphics card with excellent self-confidence.

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

When diagnosing a problem, first reproduce it with the smallest practical setup:

- Minecraft 1.20.1
- Fabric + Iris + Sodium, or Forge + Oculus + Embeddium
- Zepholume Shaders V1.0.2

Then reintroduce rendering/resource-pack mods until the conflict appears.

## Version policy

For **V1.0.2**, Minecraft **1.20.1** is the evidence-backed target.

Do not infer that every Minecraft 1.20.x/1.21.x/26.x release is validated because a project page or loader may expose broader version metadata. Older or newer versions may work, but they are not guaranteed by this release unless separately tested and documented.

## Reporting a compatibility problem

Include:

- Minecraft version
- Iris or Oculus version
- Fabric/Forge version
- Sodium/Embeddium version when applicable
- GPU model
- GPU driver version
- Java version
- Zepholume version/profile
- complete `latest.log`
- whether the issue reproduces in a minimal instance
- screenshot or short capture when the problem is visual

See [Troubleshooting](TROUBLESHOOTING.md) for a practical isolation process.
