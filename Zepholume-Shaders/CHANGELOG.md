# Changelog

## 1.0.5-dev — unreleased

- Phase 9 recovery froze and compared the workspace against the preserved Phase 8 ZIP; no surviving Gemini production shader changes were found. The operator screenshots exposed severe black crush and day/night/cave imbalance. A bounded face response, positive contrast toe, and in-gamut-neutral highlight shoulder repair the source-level attenuation path without disabling the lightmap. Profile selection now contains exactly Potato, Low, Balanced, High, and Ultra; High/Ultra no longer force stronger contrast or saturation. Loader-rendered visual QA remains required.
- Added Phase 8 patched-shader evidence analysis. It inventories and hashes loader-produced patched output and associates loader diagnostic lines with their patched context; it never promotes empty output or source compilation to a loader pass.
- Added fresh Phase 8 hash-bound Iris/Oculus comparison-lane wiring and a five-profile visual QA record. Historical lanes and all archived packages remain immutable. Hosted CI naming now targets the Phase 8 candidate, but no hosted run has occurred.

- Added an explicit configurable WSL validator backend, using the official Kali `glslang-tools` package, alongside explicit trusted native and Linux-CI modes. Stage and supported OpenGL vertex/fragment link diagnostics remain separate from Iris/Oculus patched-source evidence.
- Corrected Nether/End sky variants so they retain the loader-provided sky rather than accidentally carrying Overworld analytic sun/moon code after preprocessing. Updated CI packaging and diagnostics to the Phase 7 candidate name; no hosted run has occurred.
- Added a controlled Linux GitHub Actions compiler gate using the distribution-maintained `glslang-tools` package. It regenerates and source-hash-binds all profile/dimension/loader-model variants, compiles every unique vertex and fragment stage as OpenGL GLSL, rejects warnings, and records the affected logical variants for diagnostics. This standalone gate does not reproduce Iris/Oculus patching.
- Added compiler-backed negative GLSL coverage and dedicated missing/corrupted dimension-wrapper and water-material-classification fixtures. Packaging CI now builds the separately named Phase 6 development archive twice and compares hashes.
- Kept the blocked unsigned Windows compiler out of automatic discovery. A trusted PATH compiler can be selected explicitly with `-Validator`; otherwise the Linux CI gate is the available compilation route.
- Added a separately named Phase 6 runtime-manifest/lane workflow so the archived Phase 5-era comparison lanes remain immutable. No new lane has been launched or rendered.
- Corrected the generic scene route to multiply albedo/vertex colour by the loader-provided per-surface lightmap before colour-space decoding. Earlier source carried lightmap coordinates for artistic face and warmth modifiers but never applied the underlying block/sky irradiance, causing the permanent full-bright cave/interior defect.
- Added structural and numerical source-locked regressions requiring lightmap consumption and checking zero, mixed, and full-light transfer cases. This is static evidence only; loader-rendered visual and performance qualification remains pending.
- Restored complete legacy `world0`, `world-1`, and `world1` wrapper topologies. Each wrapper is mechanically derived from the single root program set, with dimension macros isolated in the wrapper; shared implementations remain in `shaders/lib`.
- Limited animated water displacement and analytical water shading to `minecraft:water`. `gbuffers_water` also carries glass, ice, and other translucent terrain, which now follows the ordinary scene route instead of receiving water Fresnel/specular.
- Applied texture matrix 0 to generic, sky, and cloud texture coordinates; this restores loader-provided texture transforms such as armor-glint scrolling.
- Preserved loader fog colour and linear fog range for lava and powdered-snow camera media, and normalized interpolated sky directions before angular sunrise/sunset and celestial calculations.
- Hardened package validation to require the exact allow-listed source bytes and to reject development artifacts. Development packaging now stages and validates a V1.0.5-named archive before promotion.

## 1.0.4 — released

- Avoids unnecessary water celestial-specular calculations when their contribution is exactly zero, without adding a shader interface or vendor-specific path.
- Keeps the direct GLSL 330 compatibility architecture and strengthens reproducible packaging and static validation coverage.
- Defers fog endpoint hoisting: it remains an archived experimental treatment pending runtime evidence.
- No measured FPS, frame-pacing, or runtime compatibility claim is made.

## 1.0.3-dev — unreleased

- Removed the active water fragment path's redundant working-space encode/decode round trip. The water surface now feeds the existing linear scene grade directly; no texture read, pass, buffer, or visual algorithm was added.
- Restored exact Hermite `smoothstep` behaviour for block-light warmth and skylight gating while retaining named compile-time reciprocal range constants. This is a mathematical-equivalence cleanup, not a measured performance claim.
- Enhanced directional lighting and ambient depth: added skylight occlusion for downward-facing facets and partial overhangs (Balanced, High, Ultra); implemented dual-hemisphere ambient irradiance (cool sky dome fill on top, warm ground bounce on bottom) on High and Ultra.
- Refined water Fresnel on High and Ultra to a fifth-power Fresnel-Schlick-shaped curve. This is an intentional visual change; lower water tiers retain the V1.0.2 fourth-power artistic curve.
- Added top-facet solar rim highlighting on clouds for High and Ultra tiers.
- Removed unreachable fog-scattering and foliage-response branches rather than leaving undocumented dead profile code. Added deterministic mathematical regression tests and evidence-scoped compatibility, benchmark, and runtime collection documentation.

## 1.0.2-dev — unreleased

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
- Maintained project metadata and validation rules for the 1.0.2-dev development cycle.

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
