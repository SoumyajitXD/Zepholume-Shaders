# Baseline performance report

Status: **no runtime performance measurement exists** for shaders disabled, the previous Zepholume build, or any 0.2.0 profile. The reported 94–114 FPS observation is anecdotal and is not a baseline.

Static measures after the five-profile expansion:

- 48 source stages / 24 program pairs.
- One main colour attachment; no shadow, composite, history, depth texture, temporal, or extra full-resolution buffer path.
- 6,048 logical source mappings collapse to 210 unique expanded GLSL stages across declared profiles/dimensions/loader macro models.
- 210/210 unique stages pass standalone `glslangValidator` with zero recorded failures.

These figures do not measure FPS, frame time, CPU/GPU utilisation, VRAM, allocation churn, or reload time. Use `BENCHMARK_PROTOCOL.md` and `bench/scene-manifest.json` to produce those results without changing the scene between comparisons.
