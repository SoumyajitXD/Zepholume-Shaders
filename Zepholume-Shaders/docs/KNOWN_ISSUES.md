# Known issues and test gaps

This page tracks **V1.0.8**. See the [release and validation notes](V1.0.8_RELEASE.md) for the exact build and offline checks.

## What has not been fully checked

- V1.0.8 has no exact-ZIP gameplay result. Standalone GLSL and loader patcher checks cover source and fixture behavior. In-game preprocessing, shader reloads, and rendering still need direct tests.
- The V1.0.7 release candidate was tested locally with Fabric 26.1.2, Iris 1.10.9 and Intel UHD Graphics 730. See the [V1.0.7 release record](V1.0.7_FINAL_RELEASE.md) for that historical evidence.
- Controlled Minecraft FPS and frame-time measurements are unavailable for V1.0.8. The benchmark tools and synthetic GPU timing fixtures measure different things.

## Visual cases worth retesting

- **Covered water at night:** local skylight gating reduces celestial highlights, but it is not full directional occlusion.
- **Flowing water and waterfalls:** the source includes flat water-material classification; compare real fluid meshes at several viewing angles before calling every diagonal artifact fixed.
- **Hands and held items:** lightmap routing was corrected, but dark interiors, emissive items and translucent items need matched in-game checks.
- **Clouds and fog:** check profile changes, weather transitions, low-angle views and dimension transitions on the exact release ZIP.

When reporting one of these cases, include the ZIP SHA-256, shader profile, game and loader versions, GPU and driver, relevant `latest.log` output, and a reproducible screenshot or scene. Review logs for private details before sharing. See [Troubleshooting](../../docs/TROUBLESHOOTING.md) and [Compatibility](../../docs/COMPATIBILITY.md).

## Older development notes

During the V1.0.1 development line, both `gbuffers_skybasic` wrappers had a malformed `#define #define ZEPH_NO_FOG` directive. It was fixed before later releases.
