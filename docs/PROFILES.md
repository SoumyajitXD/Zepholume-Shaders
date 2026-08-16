# Quality Profiles

Zepholume exposes five quality profiles so the shader can scale from weak hardware to high-end GPUs without changing its core rendering philosophy.

## Recommended default: Balanced

Use **Balanced** first. It is the intended middle ground between visual quality and rendering cost.

| Profile | Intended use | General behaviour |
| --- | --- | --- |
| **Potato** | Very weak/integrated GPUs | Minimum-cost path; aggressively reduces optional work and compiles out additional analytical sky/cloud calculations |
| **Low** | Lower-end hardware | Lightweight directional, fog, weather, cloud, and water treatment without the higher-tier animated-water path |
| **Balanced** | Most systems | Recommended atmosphere/performance balance; stronger material response plus subtle frame-time-driven water animation |
| **High** | Capable gaming GPUs | Raises bounded analytical quality for atmosphere, clouds, water, weather, and material response |
| **Ultra** | High-end hardware | Highest bounded quality available within Zepholume's direct-path architecture |

## V1.0.1 profile behaviour

V1.0.1 makes the profiles more meaningful at compile time instead of treating them as cosmetic presets.

- **Potato** removes additional analytical sky/cloud work so weak hardware does not pay for calculations it is not meant to use.
- **Low** remains a lightweight environmental tier and avoids the animated-water path used by higher profiles.
- **Balanced** and above use subtle frame-time-driven water movement rather than static pseudo-animation.
- **High** and **Ultra** increase bounded analytical treatment without enabling a separate heavyweight renderer.

The goal is simple: moving down a tier should reduce actual shader work, not merely change a few constants and call it optimization.

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

Use Potato when maintaining playability matters more than extra atmosphere. It is the first profile to try on weak integrated graphics or unusually heavy modpacks. V1.0.1 specifically cuts additional analytical sky/cloud work from this tier.

### Low

Use Low when Potato is comfortable and you want more environmental response without a large jump in shader work. It keeps water treatment lightweight and does not enable the higher-tier animated-water path.

### Balanced

Use Balanced for normal play. This is the recommended baseline for judging whether Zepholume suits your hardware. From V1.0.1 onward, Balanced enables subtle frame-time-driven water movement alongside the fuller atmospheric treatment.

### High

Use High when Balanced has comfortable GPU headroom and you want stronger bounded analytical visual treatment.

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

Zepholume does not publish profile-specific FPS percentages without controlled runtime measurements. Hardware, scene complexity, resolution, loader stack, and modpack composition can move the result dramatically.
