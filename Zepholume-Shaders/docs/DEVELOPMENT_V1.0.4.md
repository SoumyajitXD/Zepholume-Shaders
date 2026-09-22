# V1.0.4 first performance development pass

Date: 2026-09-12. **V1.0.4 PERFORMANCE CANDIDATE BLOCKED BY RUNTIME VALIDATION.**

## Baseline and scope

CONTROL is the unchanged local `dist/Zepholume-Shaders-1.0.3-dev.zip`, 61,612 bytes, SHA-256 `C8C654607AF3A7A6E42966EDB75DA7ED17AA99A2CF8FBD94BF81A5899D7448A4`. This is the local development baseline, not evidence of a public V1.0.3 release. All 67 archive shader entries match all 67 working shader files byte for byte. [The frozen manifest](../bench/v103-control.json) records every shader hash. A pre-edit inventory of shaders, scripts, documentation, manifests and root metadata is retained in `artifacts/v104-first-pass/before-files.json`.

Git reports an unborn `master` and an untracked project; there is no local commit history or tracked diff to use. Git metadata was left untouched. The working source is now the explicitly labelled `1.0.4-fog-hoist-treatment`; the frozen CONTROL archive remains immutable and is still the only valid control capture package. This is an experimental shader treatment, not a retained release change. No performance claim is made because no qualified benchmark has run.

Three subagents independently audited shader architecture/hot paths, benchmark evidence, and validation/compatibility tooling. The audit covered every authored stage and include, profile configuration, existing optimisation history, all maintained documentation and scripts, compiled variants, the archive and local Git state. The unrelated `SemiliarShaders` donor directory was not used: no third-party shader code, constants, assets or implementation structure was imported.

## Hot-path map

There are 14 root program pairs and 10 explicit dimension-wrapper pairs, for 24 pairs/48 authored stages. Wrapper count is not a count of passes executed per frame. All routes write one colour target. No fullscreen post-processing pipeline, shadows, history, extra buffers, compute or geometry stages were added. Actual program invocation frequency and GPU time require loader/runtime profiling; the costs below are source-derived hypotheses.

| Programs / workload | Fragment work | Vertex work / scope |
| --- | --- | --- |
| Terrain, entities, block entities (`gbuffers_block`), textured/lit particle and translucent fallbacks | Texture/vertex colour, shared normal, face lighting, block-light dominance division, material response, decode/grade/encode, fog | Position/normal matrices, distance, view direction and light coordinates; exact fallback assignment is loader-dependent |
| Water | Above plus view/half-vector normalisations, both celestial specular power chains, fourth/fifth-power grazing response, transmission and reflection mixes | Two bounded trigonometric waves at Balanced; third wave at High/Ultra; compile-time removal below Balanced |
| Basic, glint, damaged block | Generic route; basic omits texture/UV | Shared generic vertex route |
| Hand | Hand-specific grading and fog; lighting/material output consumers bypassed | Shared vertex route; dead normal calculation is compiler-removable |
| Weather | Generic route plus weather colour response | Shared vertex route |
| Sky basic/textured | Gradient/celestial glow or texture/weather treatment, stars/void stage decisions | Dedicated sky transform/direction |
| Clouds | Texture, daylight/twilight, underside response, high-tier rim, weather desaturation, fog | Dedicated cloud transform and orientation |
| Explicit Nether/End wrappers | Terrain/entities/textured/textured_lit/water replace Overworld celestial paths with dimension ambient/fog | Other program families fall back to root sources in the generator; do not claim universal dimension isolation |

No fragment loops, fragment trigonometry, `pow` calls or multiple texture samples occur in the active authored fragment routes. These are source observations, not driver instruction counts. Includes and dead helper bodies inflate static source metrics; compilers can inline, fold and eliminate them.

### Profile audit

Balanced remains default and existing compile-time caps are preserved. Potato removes active analytical face/material/water/cloud/sky consumers. Its above-water generic fog still computes atmospheric colour; exact loader fog-colour preservation applies underwater, so README wording was corrected. Low retains directional response, fourth-power water and bounded underwater tint. Balanced adds material response, water waves and stronger depth treatment. High/Ultra preserve ambient hemispheres, wrapped face response, fifth-power water and top-facet cloud rim. Weather qualities 1/2/3 share an implementation; cloud tiers 3/4 share a path. Tier plateaus are documented rather than filled with new effects.

### Existing savings and invariants

V1.0.3 already removes the water encode/decode round trip and shares one surface normal across lighting/material/water. Earlier work already moved waves to vertices, used multiplication chains for integer powers, shared sky direction normalisation, omitted basic UVs, and removed unreachable feature branches. Hermite skylight/warmth curves with named reciprocal constants are correctness-preserving mathematics, not measured GPU gains. Preserve safe-normalisation epsilon, warmth denominator, cave skylight gating, output alpha, colour-space order, continuous day/night contribution, tier-specific Fresnel powers and bounded underwater fog.

## Ranked experiments and rejection decisions

Expected savings are qualitative and unprofiled. None is accepted production code.

| Rank / candidate | Expected work reduction and frequency | Implementation / visual / portability risk | Benchmarkability and decision |
| --- | --- | --- | --- |
| 1. Draw-uniform fog endpoint hoisting: `fog.glsl:zephComputeFogEndpoint`, consumed by `fragment.glsl` | Sun normalisation, daylight/twilight and colour arithmetic are uniform-only; computing per vertex and transporting a flat value could reduce work over most fogged pixels | Moderate interface/varying and loader risk; low intended visual risk but float precision and patched interfaces require testing | Implemented as the current TREATMENT. Driver may already execute uniform work efficiently; runtime verdict pending. |
| 2. Zero-weight water celestial lobe gates: `water.glsl:zephWaterSurfaceLinear` | Potentially skip half-vector normalisation and power chain when an entire lobe's weight is exactly zero; water-heavy pixels | Moderate compiler/control-flow risk, boundary-sensitive visual risk, no intended vendor dependence | Noon/night and continuous twilight, including grazing water. Existing mathematical guard intentionally rejects daylight branches; change only with boundary tests and measured justification. Deferred |
| 3. Earlier stars-stage branch: `sky_fragment.glsl` | Avoid analytical result later overwritten for stars draws | Low-to-moderate ordering risk; preserve void/stars behaviour; loader render-stage dependency | Stars-heavy scene; small total-frame coverage and possible existing compiler elimination. Deferred |
| 4. Explicit sun/moon/daylight reuse across water, lighting, fog | Repeated source expressions may already disappear through inlining/CSE | Low mathematical but unnecessary maintenance risk | Reject absent target compiled-code evidence that duplicates survive |
| 5. Cloud uniform precomputation / fog reciprocal | Fewer repeated draw-uniform expressions, less coverage than general fog | Moderate varying/interface risk, low intended visual change | Defer until rank 1 is measured |

Rejected as a performance deliverable: shorter source, dead includes/uniform removal, `dot(up,sunDir)` to `.y`, hand dead-normal cleanup, renaming/reimplementing previous savings, blind branch-to-mix conversion, nonlinear normal/lighting interpolation, approximate powers/clamps, profile quality reductions and heavyweight rendering features. No candidate was implemented then kept despite missing evidence; no benchmark-based revert was necessary. Mathematical equivalence alone cannot show fewer executed GPU instructions.

## Tooling changes

`benchmark-summarize.ps1` now supports versioned development candidates, rejects non-finite/nonpositive input and invalid derived statistics, and reports population variance/stddev, interval duration and explicit inverse-p99 FPS. `onePercentLowFps` remains a documented legacy alias.

`benchmark-series.ps1` recomputes raw hash-bound CSV summaries; requires at least six chronological CONTROL/CONTROL pairs then eight alternating-order CONTROL/TREATMENT pairs; checks unique run IDs/content, stable role hashes, captured conditions, valid timing and comparable intervals. It reports per-pair deltas and metric-specific observed A/A envelopes. It cannot authenticate gameplay, verify declared environment exports, infer a bottleneck, establish a confidence interval or automatically prove a release win. The old two-run comparator remains an explicitly limited helper. See the [capture protocol](BENCHMARK_PROTOCOL.md).

## Benchmark results

**RUNTIME PERFORMANCE: UNPROVEN.**

| Evidence | CONTROL V1.0.3-dev | TREATMENT V1.0.4 |
| --- | --- | --- |
| Immutable shader baseline | Verified, 67/67 files | No retained production candidate |
| Real capture runs / A/A noise floor | Not captured | Not captured |
| Average FPS / median / p95 / p99 / inverse-p99 FPS / variance | Unavailable | Unavailable |
| GPU utilisation / clock / power / bottleneck attribution | Unavailable | Unavailable |

Exact blocker: the project has no qualified rendered V1.0.3 control capture, frozen completed scene/camera manifest or controlled raw frametime series. `runtime-test.ps1` provides Verify/Collect/Reset, not a legitimate game launch and capture runner. Operator launch and capture in the isolated instances are required; no authentication bypass, account handling or normal-save changes were attempted. The synthetic tests exercise tooling only and supply no row in this table.

## Validation and compatibility

Fresh local evidence is under `artifacts/v104-first-pass/`:

- Structural/package validator and its negative-fixture suite passed, including existing deterministic mathematical regressions.
- Portability matrix passed 756 mocked cases with 48 stages per case. These are include/profile corpus checks and metadata-labelled cases, not 756 GPU/compiler executions.
- Fresh evaluated variant generation passed: 6,048 logical mappings, **156 unique stages**. This supersedes the historical 154-stage count for this exact frozen control; it does not establish why that older snapshot differed.
- glslang 16.4.0 compiled all 156 freshly generated stages: zero warnings, zero errors. The previously reported Application Control execution block did not recur. Source metrics were regenerated successfully; they are source proxies only, not optimised driver ISA or performance results.
- Benchmark regression suite passed 43 synthetic checks, covering arithmetic, the legacy two-run helper, A/A and A/B direction, within-noise and regression classifications, invalid-number/identity/timing/hash/replication rejection.
- Iris and Oculus `Verify` both passed isolated package/mod/hash/Java readiness. This is the staged V1.0.3 control, not game launch, patched compilation or rendering.

Iris 1.20.1 (Iris 1.7.6/Sodium 0.5.13) and Oculus 1.20.1 (Oculus 1.8.0/Embeddium 0.3.31) remain **staged only**, with runtime/visual qualification missing. Existing newer Iris lanes remain documented source/static targets; no version-support upgrade or live upstream compatibility revalidation was performed. Community Oculus limitations remain as recorded in the compatibility matrix. NVIDIA/AMD/Intel are portability intentions and static labels, with **no cross-vendor runtime evidence**. OptiFine remains unsupported.

The final visual gate still needs sunrise/sunset/noon/night/rain; caves/overhangs/bright block lights; shallow/grazing water and underwater scenes with/without night vision; Nether/End; clouds/distant fog and biome transitions, across the maintained profiles. No mathematical shader transformation was made, so existing mathematical invariants remain the ones under test.

## Files changed

- `README.md`: development status and precise Potato fog behaviour.
- `CHANGELOG.md`: evidence-scoped development entry.
- `bench/run-manifest-template.json`: schema 2 capture identity/settings fields.
- `bench/v103-control.json`: new archive identity and complete frozen shader hash inventory.
- `scripts/benchmark-summarize.ps1`: finite numeric validation and pacing statistics.
- `scripts/benchmark-series.ps1`: new replicated, raw-bound A/A and A/B analysis.
- `scripts/tests/benchmark-tests.ps1`: synthetic positive/negative regression coverage.
- `docs/BENCHMARK_PROTOCOL.md`: controlled capture and descriptive noise methodology.
- `docs/DEVELOPMENT_V1.0.4.md`: this audit and evidence report.

Generated evidence is isolated under `artifacts/v104-first-pass/`; its final `artifact-index.txt` lists the generated files. A separate `dist/Zepholume-validation-v104-pass.zip` and `.sha256` exercise packaging only: unchanged V1.0.3 shaders plus current development documentation, not a V1.0.4 shader candidate or final release. The original CONTROL archive remains intact.

## Next task and remaining blockers

Capture the unchanged control's Balanced A/A series in one isolated loader with exact scene/settings and GPU/presentation telemetry. Once a fragment bottleneck is established, test **draw-uniform fog endpoint hoisting** as the single next optimisation, inspect loader-patched interfaces, run numerical/visual checks and counterbalanced A/B. Retain it only beyond the observed noise envelope with no tail or visual regression.

Remaining concrete blockers are the absent qualified control run, completed frozen capture scene, raw A/A and A/B data, loader-rendered visual matrix and cross-vendor runtime coverage. Standalone GLSL execution is no longer a blocker on this run. No final V1.0.4 release was packaged or published, and nothing was pushed.

## Fog endpoint hoist treatment — 2026-09-12

### Hypothesis and exact operations

The only generic fog call previously invoked `zephFogColour(zephViewDirection)` in every fogged fragment. Its argument was unused. `zephComputeFogEndpoint()` depends only on draw uniforms (`fogColor`, `isEyeInWater`, `nightVision`, `rainStrength`, `sunPosition`) and compile-time profile/dimension selection. It has no texture, fragment, position, screen, derivative, or interpolated input. The TREATMENT evaluates that endpoint in `lib/vertex.glsl`, exports `flat varying vec3 zephFogEndpoint`, and the fragment mix consumes that value. `zephFogFactor(zephDistance, zephViewDirection.y)` remains wholly fragment-local; no fog distance, depth, or view-direction calculation moved.

This removes the endpoint's safe sun normalisation, two Hermite curves, atmosphere colour mixing, and horizon-warmth mixing from each affected fragment invocation. It adds those operations per generic-program vertex plus one flat vec3 interface. The net GPU cost is unknown and may be neutral or worse.

### Correctness and static evidence

`scripts/tests/fog-hoist-equivalence.ps1` source-locks the common GLSL helper and evaluates its float32-equivalent operation order for 4,500 cases: profile tiers, Overworld/Nether/End, underwater/night vision, clear/rain/storm, daylight/twilight/night and minimum/maximum/representative fog colours. CONTROL-versus-TREATMENT maximum absolute error was `0`; maximum relative error was `0` in that host float32 evaluation. This proves neither loader-patched compilation nor rendered output.

The structural validator now checks interpolation qualifiers as part of a vertex/fragment interface, and its negative suite rejects a `flat`-to-smooth mismatch. The treatment regenerated 6,048 logical mappings and 180 unique evaluated stages; all 180 compile with glslang 16.4.0 with zero warnings/errors. The unique-stage count rises from the control's 156 because the formerly shared vertex sources now specialize on fog endpoint profile/dimension paths. This is not a performance result.

### Runtime and visual protocol

Build only the separately named `Zepholume-Shaders-1.0.4-fog-hoist-treatment.zip`; never overwrite the CONTROL archive. Its package hash is recorded beside it in `dist/Zepholume-Shaders-1.0.4-fog-hoist-treatment.zip.sha256`, and the treatment manifest intentionally points to that external hash file to avoid a self-referential archive hash. Before any A/B capture, hash both ZIPs, capture six fresh counterbalanced CONTROL/CONTROL pairs, establish a plausible fragment-bound condition, then capture eight alternating CONTROL/TREATMENT pairs under the unchanged manifest settings. Use the guarded `scripts/v104-runtime-capture.ps1`, `bench/run-manifest-template.json` and `docs/BENCHMARK_PROTOCOL.md`; record unavailable telemetry rather than inventing it.

Manual action is still required: in each disposable Iris and Oculus instance, copy the treatment ZIP alongside (not over) the CONTROL, select it explicitly, and capture the requested lossless scene matrix plus loader logs/patched shaders. No account handling, launcher automation, normal-world changes, A/A results, A/B results, visual screenshots, Iris/Oculus patched compilation, or GPU qualification occurred in this pass. Retention is therefore blocked; if the measurements are neutral, inside A/A noise, regressive, or visually incompatible, revert the four treatment source changes and record rejection before considering another candidate.

## Gemini Handoff Audit and Takeover — 2026-09-13

### Inherited State & Handoff Audit
- **Worktree state:** Repository operating on an unborn `master` branch without Git commit history. Pre-Gemini state frozen and archived under `artifacts/v104-handoff-pre-gemini/` including `handoff-diff.patch`, `pre-gemini-tree-inventory.json`, and isolated control copies.
- **Codex modifications audited:** Exactly 10 files modified/created (+168 / -22 lines across production, tests, and scripts):
  1. `shaders/lib/fog.glsl` (hoisted draw-uniform `zephComputeFogEndpoint()`, removed dummy parameter)
  2. `shaders/lib/vertex.glsl` (draw uniforms, `flat varying vec3 zephFogEndpoint;`, evaluate once per vertex in `main()`)
  3. `shaders/lib/fragment.glsl` (`flat varying vec3 zephFogEndpoint;`, consume in generic fog mix; keep `zephFogFactor` fragment-local)
  4. `shaders/shaders.properties` (updated header comment identifier)
  5. `scripts/validate.ps1` (extended varying interface regex to support `flat varying`, updated version pattern)
  6. `scripts/package.ps1` (default package target points to `Zepholume-Shaders-1.0.4-fog-hoist-treatment.zip`)
  7. `scripts/tests/validate-tests.ps1` (integrated fog equivalence and added 24th negative fixture `flat-varying-mismatch`)
  8. `scripts/tests/fog-hoist-equivalence.ps1` (new mathematical equivalence test suite)
  9. `bench/v104-fog-hoist-treatment.json` (new treatment benchmark role manifest)
  10. `docs/DEVELOPMENT_V1.0.4.md` (pass documentation)
- **Control Integrity:** Frozen CONTROL archive `dist/Zepholume-Shaders-1.0.3-dev.zip` verified against expected SHA-256 `C8C654607AF3A7A6E42966EDB75DA7ED17AA99A2CF8FBD94BF81A5899D7448A4` (Match: EXACT). All 63 unmodified shader files match CONTROL byte-for-byte.

### Complete Static & Mathematical Re-Validation
All verification suites executed and passed cleanly:
- **Mathematical equivalence (`fog-hoist-equivalence.ps1`):** 4,500 representative and boundary cases evaluated across dimensions (Overworld/Nether/End), profile tiers (Potato–Ultra), fluid states (air/water), night vision, rain strength, color extrema, and solar angles. Maximum absolute error = `0.0`, maximum relative error = `0.0` (exact-zero in IEEE 754 float32 evaluation).
- **Mathematical regression (`math-regression.ps1`):** All smoothstep reciprocal bounds and water working-space conversions verified.
- **Structural validator (`validate.ps1`):** 48 program stages checked. All 21 vertex/fragment pairs declaring `flat varying vec3 zephFogEndpoint` match identically.
- **Negative fixtures (`validate-tests.ps1`):** 24/24 negative mutations rejected as expected, including `flat-varying-mismatch`.
- **Preprocessed variant generation (`generate-compiled-variants.ps1`):** 6,048 logical mappings expanded to 180 unique stages (expanded from 156 due to vertex specialization on fog profile/dimension branches).
- **GLSL compilation (`validate-glsl.ps1`):** All 180 stages compiled cleanly via Khronos `glslangValidator` 16.4.0 in desktop OpenGL GLSL mode (0 warnings, 0 errors).
- **Portability matrix (`portability-matrix.ps1`):** 756 mocked portability cases passed across vendors, loaders, profiles, and dimensions.
- **Benchmark tooling unit tests (`benchmark-tests.ps1`):** 43 synthetic checks passed.

### Runtime Environment Staging & Blocker Status
- Both `runtime-test.ps1 -Target Iris -Action Verify` and `-Target Oculus -Action Verify` passed.
- Both `Zepholume-Shaders-1.0.3-dev.zip` and `Zepholume-Shaders-1.0.4-fog-hoist-treatment.zip` (SHA-256 `C182C53D51ECDA4C0F271CB25E375A9A7239CC5CC47A181F2560FB40F7C641CD`) are staged side-by-side in both runtime shaderpacks directories.
- Full automation of game execution, world navigation, and frametime capture is blocked by Minecraft launcher GUI and authentication boundaries. No synthetic runtime numbers are manufactured.
- **Verdict:** `V1.0.4 PERFORMANCE CANDIDATE BLOCKED BY RUNTIME VALIDATION`.

## Water celestial-specular gating treatment — 2026-09-19

This is a second, isolated experimental treatment layered on the existing fog-hoist work; it does not alter the immutable V1.0.3-dev CONTROL and does not promote either treatment to a release baseline.

| Candidate | Hot path | Original cost/problem | Treatment | Correctness | Static result | Runtime result | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Water celestial-specular exact-zero gating | Overworld water fragments at full day/night and celestial-horizon-zero states | Both sun and moon always built a half vector, normalised it, evaluated a dot product and executed the tiered power chain, although the completed lobe could be multiplied by an exact uniform zero | Calculate the existing uniform-only day/horizon weights first; retain the exact old arithmetic order inside a lobe, but skip its lobe-only work when that weight is exactly zero. At full daylight, skip moon direction normalisation as well. | `water-specular-gating-equivalence.ps1` source-locks the predicates and original product order, then evaluates 1,440 float32 boundary/profile/fluid predicate cases. 1,680 lobe paths were eligible to skip; maximum absolute error for every skipped zero product is 0.0. | Fresh generation: 6,048 mappings, 180 unique stages; glslang 16.4.0: 180/180 pass, zero warnings/errors. Source proxy totals retain 814 normalisation calls, 672 sqrt calls, 466 divisions and 92 texture calls; dynamic `if` tokens rise 296→488 because this metric counts the guarded source across expanded variants, not executed GPU work. The gate adds no uniform, varying, target or vendor extension. | Unavailable: no loader-patched compilation, rendered visual comparison, frame-time series or bottleneck attribution. | **RETAIN CANDIDATE — RUNTIME DECISION REQUIRED** |

The gate is deliberately not a per-pixel normal-dot branch: `daylight`, celestial horizon fades and positions are draw-uniform state, so all fragments in the draw take the same lobe path. The nonzero twilight path retains the prior continuous sun/moon transfer and its multiplication order. The change does not attempt to skip a lobe merely because `NdotH` is zero, because that varies per fragment and could cause harmful divergence.

Rollback is one source-file reversion (`shaders/lib/water.glsl`); the treatment-specific equivalence test and manifest can then be removed without touching CONTROL or fog-hoist artifacts. `bench/v104-water-specular-gating-treatment.json` binds the separately named archive to CONTROL. The required runtime sequence remains six fresh CONTROL/CONTROL pairs, a demonstrated fragment-bound scenario, then eight alternating CONTROL/TREATMENT pairs with patched shaders, logs and rendered visual coverage.

## Production finalisation — 2026-09-19

### Production decision

The canonical `shaders/` source is now the **V1.0.4 production release**: the immutable V1.0.3-dev CONTROL plus only the water celestial-specular exact-zero gate. The fog endpoint hoist is excluded from production. Its manifest, separately hashed package, source-locking test and prior evidence remain preserved as **DEFERRED — NOT INCLUDED IN V1.0.4 PRODUCTION**.

The retained water gate has no new varying, uniform, target, extension or vendor path. Its 1,440 float32 predicate cases cover 1,680 skipped exact-zero lobes with maximum absolute output error `0.0`. It is an efficiency hypothesis with a mathematical identity proof, not an FPS result.

### Release evidence boundary

The final public archive is intentionally built from an allow-list: shader sources plus `README.md`, `CHANGELOG.md`, and `THIRD_PARTY_NOTICES.md`. It excludes `artifacts/`, `bench/`, `docs/`, `runtime/`, `tools/`, generated reports, treatment archives, tests, screenshots and machine-local paths. Packaging uses sorted paths and a fixed ZIP timestamp so the same frozen source can be byte-reproduced.

Static validation, standalone GLSL validation, portability modelling, profile checks, package checks and mathematical tests establish source and package readiness only. Iris live load, Iris patched-shader inspection, rendered visual coverage, Oculus live load, and real V1.0.3 CONTROL versus V1.0.4 A/A and A/B benchmarking remain operator work. No runtime compatibility or performance conclusion is implied.
