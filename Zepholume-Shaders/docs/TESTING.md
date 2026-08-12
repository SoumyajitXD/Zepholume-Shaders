# Manual testing

1. Back up target instance shader configuration; copy the ZIP into `shaderpacks` without overwriting other packs.
2. Test Iris/Sodium, then Oculus with its version-compatible renderer independently. Select Ultra Lite and Balanced and reload after each.
3. Test terrain/cutouts/translucency, water/lava, entities, block entities, item entities, particles, hand, translucent held items, glint, damage, border, selection outline, clouds, sun/moon/stars, rain/snow, underwater, blindness/darkness, and night vision.
4. Change Overworld, Nether, End; test caves and unknown modded blocks/entities.
5. For sky/cloud retest, capture identical noon, sunset, midnight, rain, below-cloud, and above-cloud views with clouds Fast, Fancy, and Off where available. Confirm sun/moon edges, stars, horizon continuity, and no cloud alpha halo.
5. Change resolution, fullscreen, resource packs, and profiles; inspect full `latest.log` for compiler, OpenGL, fallback, or reload warnings.
6. Restore changed configuration unless the instance is dedicated to development.

Current status: no instance was changed or launched during the 2026-07-30 verification attempt. See `RUNTIME_RESULTS.md` before treating this checklist as completed.

For performance comparison, hold world, camera, time, weather, resolution, render/simulation distance, packs, mods, VSync/FPS cap, JVM, and warm-up constant. Record average FPS, 1% low, frame-time consistency, GPU utilisation, VRAM, reload time, and defects. F3 FPS is only a rough signal.
