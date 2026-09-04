# Known issues

## Runtime verification blockers

- Iris and Oculus have not loaded the final Zepholume package in this stage, so all rendering-matrix items and profile switching remain untested.
- The local Oculus stack is a normal saved modpack and must not be repurposed without explicit approval or a disposable clone.
- No safe authenticated launcher command was available locally; launcher credentials and account files were intentionally not inspected.

## Corrected before runtime testing

- Both `gbuffers_skybasic` wrappers contained `#define #define ZEPH_NO_FOG`, a malformed preprocessor directive. It is fixed and structurally guarded.
- Sky/cloud generic-terrain processing and second vertex-colour lighting were removed at source level. Visual acceptance, Fast/Fancy/off cloud behavior, stage macro behavior, and loader parity remain manual-test items.
## V1.0.1-dev status

- No real Iris or Oculus launch, shader compilation, render, screenshot, or benchmark has been recorded for this development line. Static checks and standalone GLSL compilation are not substitutes.
- Animated water uses the common `frameTimeCounter` uniform. Its loader/runtime behaviour is pending Iris and Oculus verification.
- Vegetation is intentionally static: a cross-loader, mod-safe material/plant identification path has not been established, so Zepholume does not guess from texture colour or magic IDs.
- Mod/resource-pack custom core shaders may be bypassed by shader loaders; this is a loader-level compatibility limitation, not something Zepholume can guarantee away.
