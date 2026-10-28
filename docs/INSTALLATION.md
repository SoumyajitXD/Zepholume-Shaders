# Zepholume Shaders V1.0.6 — Installation

Zepholume is a **Minecraft Java Edition** shader pack. It does not include Minecraft, Iris, Oculus, a mod loader or Java.

## Download the archive

- [Zepholume-Shaders-1.0.6.zip on GitHub](../Releases/Zepholume-Shaders-1.0.6.zip)
- [CurseForge Files — check actually published versions](https://www.curseforge.com/minecraft/shaders/zepholume-shaders/files)

The GitHub archive is **55,248 bytes** with SHA-256 `F72C149F44E6EE026025215D27886CD50D73252A4FE046E184DDBBB8E552331C`. A release ZIP existing does **not** mean that its Minecraft runtime compatibility has been verified. Read [Compatibility](COMPATIBILITY.md).

## Install with Iris

1. Create a suitable Minecraft Java instance with **Iris** and the dependencies required by the chosen version (generally Sodium).
2. Launch the instance once to establish its game directory.
3. Download `Zepholume-Shaders-1.0.6.zip`.
4. Copy the **intact ZIP** into the instance's `shaderpacks` directory. **Do not extract it.**
5. Launch Minecraft, open the shader-pack menu, and select Zepholume.
6. Start with **Balanced**. Move to Low/Potato if needed for performance.
7. If anything looks wrong, preserve `latest.log` and retest in a minimal instance.

A previously observed Minecraft **26.1.2 Fabric/Iris** session and an older **1.20.1 Iris 1.7.6 / Sodium 0.5.13 / Java 17** staged environment are historical evidence, **not V1.0.6 final-ZIP runtime qualifications**.

## Install with Oculus (unqualified compatibility path)

Create a Forge instance with compatible **Oculus**, **Embeddium** and dependencies, then copy the ZIP into its `shaderpacks` directory and select Zepholume. A staged 1.20.1 stack used Forge 47.4.22, Oculus 1.8.0, Embeddium 0.3.31 and Java 17, but **the final V1.0.6 ZIP has not completed Oculus gameplay qualification**.

Experimental modern Oculus ports have additional limitations. OptiFine is not supported or tested.

## Find the shaderpacks directory

The typical Windows directory is:

```text
%APPDATA%\.minecraft\shaderpacks
```

Third-party launchers and per-instance profiles can use a different game folder. Use the one belonging to **the actual instance you launch**. Create its `shaderpacks` directory if needed. The ZIP must have `shaders/` directly at its root; do not nest an extracted folder inside another folder.

## Profiles and updating

Balanced is recommended. Potato, Low, High and Ultra scale optional work. No official V1.0.6 in-game FPS percentage is available.

When updating, quit Minecraft, keep the previous ZIP as a rollback option, place the new archive in the correct instance, select it, and re-check the chosen shader profile. Existing option values can persist across updates.

## Diagnosing a failure

Test in an isolated instance; record the Minecraft version, shader loader, profile, GPU/driver, full `latest.log` and screenshot. V1.0.6's important unresolved visual tests concern **waterfall triangles, first-person hand lighting and covered/nighttime water**.

See [Troubleshooting](TROUBLESHOOTING.md), [Compatibility](COMPATIBILITY.md) and [V1.0.6 release notes](../Zepholume-Shaders/docs/V1.0.6_RELEASE_NOTES.md).
