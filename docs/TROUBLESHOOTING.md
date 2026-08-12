# Troubleshooting

This guide covers the fastest way to isolate common Zepholume problems without turning debugging into random checkbox roulette.

## Shader pack does not appear

Check that:

- the Zepholume release is inside the correct instance's `shaderpacks` folder
- the release archive has not been placed inside another ZIP
- you are launching the same Minecraft instance whose folder you edited
- Iris or Oculus is actually installed and loading

## Shader fails to load or compile

1. Confirm the Minecraft version.
2. Confirm the exact Iris or Oculus version.
3. Confirm required loader dependencies are present.
4. Try the same Zepholume release in a minimal clean instance.
5. Read the complete `latest.log` and search for shader compilation/preprocessor errors.
6. If Iris/Oculus exposes patched shader output, preserve it for diagnosis.

Do not diagnose a compile failure from one cropped error line if the full log contains the actual root cause twenty lines earlier.

## Black screen, broken colours, missing sky, or visual corruption

Record:

- Minecraft version
- Zepholume version
- selected profile
- GPU model and driver
- Iris/Oculus version
- Sodium/Embeddium version where applicable
- resource packs
- rendering-related mods
- screenshot of the problem
- complete `latest.log`

Then reproduce in a minimal instance. If the problem disappears there, reintroduce rendering/resource-pack mods in small groups until the conflict returns.

## Low FPS

Start with **Balanced** and compare against **Low** and **Potato** in the same scene.

Also inspect:

- render distance
- simulation distance
- resolution/render scale
- VSync and FPS cap
- high-resolution resource packs
- entity-heavy scenes
- unusually expensive modded rendering
- GPU utilisation and thermal/power limits

A profile comparison is only meaningful when the scene and settings stay fixed.

## Stutter or bad frame pacing

High average FPS does not rule out a performance problem. Watch for:

- chunk generation/loading
- Java garbage collection
- large resource reloads
- background shader compilation
- modded entity/block-entity spikes
- VRAM pressure
- driver shader-cache behaviour
- overlays or capture software

If lowering Zepholume from Ultra to Potato does not materially change the stutter, the shader is probably not the primary bottleneck.

## Problems after updating GPU drivers

If an issue started immediately after a driver update:

1. verify the problem in a minimal instance
2. perform a clean shader reload
3. compare with the previous known-good driver if practical
4. include both driver versions in the report

## Problems in a modpack only

Create a minimal control instance with the same Minecraft version and loader family. If Zepholume works there, the remaining task is compatibility isolation, not shader-pack installation.

Binary-search large mod lists where practical: remove roughly half the suspect rendering/resource mods, retest, then narrow the failing group.

## Useful bug report template

```text
Zepholume version:
Minecraft version:
Loader: Iris / Oculus
Loader version:
Fabric/Forge version:
Sodium/Embeddium version:
GPU:
GPU driver:
Java version:
Profile:
Resource packs:
Rendering-related mods:
Issue:
Steps to reproduce:
Minimal instance reproduction: yes/no
latest.log attached: yes/no
Screenshot/video attached: yes/no
```

## Support boundary

Minecraft versions older than 1.20 may or may not work and are not guaranteed. OptiFine is not a supported Zepholume target; use Iris or Oculus.