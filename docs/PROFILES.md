# Quality Profiles

Zepholume exposes five quality profiles so the shader can scale across different hardware without changing its core direct-path rendering philosophy.

## Recommended default: Balanced

Use **Balanced** first. It is the intended general-gameplay baseline, not a disguised High preset.

The selected profile caps which capability tiers are allowed to compile. Lower overrides can reduce work, but they cannot silently enable features above the chosen baseline.

| Profile | Intended use | V1.0.3 baseline |
| --- | --- | --- |
| **Potato** | Weak/integrated GPUs and compatibility triage | Direct scene grade and loader sky/fog only; analytical face/material/cloud/water/weather/underwater-colour work compiled out |
| **Low** | Lower-end hardware | Directional face/cloud response, bounded analytical water/weather, and subtle underwater fog tint |
| **Balanced** | General gameplay | Default; adds stronger material response, atmospheric depth, two-wave water movement, and skylight occlusion for downward-facing/overhung facets |
| **High** | Systems with more headroom | Adds refined face/cloud/water/weather detail, dual-hemisphere ambient fill, fifth-power water response, and top-facet cloud solar rim |
| **Ultra** | Maximum current Zepholume quality | Maximum bounded analytical detail within the same renderer; still no shadows, temporal effects, or framebuffer expansion |

`Ultra Lite` remains a **deprecated compatibility alias for Low** so older selections remain meaningful.

## V1.0.3 profile behaviour

V1.0.3 keeps the existing profile boundaries and adds refinement where the higher tiers have budget for it:

- **Potato** preserves loader sky/fog behaviour and continues to compile out optional analytical systems.
- **Low** keeps the lightweight face/cloud/water/weather baseline and restrained underwater fog tint.
- **Balanced** remains the everyday default and now includes skylight occlusion for downward-facing facets and partial overhangs.
- **High** and **Ultra** add dual-hemisphere ambient irradiance, a refined fifth-power Fresnel-Schlick-shaped water response, and top-facet solar rim highlighting on clouds.
- Lower water tiers retain the V1.0.2 fourth-power artistic response rather than inheriting the High/Ultra water model by accident.
- Dimension and profile gates remain authoritative so work intended to be absent is less likely to survive preprocessing by mistake.

The goal is simple: moving down a tier should remove or reduce actual shader work, not merely change a few constants and call it optimisation.

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

Use High when Balanced has comfortable GPU headroom and you want the stronger V1.0.3 ambient, water, and cloud refinements.

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

Zepholume does not publish profile-specific FPS percentages without controlled runtime measurements. V1.0.3 has not yet completed a controlled real-loader A/B benchmark pass, so no profile performance delta should be invented from static source metrics or mathematical regression tests.
