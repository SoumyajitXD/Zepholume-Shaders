# Troubleshooting

This guide covers the fastest way to isolate common Zepholume problems without turning debugging into random checkbox roulette.

## Shader pack does not appear

Check that:

- `Zepholume-Shaders-1.0.3.zip` is inside the correct instance's `shaderpacks` folder
- the release archive has not been placed inside another ZIP
- you are launching the same Minecraft instance whose folder you edited
- the intended shader loader is actually installed and loading

## Shader fails to load or compile

1. Confirm the exact Minecraft version and compare it with the documented compatibility lane.
2. Confirm the exact Iris/Oculus version.
3. Confirm required loader dependencies are present.
4. Confirm you are testing `Zepholume-Shaders-1.0.3.zip` rather than an older archive.
5. Try the same release in a minimal clean instance.
6. Read the complete `latest.log` and search for shader compilation/preprocessor errors.
7. If the loader exposes patched shader output, preserve it for diagnosis.

Do not diagnose a compile failure from one cropped error line if the full log contains the actual root cause twenty lines earlier.

## Minecraft 26.2-specific problems

The current 26.2 lanes do not have the same evidence level as the staged 1.20.1 baseline.

- Iris on Fabric/NeoForge 26.2 is currently a **static target**, not completed runtime qualification.
- Zepholume's current 26.2 qualification boundary is OpenGL; do not assume Vulkan behaviour is covered.
- The Oculus Community Port 0.3.0-beta.1 path is experimental and currently blocked for Zepholume's ordinary `gbuffers_*` world programs by the port's declared partial program support.

If a 26.2 configuration fails before Zepholume's world programs can activate, first determine whether the loader path itself supports the program family you are trying to run. Debugging shader arithmetic cannot fix a loader that never reaches the shader.

## Black screen, broken colours, missing sky, or visual corruption

Record:

- Minecraft version
- Zepholume version
- selected profile
- GPU model and driver
- Iris/Oculus version
- Sodium/Embeddium version where applicable
- Fabric/Forge/NeoForge version
- resource packs
- rendering-related mods
- screenshot or short video of the problem
- complete `latest.log`

Then reproduce in a minimal instance. If the problem disappears there, reintroduce rendering/resource-pack mods in small groups until the conflict returns.

## Cave/interior lighting looks wrong

V1.0.3 keeps skylight-grounded celestial lighting, restores exact Hermite skylight/block-light transition behaviour, and adds extra skylight occlusion for downward-facing facets and partial overhangs on Balanced, High, and Ultra.

If a cave or enclosed room still looks strongly sunlit, moonlit, uniformly orange, or strangely flat:

1. capture the exact scene and profile
2. record time, weather, dimension, and nearby light sources
3. test the same location with resource packs/rendering mods removed
4. compare Balanced against Potato; if relevant, also compare High/Ultra to isolate the extra ambient treatment
5. attach `latest.log` and a screenshot when reporting it

High and Ultra also add bounded dual-hemisphere ambient irradiance. If the issue appears only on those tiers, mention that explicitly.

## Water or underwater rendering looks wrong

V1.0.3 keeps water on the direct path and removes a redundant working-space encode/decode round trip.

Water behaviour is profile-dependent:

- lower water tiers retain the V1.0.2 tuned fourth-power artistic grazing response
- High and Ultra use a refined fifth-power Fresnel-Schlick-shaped curve
- Low through Ultra can use restrained underwater fog tint
- Potato preserves loader fog colour and compiles out analytical water work

Check whether the issue:

- appears only on one profile
- appears only on High/Ultra
- appears only while the camera is underwater
- changes with rain/storm conditions
- changes after shader reload
- reproduces without resource packs or other rendering mods

That profile split matters. A High-only reflection issue is a much better report than “water weird”.

## Clouds look wrong

High and Ultra add top-facet solar rim highlighting in V1.0.3. If a cloud artefact appears only on those profiles, capture the time of day, weather, camera direction, and whether the issue disappears on Balanced.

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
- VRAM pressure

A profile comparison is only meaningful when the scene and settings stay fixed.

V1.0.3 does not currently have a completed controlled real-loader A/B benchmark, so do not compare your result against invented official FPS numbers—there are none.

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
Fabric/Forge/NeoForge version:
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

For **Zepholume V1.0.3**, Minecraft **1.20.1** is the strongest staged evidence baseline. Minecraft **26.2** has explicit static/experimental lanes but is not yet equivalent to completed runtime support, and intermediate Minecraft versions are not automatically validated by implication.

OptiFine is not a supported Zepholume target. Broad GPU, driver, loader, or performance claims require completed real runtime evidence rather than static validation alone.
