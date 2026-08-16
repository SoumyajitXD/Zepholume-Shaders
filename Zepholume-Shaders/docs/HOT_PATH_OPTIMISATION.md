# Hot-path optimisation, 1.0.1

This pass measures Zepholume-preprocessed source, not GPU instructions or FPS. Runtime benchmarking remains required.

## Implemented reductions

- Removed seven globally declared but irrelevant uniforms from ordinary fragment paths. Ultra Lite generic paths now declare only `texture`, `fogColor`, `fogStart`, and `fogEnd`; Balanced adds only `rainStrength` for its guarded fog response.
- Removed the unused texture-coordinate varying from the untextured basic pair. Its vertex shader no longer reads `gl_MultiTexCoord0`.
- Removed the dead `zephShapeLighting` helper and its unused `lighting.glsl` file.
- Isolated sky and cloud interfaces from generic helpers, preventing generic clamp helpers and unrelated declarations entering those expanded stages.

Texture sampling remains one essential source sample for textured geometry, water, clouds, and textured sky. No duplicate texture read was present to remove. There are no fragment `pow`, loops, or `discard` operations. Water trigonometry remains vertex-only and is compiled out below Balanced. V1.0.1 also removes a redundant display-to-linear decode from the generic scene grade.

## Source comparison

| Metric across 38 deduplicated expanded stages | Before | After | Change |
| --- | ---: | ---: | ---: |
| Source bytes | 76,544 | 75,718 | -826 |
| Functions | 198 | 186 | -12 |
| Uniform declarations | 180 | 108 | -72 |
| Texture calls | 20 | 20 | 0 |
| Varying declarations | 114 | 114 | 0 |
| Divisions | 34 | 34 | 0 |
| Fragment trigonometric calls | 0 | 0 | 0 |
| Dynamic branches | 16 | 16 | 0 |

The aggregate varying declaration total does not change because the isolated untextured basic source is deduplicated with other interface-equivalent expanded sources in this source model; the program-pair interface itself is smaller.

`artifacts/performance-analysis/baseline/stage-stats.json` and `artifacts/performance-analysis/final/stage-stats.json` contain every stage statistic, including source bytes, lines, include relationships, macros, functions, uniforms, attributes, varyings, texture calls, numerical operations, branches, discard, and fragment outputs.

## Compiler validation

The deterministic generator maps Ultra Lite and Balanced, Overworld/Nether/End, conservative Iris/Oculus models, and generic/NVIDIA/AMD/Intel/Mesa/Unknown identities. Identities do not alter source because Zepholume has no vendor branches. The 2,016 logical mappings deduplicate to 38 source files.

The official Khronos `main-tot` Windows Release asset was downloaded from `KhronosGroup/glslang` and SHA-256 verified as `7DF6A52516AE5942B234E8DD9314C0CF7F6792126C1DB712E9EBB6F48B0BFEC1`. It is a 15,354,793-byte GitHub Actions release artifact. Only `glslangValidator.exe` was extracted to `tools/glslang/main-tot/`.

Execution is currently blocked by Windows Application Control, before the validator can print its own exact build string or compile a shader. `scripts/validate-glsl.ps1` detects the configured binary, invokes it separately for each expanded vertex/fragment stage in OpenGL GLSL mode, captures output in JSON and Markdown, and returns non-zero on warnings/errors or compiler failure. It deliberately does not pass Iris include syntax to the compiler and does not use Vulkan/SPIR-V flags.

Standalone success, once this policy block is lifted, validates the Zepholume-preprocessed source only. It is not proof that Iris/Oculus's patched runtime shader will compile. No custom uniforms were added.
