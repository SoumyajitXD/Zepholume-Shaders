# Benchmark protocol

V1.0.4 first pass, 2026-09-07. **RUNTIME PERFORMANCE: UNPROVEN.** No captured results accompany this procedure. Earlier V1.0.2 versus V1.0.3 work remains historical; the new CONTROL is the unchanged local V1.0.3-dev archive identified in [the frozen inventory](../bench/v103-control.json). Do not rebuild or overwrite that archive. TREATMENT must be a separately hashed development candidate. No production candidate is retained in this pass.

## Capture conditions

Use disposable isolated Minecraft 1.20.1 Iris/Sodium and Oculus/Embeddium instances separately, with Java 17. Run each loader as its own series. Freeze an initial disposable-world snapshot and restore it consistently between captures. Complete the [scene manifest](../bench/scene-manifest.json) with real viewpoints before hashing it. Fix seed, dimension, location, camera path (stationary is valid), time, weather, loaded chunks/entities, resolution, render scale, render/simulation distance, FOV, VSync, FPS limit, resources, shader options, Minecraft, loader, every mod, JVM arguments, hardware and driver. Keep power policy, background work and thermal conditions stable and record deviations.

Begin with Balanced on an agreed representative terrain scene, then a water-heavy scene. Select scenes before observing candidate results. Repeat other profiles and the visual scene matrix before release; do not pool different loaders, profiles, GPUs or scenes. Wait for chunk loading and shader compilation to settle. The minimum procedure is a fresh 30-second warm-up followed by a 60-second measurement for every run; lengthen it consistently if settling is incomplete. Capture intervals must exclude reloads, menus, warm-up and loading. Record the actual capture start in UTC. Capture one target game process only.

Store raw per-frame intervals in invariant-culture milliseconds with a `frameTimeMs` column. A capture-tool adapter must document the source field and whether it measures presentation cadence, displayed frames or GPU execution. Do not substitute GPU-busy duration for presentation intervals or silently discard outliers. Missing/dropped capture data invalidates a run; retain the original raw export and the documented conversion. The analyzer checks summed intervals against declared duration with a 2% tolerance (minimum 0.1 seconds); this is a completeness sanity check, not wall-clock proof.

Record GPU utilisation, clocks, power, CPU/GPU busy telemetry and VRAM only when the recorder supplies reliable measurements. Save them as companion evidence and list unavailable metrics in the run manifest. No script infers bottleneck state from FPS or utilisation alone. Compare GPU/CPU timings and controlled resolution sensitivity when establishing the limiting stage. Capture lossless visual references and loader-patched shaders separately; numerical regressions and standalone GLSL are not rendered-world evidence.

## A/A before A/B

1. Capture at least six independent CONTROL/CONTROL pairs (twelve unique runs), with a fresh warm-up each time. This measures an observed noise envelope, not a confidence interval. If drift or excessive noise appears, resolve it and repeat the entire series before testing a candidate.
2. Capture at least eight CONTROL/TREATMENT pairs, alternating chronological order: `CONTROL,TREATMENT`, then `TREATMENT,CONTROL`, and so on (or the inverse). This counterbalances simple order effects; inspect every pair for drift rather than trusting its median alone.
3. Use one captured [run manifest](../bench/run-manifest-template.json) per CSV. Set `status` to `captured`, a unique `runId`, and its role. Hash the actual raw CSV. Hash exports of shader options, resource inventory (including a written Default declaration when appropriate), JVM arguments, mod inventory, initial world snapshot and camera specification. These are operator declarations and must be checked against the actual capture; a valid hash string is not proof of its contents.
4. Keep world/runtime/settings object key order consistent with the template. The analyzer conservatively compares complete objects as well as scene/profile/tool/timing identity. Missing values, changed conditions, reused runs/content, overlapping intervals, changing pack identities and insufficient replication are rejected. Distinct content hashes cannot prove captures were independent; that remains a capture obligation.

Create `series.json` next to the run manifests:

```json
{
  "schemaVersion": 1,
  "pairs": [
    {"kind":"AA","runs":["aa1-a.json","aa1-b.json"]}, {"kind":"AA","runs":["aa2-a.json","aa2-b.json"]},
    {"kind":"AA","runs":["aa3-a.json","aa3-b.json"]}, {"kind":"AA","runs":["aa4-a.json","aa4-b.json"]},
    {"kind":"AA","runs":["aa5-a.json","aa5-b.json"]}, {"kind":"AA","runs":["aa6-a.json","aa6-b.json"]},
    {"kind":"AB","runs":["ab1-control.json","ab1-treatment.json"]}, {"kind":"AB","runs":["ab2-treatment.json","ab2-control.json"]},
    {"kind":"AB","runs":["ab3-control.json","ab3-treatment.json"]}, {"kind":"AB","runs":["ab4-treatment.json","ab4-control.json"]},
    {"kind":"AB","runs":["ab5-control.json","ab5-treatment.json"]}, {"kind":"AB","runs":["ab6-treatment.json","ab6-control.json"]},
    {"kind":"AB","runs":["ab7-control.json","ab7-treatment.json"]}, {"kind":"AB","runs":["ab8-treatment.json","ab8-control.json"]}
  ]
}
```

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoLogo -NoProfile -File scripts/benchmark-series.ps1 -SeriesManifest <series.json> -OutputJson <comparison.json>
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoLogo -NoProfile -File scripts/benchmark-summarize.ps1 -InputCsv <run.csv> -PackVersion 1.0.4-dev -Profile Balanced -OutputJson <summary.json>
```

The series analyzer recomputes summaries from raw CSVs rather than accepting supplied summary metrics. It reports per-run mean, nearest-rank median/p95/p99, average FPS, inverse-p99 FPS, population variance and standard deviation. The legacy `onePercentLowFps` field is an alias for inverse-p99, not the mean of the slowest 1%. Frame-time variance describes within-run pacing; A/A paired deltas describe between-run variation. Do not treat thousands of frames as thousands of independent benchmark repetitions.

For each mean/median/p95/p99 metric, the series reports maximum absolute A/A paired percentage delta and median paired TREATMENT-minus-CONTROL percentage delta. Negative frametime delta is better. A gain inside the observed envelope is inconclusive; a gain outside it is only `candidate-improvement-requires-review`. Positive differences beyond the envelope request regression review. The tool never declares performance proof, even with zero observed A/A variation. Review per-run variance, tail regressions, drift, capture validity, matched screenshots and loader/GPU correctness before retention. Expand repetitions when results are ambiguous. A 0.5% change with a 2% noise envelope is not a win.

The older `benchmark-compare.ps1` remains a two-run descriptive helper. It does not enforce this series protocol and must not be used as the V1.0.4 acceptance gate. Synthetic regression fixtures are tooling tests only; never place them in a runtime-results table.
