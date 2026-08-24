# Changelog

## 1.0.2 — released

- Pass 4 release-candidate hardening: corrected water terminology to a tuned fourth-power Fresnel-inspired approximation; the conventional fifth-power Fresnel-Schlick label is no longer used, and the intentionally elevated 0.035 base reflectance is documented as artistic tuning.
- Added profile-gated underwater fog tint using standard shader-pack `isEyeInWater`/`nightVision` inputs and existing fog distance. Potato preserves loader fog exactly; Low through Ultra add restrained red attenuation without a depth texture, extra pass, exponential attenuation, or extra texture sample.
- Replaced include-only “preprocessed” source metrics with `glslangValidator -E` evaluated variants, and added evaluated-source checks for Potato analytical-water/normal removal and Nether/End celestial-shading isolation.
- Added structural regressions for preserving source alpha and rejecting accidental composite/deferred/shadow program families.
- Implemented dual celestial directional lighting for sun (day) and moon (night) consuming loader `sunPosition` and `moonPosition` uniforms with storm-softened directional response.
- Prevented cave and interior directional light leakage by modulating sun/moon directional shading with skylight (`zephLightCoord.y`), ensuring underground caves and dark interiors retain natural isotropic ambient lighting.
- Implemented a relative block-light dominance warmth model using the ratio of block light (`zephLightCoord.x`) to skylight (`zephLightCoord.y`), eliminating daytime orange tinting while delivering rich, incandescent interior warmth without destroying blue/green material chroma.
- Upgraded water response to a bounded fourth-power Fresnel-inspired approximation ($F_0 \approx 0.035$, an intentional artistic baseline rather than physical Schlick Fresnel) with dual-lobe celestial specular, horizon extinction, storm softening, and compile-time Potato elimination.
- Isolated Nether (`world-1`) and End (`world1`) dimension lighting, compiling out Overworld sun/moon trigonometry and replacing it with vertical cavern ambient gradients (Nether) and void-grounded ambient fill (End).
- Deduplicated hot-path vector operations: normalized surface normal once in `fragment.glsl` across lighting, materials, and water; eliminated 3 redundant direction normalizations in `sky_fragment.glsl`; optimized daylight/twilight with fast `inversesqrt` elevation helpers.
- Enhanced cloud shading with sun/moon directional rim lighting, underside density shaping, and twilight flank warmth.
- Seamlessly aligned analytical sky and horizon fog curves, preventing horizon seam artifacts at twilight and night transitions.
- Updated release metadata, packaging defaults, and validation rules for V1.0.2.

## 1.0.1 — released

- Centralised continuous sun-elevation and twilight response so terrain, clouds, sky, and Overworld fog no longer use incompatible day/night bands.
- Refined the analytical Overworld sky with loader-provided sky/fog colour integration, restrained twilight warmth, smoother horizon separation, moon glow, and rain desaturation. Potato now compiles out analytic sky and cloud lighting work.
- Reworked fog colour integration for clearer Overworld depth and restrained independent Nether/End atmosphere while retaining loader fog ranges and source alpha.
- Replaced the misleading static “surface movement” control with `Water movement`; Balanced and above now use bounded, frame-time-driven vertex waves with no depth reconstruction, SSR, or extra buffer.
- Removed the repeated display-to-linear decode in the generic scene route and removed the normal-route dependency on an Iris-specific thunder uniform.
- Added stale-version metadata checks to structural validation. No loader runtime test, benchmark, or cross-vendor claim is implied.

## 1.0.0 — released

- Replaced two presets with Potato, Low, Balanced (default), High, and Ultra; Ultra Lite remains a documented Low compatibility alias.
- Added a single profile configuration matrix, grouped option UI, and static profile/option validation.
- Reworked the direct colour path around bounded display decoding, exposure, contrast, temperature, highlight compression, and hand-safe grading.
- Added profile-gated face/material response, atmospheric fog, analytical sky/celestial glow, directional cloud response, weather response, and Fresnel-style water treatment.
- Added repeatable benchmark and visual-regression manifests. No runtime benchmark or screenshot result is claimed in this release candidate.

## Historical development notes

- Replaced the generic terrain treatment on `gbuffers_skybasic`, `gbuffers_skytextured`, and `gbuffers_clouds` with dedicated, bounded sky/cloud paths.
- Preserved sun, moon, stars, custom sky texture, cloud alpha, and vanilla vertex colour instead of applying terrain lighting and global grading to them.
- Removed the generic second vertex-colour lighting multiplier and made terrain/cloud fog follow the loader-provided fog range.
- Preserved the player's cloud setting; no `clouds=` override is set.

- Corrected malformed `gbuffers_skybasic` preprocessor directives that would block compilation.
- Extended structural validation for recursive includes, malformed directives, stage entry points, interfaces, option/profile ranges, and output-target policy.
- Recorded runtime-test discovery; no user instance setting, shader pack, save, or world was changed.
- First loadable shader-pack foundation.
- Ultra Lite and Balanced preprocessor profiles.
- Original lighting, colour, fog, water, and dimension treatment.
- Offline validation and deterministic ZIP packaging.
