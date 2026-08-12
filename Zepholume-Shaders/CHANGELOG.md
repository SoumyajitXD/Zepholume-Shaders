# Changelog

## 0.2.0-dev — unreleased

- Replaced two presets with Potato, Low, Balanced (default), High, and Ultra; Ultra Lite remains a documented Low compatibility alias.
- Added a single profile configuration matrix, grouped option UI, and static profile/option validation.
- Reworked the direct colour path around bounded display decoding, exposure, contrast, temperature, highlight compression, and hand-safe grading.
- Added profile-gated face/material response, atmospheric fog, analytical sky/celestial glow, directional cloud response, weather response, and Fresnel-style water treatment.
- Added repeatable benchmark and visual-regression manifests. No runtime benchmark or screenshot result is claimed in this release candidate.

## 0.1.0-dev

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
