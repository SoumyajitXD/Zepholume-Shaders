# Changelog

## 1.0.6 — released 2026-10-28

- Restored hand-program lightmap multiplication in all dimension wrappers; retained existing hand grading and alpha, including the documented translucent-hand fallback.
- Corrected raw view-space interpolation and fragment-local distance calculation, eliminating reproduced triangle-diagonal differences in standalone water and fog fixtures without altering wave geometry.
- Corrected camera-space world-elevation calculations and preserved valid short loader fog ranges, with defined handling for equal or reversed endpoints.
- Preserved Potato, Low, Balanced, High and Ultra, with Balanced as the recommended default and the existing direct one-colour-target architecture.
- Expanded source-bound compilation, portability, profile, lighting and water regression coverage, plus deterministic archive verification.
- Released with explicit testing limitations: Minecraft visual outcomes, loader/version combinations, transparency behavior and in-game FPS are not qualified. Analytical water reflections still lack local skylight occlusion.

## 1.0.6-dev-phase8 — unreleased

- Restored per-surface lightmap irradiance to the hand program in all three dimension wrappers, including the translucent-hand fallback. Retained the existing hand grade and alpha.
- Interpolate the raw view-space position before normalizing water view rays and calculating fragment distance. This removes reproduced triangle-diagonal differences in analytical water and generic distance fog without changing wave geometry or visual tuning parameters.
- Added focused hand routing and native irradiance regressions. Minecraft hand/item visuals, loader compatibility and performance still require qualification.

## 1.0.6-dev-phase7 — unreleased

- Corrected world-elevation calculations to compare view-space celestial positions and surface normals with camera-transformed world up. Camera pitch should no longer change day/night weights, sky elevation, cloud facets, horizon fog, or dimensional vertical fill.
- Added camera-rotation numerical and native Intel regression checks; these are standalone evidence. Minecraft visuals, profile UI, loader compatibility, and frame-time performance still require runtime qualification.
- Fixed Windows crash-report evidence redaction and strict linker-warning enforcement, with targeted negative fixtures. Frozen control archives remain unchanged.

## 1.0.6-dev-phase6 — unreleased

- Hardened five-profile parsing and settings localization checks, and expanded source-derived Intel GPU fog and framebuffer regressions. These checks are offline evidence, not Minecraft qualification.
- Made development packaging refuse existing archive names and emit an entry-hash manifest. Added a post-launch evidence collector with a dry-run mode and fresh-session checks.
- Production GLSL is unchanged. The seven historical short-range fog differences match the corrected loader-range equation; no measured Minecraft performance or release-readiness claim is made.

## 1.0.6-dev-phase3 — unreleased

- Preserved every positive loader fog range in immersed, open-air, and cloud paths. Equal or reversed ranges now use a defined step at `fogStart`; numerical tests cover zero, short, tiny, negative-start, and invalid ranges.
- Reused computed water sun/moon specular weights, and moved disabled Potato cloud colour calculations inside the compile-time feature gate. These are source-level reductions, not measured FPS gains.
- Corrected the cloud-fog menu label, added source-locked math regressions and a native Windows OpenGL compiler harness. Standalone Intel driver compilation is separate from Iris/Oculus runtime qualification.

## 1.0.6-dev-phase2 — unreleased

- Preserved exact loader fog start/end values for valid sub-block immersed-media ranges while guarding a zero denominator. Added numerical cases for water, lava, and powdered snow across all five tiers.
- Staged hash-verified, disposable 1.20.1 Iris and Oculus test lanes with source revision and package hashes. The available launcher session is offline only, so loader compilation, rendered visuals, and frame times remain unverified.

## 1.0.6-dev-phase1 — unreleased

- Corrected underwater fog to use the loader's medium distance range and reach its endpoint regardless of view angle or rain. Low through Ultra retain their small profile fog-strength adjustment; lava and powdered snow retain the loader range.
- Corrected CRLF profile parsing so the five preset assignments validate on Windows. Added LF/CRLF and immersed-fog endpoint regressions.
- Standalone compilation and package checks are development evidence only. Loader-rendered visuals, cross-GPU behavior, and performance remain unverified.

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
