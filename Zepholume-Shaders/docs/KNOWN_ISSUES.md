# Known issues and test gaps

This page tracks **V1.0.7**. Older development notes that said the pack had never been loaded in Minecraft no longer describe the current release.

## What has not been fully checked

- The V1.0.7 release candidate was tested locally with Fabric 26.1.2, Iris 1.10.9 and Intel UHD Graphics 730. The exported final ZIP has **not** been put through a complete scene, dimension and profile test matrix.
- Oculus/Forge, other game versions and other GPU vendors still need direct testing. Standalone GLSL checks do not establish loader compatibility.
- There is no controlled real-game FPS or frame-time benchmark for V1.0.7. Performance improvements should not be assumed.

## Visual cases worth retesting

- **Covered water at night:** local skylight gating reduces celestial highlights, but it is not full directional occlusion.
- **Flowing water and waterfalls:** the source includes flat water-material classification; compare real fluid meshes at several viewing angles before calling every diagonal artifact fixed.
- **Hands and held items:** lightmap routing was corrected, but dark interiors, emissive items and translucent items need matched in-game checks.
- **Clouds and fog:** check profile changes, weather transitions, low-angle views and dimension transitions on the exact release ZIP.

Include the shader profile, loader versions, GPU/driver, full `latest.log` and a reproducible screenshot or scene when reporting one of these cases. See [Troubleshooting](../../docs/TROUBLESHOOTING.md) and [Compatibility](../../docs/COMPATIBILITY.md).

## Older development notes

During the V1.0.1 development line, both `gbuffers_skybasic` wrappers had a malformed `#define #define ZEPH_NO_FOG` directive. It was fixed before later releases. Earlier launcher-access and profile-testing blockers were specific to that stage and should not be reported as current V1.0.7 failures.
