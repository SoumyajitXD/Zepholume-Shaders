# Quality Profiles

Zepholume exposes five quality profiles so the shader can scale from weak hardware to high-end GPUs without changing its core rendering philosophy.

## Recommended default: Balanced

Use **Balanced** first. It is the intended middle ground between visual quality and rendering cost.

| Profile | Intended use | General behaviour |
| --- | --- | --- |
| **Potato** | Very weak/integrated GPUs | Keeps the cheapest grade, fog, and sky path; aggressively reduces optional detail work |
| **Low** | Lower-end hardware | Adds lightweight directional, cloud, water, and weather treatment |
| **Balanced** | Most systems | Stronger material response, atmospheric depth, and water/cloud treatment while keeping cost controlled |
| **High** | Capable gaming GPUs | Raises analytical quality for face, cloud, water, and weather effects |
| **Ultra** | High-end hardware | Highest bounded quality available within Zepholume’s direct-path architecture |

## What profiles do not do

High and Ultra do not secretly replace Zepholume with an entirely different renderer. The project deliberately avoids turning higher presets into an excuse to add expensive subsystems such as:

- shadow maps
- screen-space reflections
- SSAO
- TAA or temporal-history pipelines
- volumetric lighting
- ray tracing
- compute-shader passes
- geometry/tessellation stages
- multiple heavyweight full-resolution post-processing buffers

The profiles scale quality **inside the same lightweight architectural boundary**.

## Choosing the right profile

### Potato

Use Potato when maintaining playability matters more than extra atmosphere. It is the first profile to try on weak integrated graphics or unusually heavy modpacks.

### Low

Use Low when Potato is comfortable and you want more environmental response without a large jump in shader work.

### Balanced

Use Balanced for normal play. This should be the baseline for judging whether Zepholume suits your hardware before moving higher.

### High

Use High when Balanced has comfortable GPU headroom and you want stronger analytical visual treatment.

### Ultra

Use Ultra only when the extra visual refinement is worth the additional cost on your system. “Ultra” is not a moral achievement. If Balanced looks nearly identical during actual gameplay and runs better, Balanced wins.

## Performance tuning order

If you are losing FPS or frame-time consistency:

1. Reduce the Zepholume profile by one tier.
2. Check render distance and simulation distance.
3. Check whether another rendering/resource-pack mod is adding substantial work.
4. Disable unusually expensive Minecraft video settings.
5. Update or roll back the GPU driver if the problem began after a driver change.
6. Test the same scene in a minimal Iris/Oculus instance.

When comparing profiles, use the same world, position, camera direction, weather, time, render distance, resolution, and FPS/VSync settings. Otherwise the comparison is mostly decorative statistics.