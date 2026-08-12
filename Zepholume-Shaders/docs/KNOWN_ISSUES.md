# Known issues

## Runtime verification blockers

- Iris and Oculus have not loaded the final Zepholume package in this stage, so all rendering-matrix items and profile switching remain untested.
- The local Oculus stack is a normal saved modpack and must not be repurposed without explicit approval or a disposable clone.
- No safe authenticated launcher command was available locally; launcher credentials and account files were intentionally not inspected.

## Corrected before runtime testing

- Both `gbuffers_skybasic` wrappers contained `#define #define ZEPH_NO_FOG`, a malformed preprocessor directive. It is fixed and structurally guarded.
- Sky/cloud generic-terrain processing and second vertex-colour lighting were removed at source level. Visual acceptance, Fast/Fancy/off cloud behavior, stage macro behavior, and loader parity remain manual-test items.
