# Quality Profiles

Zepholume exposes five quality profiles so the shader can scale across different hardware without changing its core direct-path rendering philosophy.

## Recommended default: Balanced

Use **Balanced** first. It is the intended general-gameplay baseline, not a disguised High preset.

The selected profile caps which capability tiers are allowed to compile. Lower overrides can reduce work, but they cannot silently enable features above the chosen baseline.

| Profile | Intended use | V1.0.2 baseline |
| --- | --- | --- |
| **Potato** | Weak/integrated GPUs and compatibility triage | Direct scene grade and loader sky/fog only; analytical face/material/cloud/water/weather/underwater-colour work compiled out |
| **Low** | Lower-end hardware | Directional face/cloud response, bounded analytical water/weather, and subtle underwater fog tint |
| **Balanced** | General gameplay | Default; adds stronger material response, atmospheric depth, continuous time transitions, and animated low-amplitude water |
| **High** | Systems with more headroom | Raises bounded face/cloud/water/weather detail within the same architecture |
| **Ultra** | Maximum current Zepholume quality | Highest bounded analytical tiers without shadows, temporal effects, or framebuffer expansion |

`Ultra Lite` remains a **deprecated compatibility alias for Low** so older selections remain meaningful.

## V1.0.2 profile behaviour

V1.0.2 strengthens the distinction between the tiers:

- **Potato** preserves the loader fog colour underwater and compiles out analytical water and other optional direct-path systems.
- **Low** enables the lowest bounded face/cloud/water/weather tiers and a restrained underwater fog tint.
- **Balanced** adds the intended core material/atmospheric treatment and low-amplitude two-wave water movement.
- **High** and **Ultra** raise analytical quality inside the same one-colour-target renderer; they do not activate a hidden heavyweight pipeline.
- Dimension and profile gates are validated so work intended to be absent is less likely to survive preprocessing by accident.

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

Use High when Balanced has comfortable GPU headroom and you want stronger bounded analytical detail.

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

Zepholume does not publish profile-specific FPS percentages without controlled runtime measurements. The final V1.0.2 package has not yet completed a real Iris/Oculus benchmark pass, so no profile performance delta should be invented from static source metrics.
