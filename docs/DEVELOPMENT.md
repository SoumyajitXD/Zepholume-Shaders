# Development Guide

This document describes the development expectations for Zepholume Shaders. The implementation lives under `/Zepholume-Shaders`; this guide focuses on how changes should be approached and validated.

## Project priorities

Changes should optimise for, in order:

1. correctness
2. visual stability
3. performance and frame-time consistency
4. GPU/loader portability
5. maintainability
6. feature value relative to rendering cost

A feature that looks impressive in one screenshot but adds fragile code, major frame-time cost, or vendor-specific behaviour needs a very strong reason to exist.

## Keep the architecture lean

Zepholume deliberately uses a lightweight direct-path design. Do not introduce heavyweight rendering systems casually.

Before adding a new effect, answer:

- What visual problem does it solve?
- Can the effect be implemented analytically or in an existing pass?
- What is the fragment/vertex cost?
- Which quality profiles should compile it out?
- Does it require a new buffer or texture dependency?
- Does it create temporal state?
- Does it weaken Iris/Oculus or cross-vendor portability?
- How will it be validated visually and structurally?

“No, but other shader packs have it” is not an architecture argument.

## Shader style

Prefer:

- shared GLSL helpers over copy/paste
- explicit responsibilities for libraries
- compile-time profile gates for avoidable work
- bounded maths and predictable ranges
- clear names for colour-space and lighting operations
- include guards for shared source
- portable GLSL 330-compatible constructs
- comments explaining non-obvious rendering decisions rather than narrating every line

Avoid:

- vendor-specific hacks without a proven necessity
- hidden profile behaviour
- duplicated effect implementations
- unnecessary texture samples
- expensive loops in hot fragment paths
- speculative abstractions that make simple shader code harder to follow

## Profiles

Potato, Low, Balanced, High, and Ultra should remain meaningful cost/quality tiers.

A lower profile must not accidentally execute work intended only for a higher tier. New options should have explicit defaults and bounded ranges, and their relationship to the selected profile should be understandable.

## Validation

Before considering a shader change ready:

1. run the repository's structural/source validation tooling
2. check recursive includes and preprocessor output
3. verify vertex/fragment interfaces for affected program pairs
4. verify the intended output-target policy remains intact
5. check that all quality profiles expand successfully
6. test affected dimensions/scene categories
7. test with a real Iris or Oculus runtime when the change can affect loader compilation or rendering
8. inspect `latest.log` for new warnings/errors

Static GLSL validation is necessary but not sufficient. A standalone compiler cannot prove loader-patched source, GPU-driver behaviour, or visual correctness.

## Visual regression testing

For before/after comparisons, keep constant:

- world/seed
- player coordinates
- yaw/pitch
- time and weather
- Minecraft version
- loader and rendering-mod versions
- resource packs
- render/simulation distance
- resolution/render scale
- FOV
- VSync/FPS cap
- shader profile and non-target options

Capture the same viewpoints. Otherwise a screenshot comparison can become accidental marketing rather than evidence.

## Performance testing

Measure more than average FPS when possible:

- median FPS
- 1% low FPS
- mean frame time
- P95/P99 frame time
- GPU utilisation
- VRAM use
- shader reload time

Warm up the scene before measuring and compare identical conditions.

## Compatibility changes

When a change affects loader interaction, preprocessor macros, shader stages, or GLSL constructs, validate both Iris and Oculus paths where practical. Do not claim a GPU/vendor combination is fixed unless it was actually tested or the claim is clearly limited to static/source validation.

## Documentation

Update public documentation when a change affects:

- installation
- supported Minecraft versions
- required shader loaders
- profile behaviour
- compatibility expectations
- major architecture boundaries

Keep implementation-specific notes in the source documentation and public user guidance in root `/docs`.