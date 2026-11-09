# Quality Profiles

Zepholume exposes five quality profiles so the shader can scale across different hardware without changing its core direct-path rendering philosophy.

## Recommended default: Balanced

Use **Balanced** first. It is the intended general-gameplay baseline, not a disguised High preset.

The selected profile caps which capability tiers are allowed to compile. Lower overrides can reduce work, but they cannot silently enable features above the chosen baseline.

| Profile | Intended use | V1.0.7 baseline |
| --- | --- | --- |
| **Potato** | Weak/integrated GPUs and compatibility triage | Direct scene grade and loader sky/fog only; analytical face/material/cloud/water/weather/underwater-colour work compiled out |
| **Low** | Lower-end hardware | Directional face/cloud response, bounded analytical water/weather, and subtle underwater fog tint |
| **Balanced** | General gameplay | Default; adds stronger material response, atmospheric depth, two-wave water movement, and skylight occlusion for downward-facing/overhung facets |
| **High** | Systems with more headroom | Adds refined face/cloud/water/weather detail, dual-hemisphere ambient fill, fifth-power water response, and top-facet cloud solar rim |
| **Ultra** | Maximum current Zepholume quality | Maximum bounded analytical detail within the same renderer; still no shadows, temporal effects, or framebuffer expansion |

`Ultra Lite` remains a **deprecated compatibility alias for Low** so older selections remain meaningful.

## V1.0.7 profile behaviour

The final V1.0.7 configuration retains **exactly five selectable profiles**: Potato, Low, Balanced (default), High and Ultra. Source-level configuration checks passed, and local Iris profile switching was smoke-tested. Full cross-profile visual qualification on all GPUs and loaders remains incomplete.

- Potato retains the direct grade/loader sky and preserves dark/black fog without the earlier additive wash.
- Low keeps a lightweight face/cloud/weather/water path without vertex water movement.
- Balanced is the default atmospheric/material baseline and includes subtle animated water.
- High and Ultra increase bounded analytical quality without requiring additional framebuffer passes.
- `Ultra Lite` remains a deprecated Low compatibility alias, not a sixth selectable profile.

V1.0.7 also refines sky-to-horizon blending, block cloud coverage, cave-water skylight gating and waterfall classification. Profile selection does not fix an incompatible loader. See [V1.0.7 final release evidence](../Zepholume-Shaders/docs/V1.0.7_FINAL_RELEASE.md).

## What profiles do not do

High and Ultra do not secretly replace Zepholume with a different renderer. The project deliberately avoids using higher presets as an excuse to add:

- shadow maps
- screen-space reflections
- SSAO
- bloom pipelines
- TAA or temporal-history systems
- volumetric lighting
- ray tracing
- compute-shader passes
- geometry/tessellation stages
- SSBO/image pipelines
- heavyweight full-resolution post-processing buffers

The profiles scale quality **inside the same direct-path architectural boundary**.

## Choosing the right profile

### Potato

Use Potato when maintaining playability or isolating compatibility matters more than extra atmosphere. It is the first tier to try on weak integrated graphics or unusually demanding modpacks.

### Low

Use Low when Potato is comfortable and you want more directional, cloud, weather, water, and underwater response without the fuller Balanced feature baseline.

### Balanced

Use Balanced for normal play. This is the default profile and the best starting point for judging whether Zepholume suits your system.

### High

Use High when Balanced has comfortable GPU headroom and you want the retained ambient, water, and cloud refinements.

### Ultra

Use Ultra only when the extra refinement is worth the additional cost on your system. “Ultra” is not a moral achievement. If Balanced looks nearly identical during actual gameplay and runs better, Balanced wins.

## Performance tuning order

If you are losing FPS or frame-time consistency:

1. Reduce the Zepholume profile by one tier.
2. Check render distance and simulation distance.
3. Check resolution/render scale and FPS/VSync settings.
4. Check whether another rendering/resource-pack mod is adding substantial work.
5. Check GPU utilisation, temperatures, power limits, and VRAM pressure.
6. Update or roll back the GPU driver if the problem began after a driver change.
7. Test the same scene in a minimal Iris/Oculus instance.

When comparing profiles, keep the world, position, camera direction, weather, time, render distance, resolution, and FPS/VSync settings fixed. Otherwise the comparison is mostly decorative statistics.

Zepholume does not publish profile-specific FPS percentages without controlled runtime measurements. V1.0.7 has not completed a controlled real-loader A/B benchmark pass, so no profile performance delta should be invented from static source metrics or mathematical regression tests.
