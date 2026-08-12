# Installation Guide

Zepholume Shaders is a Minecraft Java Edition shader pack and **requires either Iris Shaders or Oculus** to load.

## Requirements

- Minecraft Java Edition
- A supported shader loader:
  - **Iris Shaders** for the Fabric ecosystem, or
  - **Oculus** for the Forge ecosystem
- A GPU and driver capable of running your chosen Minecraft version and shader loader

Minecraft **1.20+** versions are the tested support range. Older versions may or may not work and are not guaranteed.

## Install with Iris

1. Install Fabric and Iris for the Minecraft version you intend to use.
2. Launch that installation once so Minecraft creates the required directories.
3. Download the Zepholume release `.zip`.
4. Copy the `.zip` into your Minecraft `shaderpacks` directory.
5. Launch Minecraft.
6. Open **Options → Video Settings → Shader Packs** (wording can vary by Iris version).
7. Select **Zepholume Shaders**.
8. Start with the **Balanced** profile.

Do not extract the release archive unless a specific release explicitly tells you to do so.

## Install with Oculus

1. Install Forge for the Minecraft version you intend to use.
2. Install Oculus and any dependency required by the Oculus version you selected.
3. Launch that installation once.
4. Download the Zepholume release `.zip`.
5. Copy the `.zip` into your Minecraft `shaderpacks` directory.
6. Launch Minecraft and open the shader-pack menu.
7. Select **Zepholume Shaders**.
8. Start with the **Balanced** profile.

## Finding the shaderpacks folder

The normal Windows location is inside your Minecraft game directory, for example:

```text
%APPDATA%\.minecraft\shaderpacks
```

Third-party launchers and separate Minecraft instances can use a different game directory. Put Zepholume in the `shaderpacks` folder belonging to the **actual instance you launch**.

## Choosing a profile

Start with **Balanced**. If performance is insufficient, move down to Low or Potato. If you have substantial GPU headroom and want stronger visual treatment, try High or Ultra.

Changing to Ultra before checking whether Balanced already looks good is the shader equivalent of buying a forklift to move a chair.

See [Quality Profiles](PROFILES.md) for details.

## Updating Zepholume

When moving to a newer release:

1. Exit Minecraft.
2. Place the new Zepholume archive in `shaderpacks`.
3. Keep the previous release temporarily if you want an easy rollback path.
4. Launch Minecraft and select the new release.
5. Re-check your profile and shader options.
6. Remove the old archive after the new build is confirmed working.

## If it does not load

See [Troubleshooting](TROUBLESHOOTING.md). The most useful diagnostic is usually the complete `latest.log` from the affected Minecraft instance.