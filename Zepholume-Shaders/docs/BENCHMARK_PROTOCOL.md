# Benchmark protocol

Status: **not yet executed**. This document defines the only acceptable comparison procedure for Zepholume. It does not contain results.

Use the locked settings and viewpoints in [`bench/scene-manifest.json`](../bench/scene-manifest.json). Create a fresh disposable world from one recorded seed, record exact coordinates/yaw/pitch for every viewpoint, and keep the Minecraft version, loader, mod list, Java, GPU driver, resolution, render scale, render/simulation distance, FOV, VSync, FPS cap, resource pack, time, and weather unchanged for every row.

For each of Shaders disabled, Potato, Low, Balanced, High, and Ultra: warm up for 30 seconds, measure the same stationary 60-second camera run, then record median FPS, 1% low FPS, mean/P95/P99 frame time, GPU utilisation, VRAM use when the capture tool supplies it, shader reload time, and post-test log warnings/errors. Capture source data—not only rounded overlays—and mark unavailable values explicitly.

The current local candidates are isolated 1.20.1 Iris and Oculus environments. No captured row exists yet, so the previous anecdotal 94–114 FPS observation is intentionally excluded.
