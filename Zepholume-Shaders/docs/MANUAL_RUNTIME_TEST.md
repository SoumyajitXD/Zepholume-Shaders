# Manual runtime test procedure

This kit prepares isolated game directories only. It does not launch Minecraft, validate a runtime compilation, or claim runtime compatibility.

## Before either test

Use a compatible Java 17 runtime selected by the launcher. Keep existing normal installations unchanged. The only game directories used below are inside this project.

Start at 1280 x 720 and allocate 2–4 GB of memory. Do not override an already working Java 17 setup merely to set memory.

## Create the Iris launcher installation

In Minecraft Launcher, create or edit an installation with these exact values:

| Setting | Value |
| --- | --- |
| Name | `Zepholume Iris Test` |
| Version | `Fabric1.20.1` |
| Game directory | `<project-root>/runtime/iris-1.20.1` |
| Java | The Java 17 runtime above, or the launcher's compatible Java 17 selection |
| Resolution | 1280 x 720 |
| JVM memory | 2–4 GB |

Do not delete or replace the existing `Fabric1.20.1` installation. The local version metadata identifies it as Fabric Loader 0.19.3 for Minecraft 1.20.1.

### Iris test sequence

1. From the project root run `./scripts/runtime-test.ps1 -Target Iris -Action Verify`.
2. Open Minecraft Launcher, select `Zepholume Iris Test`, and launch it.
3. Confirm the title screen reports Minecraft 1.20.1 with Fabric/Iris.
4. Open Video Settings, then Shader Packs.
5. Enable Iris shader debug mode with `F3 + V`; restart if Iris asks.
6. Select `Zepholume-Shaders-1.0.3-dev.zip`.
7. Record whether shader compilation succeeds.
8. Create a new disposable Creative test world. Do not open an existing world.
9. Test daytime terrain, cutout leaves, glass, water from above and below, player hand, held item, entity, block entity, particles, rain, night, Nether, and End.
10. Switch through Potato, Low, Balanced, High, and Ultra; verify reloads and profile switching.
11. Take Minecraft screenshots of obvious defects, close the game normally, and run `./scripts/runtime-test.ps1 -Target Iris -Action Collect`.

## Create the Oculus launcher installation

In Minecraft Launcher, create or edit a separate installation with these exact values:

| Setting | Value |
| --- | --- |
| Name | `Zepholume Oculus Test` |
| Version | `Still Watching Next` |
| Game directory | `<project-root>/runtime/oculus-1.20.1` |
| Java | The Java 17 runtime above, or the launcher's compatible Java 17 selection |
| Resolution | 1280 x 720 |
| JVM memory | 2–4 GB |

The detected local Forge loader is Forge 47.4.22 for Minecraft 1.20.1, represented by the version ID `Still Watching Next`. This instruction uses that **version ID only**; it never uses the `Still Watching Next` directory as a game directory and never changes that modpack. If Minecraft Launcher does not offer `Still Watching Next` as a selectable version, the missing independent loader installation is **Forge 1.20.1-47.4.22**. Stop there and install/select that loader only after explicitly choosing to do so; do not use the modpack directory as a workaround.

### Oculus test sequence

1. From the project root run `./scripts/runtime-test.ps1 -Target Oculus -Action Verify`.
2. Open Minecraft Launcher, select `Zepholume Oculus Test`, and launch it.
3. Confirm the title screen reports Minecraft 1.20.1 with Forge/Oculus.
4. Open Video Settings, then Shader Packs.
5. Enable Oculus shader debug mode with `F3 + V`; restart if Oculus asks.
6. Select `Zepholume-Shaders-1.0.3-dev.zip` and record whether compilation succeeds.
7. Create a new disposable Creative test world. Do not open an existing world.
8. Test daytime terrain, cutout leaves, glass, water from above and below, player hand, held item, entity, block entity, particles, rain, night, Nether, and End.
9. Switch through Potato, Low, Balanced, High, and Ultra; verify reloads and profile switching.
10. For the sky/cloud correction, test dawn, noon, sunset, midnight, rain and thunder; look up, at the horizon, toward/away from the sun, and above/below clouds. Repeat Fast/Fancy/Off cloud settings where the loader exposes them.
11. Take Minecraft screenshots of obvious defects, close normally, and run `./scripts/runtime-test.ps1 -Target Oculus -Action Collect`.

Never enable Zepholume in `Still Watching Next`.

## Evidence and reset

`Collect` copies only test-relevant logs, crash reports, patched shaders, recognised Iris/Oculus shader settings, relevant options, screenshots, JVM crash logs, and a collection manifest into `runtime/evidence/<loader>/<timestamp>/`. The evidence is local and ignored by Git: logs and screenshots may contain personal in-game or system details, so review/redact it before sharing. It excludes account databases, launcher authentication files, server lists, worlds, and unrelated data.

To clear generated runtime artifacts from one isolated directory, use exactly one target:

```powershell
./scripts/runtime-test.ps1 -Target Iris -Action Reset
./scripts/runtime-test.ps1 -Target Oculus -Action Reset
```

Reset preserves mods, shaderpacks, config, options, and saves. It never accesses source, `dist`, normal Minecraft instances, launcher profiles, or `Still Watching Next`.

## Structural-validation boundary

`scripts/validate.ps1` verifies source/package structure: includes, shader entry points, program pairs, legacy varyings, option/profile constraints, a single colour target, malformed/duplicated defines, and ZIP path shape. It does not compile GLSL with Iris/Oculus, test drivers, confirm rendering output, inspect game logs, or establish runtime compatibility. Those questions remain for the manual tests above.
# Compiler-scope note

`scripts/validate-glsl.ps1` checks Zepholume-preprocessed standalone GLSL only. It does not emulate Iris or Oculus patching, so runtime loader testing remains required even after standalone compiler success.
