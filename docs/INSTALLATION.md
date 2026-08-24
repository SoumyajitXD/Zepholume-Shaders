# Installation Guide

Zepholume Shaders is a Minecraft Java Edition shader pack and **requires Iris Shaders or Oculus** to load.

## V1.0.2 requirements

V1.0.2 targets **Minecraft Java 1.20.1**.

Prepared validation environments currently use:

- **Iris 1.7.6 + Sodium 0.5.13** on Minecraft 1.20.1
- **Oculus 1.8.0 + Embeddium 0.3.31 + Forge 47.4.22** on Minecraft 1.20.1
- **Java 17**

The final V1.0.2 package has not yet completed a real Iris/Oculus launch-and-render validation pass. Treat other Minecraft/loader combinations as unverified unless separately documented.

## Install with Iris

1. Create or use a **Minecraft 1.20.1** Fabric instance.
2. Install Iris and its required Sodium stack.
3. Launch the instance once so Minecraft creates the required directories.
4. Download `Zepholume-Shaders-1.0.2.zip`.
5. Copy the ZIP into that instance's `shaderpacks` directory.
6. Launch Minecraft.
7. Open the shader-pack menu (wording can vary by Iris version).
8. Select **Zepholume Shaders**.
9. Start with the **Balanced** profile.

## Install with Oculus

1. Create or use a **Minecraft 1.20.1** Forge instance.
2. Install Oculus, Embeddium, and any dependencies required by the selected builds.
3. Launch the instance once.
4. Download `Zepholume-Shaders-1.0.2.zip`.
5. Copy the ZIP into that instance's `shaderpacks` directory.
6. Launch Minecraft and open the shader-pack menu.
7. Select **Zepholume Shaders**.
8. Start with the **Balanced** profile.

## Do not extract the release ZIP

Place `Zepholume-Shaders-1.0.2.zip` directly in `shaderpacks` unless a future release explicitly says otherwise.

## Finding the shaderpacks folder

The normal Windows location is inside the Minecraft game directory, for example:

```text
%APPDATA%\.minecraft\shaderpacks
```

Third-party launchers and separate instances can use a different game directory. Put Zepholume in the `shaderpacks` folder belonging to the **actual instance you launch**.

## Choosing a profile

Start with **Balanced**. It is Zepholume's default general-gameplay tier.

- move down to **Low** or **Potato** when you need to reduce shader work
- move up to **High** or **Ultra** only when you have comfortable GPU headroom

Changing to Ultra before checking whether Balanced already looks good is still the shader equivalent of buying a forklift to move a chair.

See [Quality Profiles](PROFILES.md) for details.

## Updating Zepholume

When moving to a newer release:

1. Exit Minecraft.
2. Place the new Zepholume archive in `shaderpacks`.
3. Keep the previous release temporarily if you want an easy rollback path.
4. Launch Minecraft and select the new release.
5. Re-check your profile and shader options.
6. Remove the old archive after the new build is confirmed working on your setup.

## Safer compatibility testing

For loader, driver, or mod compatibility testing, prefer an **isolated or disposable Minecraft instance**. Do not use an irreplaceable modpack save as a test harness when a clean instance can answer the question more clearly.

## If it does not load

See [Troubleshooting](TROUBLESHOOTING.md). The most useful diagnostic is usually the complete `latest.log` from the affected Minecraft instance.
