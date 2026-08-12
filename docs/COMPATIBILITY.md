# Compatibility

Zepholume Shaders targets **Minecraft Java Edition** and requires a compatible shader loader.

## Supported loader paths

| Loader path | Status |
| --- | --- |
| **Iris Shaders** | Supported target |
| **Oculus** | Supported target |
| **OptiFine** | Not a supported target |

Zepholume does not include a shader loader. Install Iris or Oculus separately for the Minecraft version you are using.

## Minecraft versions

- **Minecraft 1.20+**: tested support range
- **Minecraft versions older than 1.20**: may or may not work; not tested or guaranteed

A version being in the tested range does not mean every possible combination of loader build, modpack, graphics driver, and GPU has been validated. Shader compatibility is a stack, not a checkbox.

## Graphics hardware

Zepholume is designed around broadly portable GLSL rather than vendor-specific features. The project avoids requiring heavyweight modern GPU features such as compute shaders, geometry/tessellation stages, SSBO-based pipelines, ray tracing, or vendor-specific extensions.

Actual runtime behaviour can still vary between:

- NVIDIA GPUs and driver versions
- AMD GPUs and driver versions
- Intel integrated/discrete GPUs and driver versions
- operating systems and Java runtimes
- Iris/Oculus releases
- Sodium/Embeddium versions and other rendering mods

## Modpack compatibility

Zepholume can be used in modded Minecraft, but large rendering stacks can create interactions that do not exist in a clean instance.

When diagnosing a problem, first reproduce it with the smallest practical setup:

- Minecraft
- Fabric + Iris, or Forge + Oculus
- required loader dependencies
- Zepholume Shaders

Then reintroduce rendering/resource-pack mods until the conflict appears.

## What “tested” means here

The public compatibility statement is intentionally simple:

> Zepholume requires Iris or Oculus. Minecraft 1.20+ versions are tested. Older versions may or may not work and are not guaranteed.

This should not be expanded into claims about every patch release, every GPU, or every mod combination without evidence.

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