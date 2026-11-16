# Next checks

The next useful work is targeted validation, not another speculative rendering feature.

1. **Test the exact release ZIP.** On a clean Iris instance, cover all five profiles, all three dimensions, reloads, water, darkness and first-person items. Keep the log and matched screenshots.
2. **Check the Oculus path separately.** Record Minecraft, Forge, Oculus, Embeddium and GPU versions. Do not infer compatibility from the Iris results.
3. **Revisit water under cover.** Compare exposed and enclosed water at the same time, weather, camera angle and profile. Local skylight gating is not terrain-aware reflection occlusion.
4. **Measure before optimising.** Record repeatable frame-time results against a shader-off control and determine the noise floor before changing shader hot paths.
5. **Keep the profile contract intact.** Changes to Low or Potato should be checked for new visual work or shader stages they were intended to avoid.

Fog endpoint hoisting and common-subexpression rewrites were previously proposed but remain deferred. Reopen them only if compiler output shows duplicate work and a controlled benchmark supports a change.

For the current evidence boundary, see [V1.0.7 final release](V1.0.7_FINAL_RELEASE.md) and [Compatibility](../../docs/COMPATIBILITY.md).
