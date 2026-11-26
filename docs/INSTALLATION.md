# Installing Zepholume Shaders

Zepholume is a **Minecraft Java Edition** shader pack. It does not include Minecraft, Iris, Oculus, a mod loader or Java.

## Download or build the archive

- [CurseForge Files](https://www.curseforge.com/minecraft/shaders/zepholume-shaders/files) — choose a published file for your setup.
- [GitHub ZIP archives](../Releases/) — V1.0.7 is the latest archived ZIP as of November 26, 2026.
- [V1.0.8 source and build instructions](../Zepholume-Shaders/docs/V1.0.8_RELEASE.md) — the source is finalized, but its locally exported ZIP has not been added to the archive directory.

The V1.0.8 release record gives the local ZIP SHA-256 as `A4C733D2ACB89A7BCBD158A40BF19B114D02B8A357AA9EFA7E97AC1262E0D804`.

To build from a clean V1.0.8 source checkout, use PowerShell 7 from the nested `Zepholume-Shaders/` directory:

```powershell
./scripts/package.ps1 -OutputDirectory ./dist
Get-FileHash -Algorithm SHA256 -LiteralPath ./dist/Zepholume-Shaders-1.0.8.zip
```

The packager refuses to overwrite existing output. Use an empty output directory. Compression may vary between environments; see the release record for per-entry comparison instructions. For a downloaded ZIP, use `Get-FileHash -Algorithm SHA256 -LiteralPath ./Zepholume-Shaders-1.0.8.zip` (Windows), `sha256sum` (Linux) or `shasum -a 256` (macOS). Compare against the record for the exact version, not another release.

The previous V1.0.7 archive's recorded SHA-256 is `79CF6F63E7BA609D734FE653A34321BB79DC5EBAFCC80C1FD5A190471EC5BEB8`. See [Compatibility](COMPATIBILITY.md) before choosing a version.

## Install with Iris

1. Create a suitable Minecraft Java instance with **Iris** and the dependencies required by the chosen version (generally Sodium).
2. Launch the instance once to establish its game directory.
3. Obtain the desired shaderpack ZIP using one of the options above.
4. Copy the **intact ZIP** into the instance's `shaderpacks` directory. **Do not extract it.**
5. Launch Minecraft, open the shader-pack menu, and select Zepholume.
6. Start with **Balanced**. Move to Low/Potato if needed for performance.
7. If anything looks wrong, preserve `latest.log` and retest in a minimal instance.

V1.0.8 has standalone Iris patcher evidence, but no exact-ZIP gameplay qualification. V1.0.7's historical Minecraft 26.1.2 / Fabric / Iris 1.10.9 / Intel UHD 730 candidate testing does not transfer to V1.0.8.

## Install with Oculus (unqualified compatibility path)

Create a Forge instance with compatible **Oculus**, **Embeddium** and dependencies, then copy the ZIP into its `shaderpacks` directory and select Zepholume. A staged 1.20.1 stack used Forge 47.4.22, Oculus 1.8.0, Embeddium 0.3.31 and Java 17, but V1.0.8 exercised the Oculus 1.8.0 standalone patcher, but **has not completed Oculus gameplay qualification**.

Experimental modern Oculus ports have additional limitations. OptiFine is not supported or tested.

## Find the shaderpacks directory

The typical Windows directory is:

```text
%APPDATA%\.minecraft\shaderpacks
```

Third-party launchers and per-instance profiles can use a different game folder. Use the one belonging to **the actual instance you launch**. Create its `shaderpacks` directory if needed. The ZIP must have `shaders/` directly at its root; do not nest an extracted folder inside another folder.

## Profiles and updating

Balanced is recommended. Potato, Low, High and Ultra scale optional work. No controlled V1.0.8 gameplay FPS improvement is established.

When updating, quit Minecraft, keep the previous ZIP as a rollback option, place the new archive in the correct instance, select it, and re-check the chosen shader profile. Existing option values can persist across updates.

## Diagnosing a failure

Test in an isolated instance; record the Minecraft version, shader loader, profile, GPU/driver, full `latest.log` and screenshot. V1.0.8 retains prior waterfall and hand-lightmap fixes and refines water, fog and entity overlays. Test the exact problem scene and archive before treating any source fix as a confirmed in-game fix.

See [Troubleshooting](TROUBLESHOOTING.md), [Compatibility](COMPATIBILITY.md) and [V1.0.8 release notes](../Zepholume-Shaders/docs/V1.0.8_RELEASE.md).
