# Benchmark protocol

Status: **not yet executed**. This document defines the only acceptable comparison procedure for Zepholume. It does not contain results.

Use the locked settings and viewpoints in [`bench/scene-manifest.json`](../bench/scene-manifest.json). Create a fresh disposable world from one recorded seed, record exact coordinates/yaw/pitch for every viewpoint, and keep the Minecraft version, loader, mod list, Java, GPU driver, resolution, render scale, render/simulation distance, FOV, VSync, FPS cap, resource pack, time, and weather unchanged for every row.

For each of Shaders disabled, Potato, Low, Balanced, High, and Ultra: warm up for 30 seconds, measure the same stationary 60-second camera run, then record median FPS, 1% low FPS, mean/P95/P99 frame time, GPU utilisation, VRAM use when the capture tool supplies it, shader reload time, and post-test log warnings/errors. Capture source data—not only rounded overlays—and mark unavailable values explicitly.

For the release comparison, run the same scene/profile first with **Zepholume V1.0.2**, then with **V1.0.3-dev** (preferably alternating A/B/A/B after a fresh warm-up). Store raw per-frame milliseconds as CSV and summarize each run with:

```powershell
pwsh -NoLogo -NoProfile -File scripts/benchmark-summarize.ps1 -InputCsv <run>.csv -PackVersion 1.0.2 -Profile Balanced
pwsh -NoLogo -NoProfile -File scripts/benchmark-summarize.ps1 -InputCsv <run>.csv -PackVersion 1.0.3-dev -Profile Balanced
```

The parser calculates only frame-time-derived values; GPU utilisation, power, VRAM, CPU use, driver, and camera/environment identity must be recorded by the operator and remain `unavailable` when the capture tool does not provide them.

For every CSV, copy and complete [`bench/run-manifest-template.json`](../bench/run-manifest-template.json). The comparison parser refuses mismatched profile, scene, scene-manifest hash, or locked-environment identity:

```powershell
pwsh -NoLogo -NoProfile -File scripts/benchmark-compare.ps1 -SummaryA <v102.summary.json> -RunManifestA <v102.run.json> -SummaryB <v103.summary.json> -RunManifestB <v103.run.json>
```

Its deltas are observations from those captured inputs, not an FPS claim or a substitute for replicated A/B/A/B evidence.

The current local candidates are isolated 1.20.1 Iris and Oculus environments. No captured row exists yet, so the previous anecdotal 94–114 FPS observation is intentionally excluded.
