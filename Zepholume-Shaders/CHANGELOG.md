# Changelog

## 1.0.1 — released

- Centralised continuous sun-elevation and twilight response so terrain, clouds, sky, and Overworld fog no longer use incompatible day/night bands; hardened shared vector normalization against zero-length inputs.
- Refined the analytical Overworld sky with loader-provided sky/fog colour integration, restrained twilight warmth, smoother horizon separation, sun/moon glow, and rain desaturation. Potato now compiles out analytic sky and cloud lighting work.
- Reworked fog colour integration for clearer Overworld depth and restrained independent Nether/End atmosphere while retaining loader fog ranges and source alpha.
- Replaced the misleading static “surface movement” control with `Water movement`; Balanced and above now use bounded, frame-time-driven vertex waves with no depth reconstruction, SSR, or extra buffer.
- Removed the repeated display-to-linear decode in the generic scene route and removed the normal-route dependency on an Iris-specific thunder uniform, improving Iris/Oculus portability without claiming runtime verification.
- Added release-metadata checks to structural validation. No loader runtime test, benchmark, or cross-vendor claim is implied.

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
