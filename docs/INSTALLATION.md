# Zepholume Shaders V1.0.7 — Installation

Zepholume is a **Minecraft Java Edition** shader pack. It does not include Minecraft, Iris, Oculus, a mod loader or Java.

## Download the archive

- [Zepholume-Shaders-1.0.7.zip on GitHub](../Releases/Zepholume-Shaders-1.0.7.zip)
- [CurseForge Files — check actually published versions](https://www.curseforge.com/minecraft/shaders/zepholume-shaders/files)

The V1.0.7 local release record reports **67,750 bytes** with SHA-256 `79CF6F63E7BA609D734FE653A34321BB79DC5EBAFCC80C1FD5A190471EC5BEB8`. Verify the downloaded bytes before use. A GitHub archive does **not** guarantee all-version or cross-vendor runtime compatibility. Read [Compatibility](COMPATIBILITY.md).

## Install with Iris

1. Create a suitable Minecraft Java instance with **Iris** and the dependencies required by the chosen version (generally Sodium).
2. Launch the instance once to establish its game directory.
3. Download `Zepholume-Shaders-1.0.7.zip`.
4. Copy the **intact ZIP** into the instance's `shaderpacks` directory. **Do not extract it.**
5. Launch Minecraft, open the shader-pack menu, and select Zepholume.
6. Start with **Balanced**. Move to Low/Potato if needed for performance.
7. If anything looks wrong, preserve `latest.log` and retest in a minimal instance.

V1.0.7's selected source candidate has local Minecraft **26.1.2 / Fabric / Iris 1.10.9 / Intel UHD 730** runtime evidence. Copying the final ZIP into shaderpacks was recorded, but no comprehensive multi-profile, multi-dimension, cross-vendor final-ZIP gameplay matrix was completed.

## Install with Oculus (unqualified compatibility path)

Create a Forge instance with compatible **Oculus**, **Embeddium** and dependencies, then copy the ZIP into its `shaderpacks` directory and select Zepholume. A staged 1.20.1 stack used Forge 47.4.22, Oculus 1.8.0, Embeddium 0.3.31 and Java 17, but **the final V1.0.7 ZIP has not completed Oculus gameplay qualification**.

Experimental modern Oculus ports have additional limitations. OptiFine is not supported or tested.

## Find the shaderpacks directory

The typical Windows directory is:

```text
%APPDATA%\.minecraft\shaderpacks
```

Third-party launchers and per-instance profiles can use a different game folder. Use the one belonging to **the actual instance you launch**. Create its `shaderpacks` directory if needed. The ZIP must have `shaders/` directly at its root; do not nest an extracted folder inside another folder.

## Profiles and updating

Balanced is recommended. Potato, Low, High and Ultra scale optional work. No official V1.0.7 in-game FPS improvement percentage is available.

When updating, quit Minecraft, keep the previous ZIP as a rollback option, place the new archive in the correct instance, select it, and re-check the chosen shader profile. Existing option values can persist across updates.

## Diagnosing a failure

Test in an isolated instance; record the Minecraft version, shader loader, profile, GPU/driver, full `latest.log` and screenshot. V1.0.7 includes source fixes for **waterfall interpolation, first-person irradiance and enclosed-water skylight gating**. Those fixes are not substitutes for testing the exact problem scene in the final ZIP.

See [Troubleshooting](TROUBLESHOOTING.md), [Compatibility](COMPATIBILITY.md) and [V1.0.7 release notes](../Zepholume-Shaders/docs/V1.0.7_RELEASE_NOTES.md).
