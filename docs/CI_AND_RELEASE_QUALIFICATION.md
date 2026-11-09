# Continuous integration and release qualification

## V1.0.7 qualification snapshot (2026-11-09)

**Exported locally: YES. Fully cross-vendor and cross-loader qualified: NOT ESTABLISHED.** The [V1.0.7 ZIP](../Releases/Zepholume-Shaders-1.0.7.zip) is present in the repository; the [final release report](../Zepholume-Shaders/docs/V1.0.7_FINAL_RELEASE.md) records 320 standalone GLSL-stage checks, 420 links and deterministic packaging. Local Minecraft 26.1.2/Fabric/Iris/Intel release-candidate runtime evidence does not imply cross-vendor support or measured FPS gains.

**Hosted CI is a separate acceptance gate.** At the audit, [run 42600623873](https://github.com/SoumyajitXD/Zepholume-Shaders/actions/runs/42600623873) was in progress and [run 42596047328](https://github.com/SoumyajitXD/Zepholume-Shaders/actions/runs/42596047328) had failed. Check [current Actions status](https://github.com/SoumyajitXD/Zepholume-Shaders/actions) instead of assuming a prior or partial run makes `main` green.

## Automated checks

The CI workflow is in `.github/workflows/ci.yml` and runs on pushes to
`main`, pull requests, manual dispatch and a weekly schedule. Its final
`Required checks` job fails if any required dependency fails or is skipped.

The workflow tests:
- workflow security using pinned actions, least-privilege permissions,
  `actionlint`, and pinned `zizmor` static analysis
- structural and mathematical shader regressions on Linux
- profile parser behavior with LF, CRLF, and UTF-8 BOM, including negative tests
- Windows source/profile/benchmark validation
- static mock-loader and GPU-*label* portability coverage
- Khronos glslang compilation and program linking, with warnings treated as errors
- full coverage of the expected preprocessed profile/dimension/loader combinations
- deterministic same-runner ZIP builds and independent Linux/Windows ZIP builds
- **required** equality of ZIP member paths and uncompressed member SHA-256
- **advisory** cross-runner ZIP byte-hash equality (compressors can differ)
- report artifacts for portability, standalone GLSL, coverage, packages and parity

The GPU identity labels in the mocked portability matrix **do not** simulate
Intel, AMD or NVIDIA drivers. Nor do glslang passes establish Iris/Oculus
loader-patched compilation, working profile UI, Minecraft rendering or FPS.

Do not make compatibility claims based solely on these checks.

## Historical V1.0.6 hosted status (2026-10-28)

**The V1.0.6 main-branch GitHub Actions runs observed at that date were failing.** Do not describe the branch as green because local final-source validation or individual hosted jobs passed.

- [Run 40680015526](https://github.com/SoumyajitXD/Zepholume-Shaders/actions/runs/40680015526) on commit `b4f101d`: **Full regression tests FAILED**, because the clean-tree guard detected modifications to tracked files after running tests. The required aggregate also failed.
- The observed tracked modifications were `Zepholume-Shaders/bench/run-manifest-template.json`, `Zepholume-Shaders/bench/v103-control.json` and `Zepholume-Shaders/docs/BENCHMARK_PROTOCOL.md`. This is a test side-effect/source-isolation defect, **not** evidence of a GLSL compilation failure in this run.
- In that run, workflow policy, GLSL compiler validation, mocked portability, Windows smoke, deterministic packaging, independent Windows packaging and cross-runner package contents **passed**.
- This documentation update intentionally does **not** alter the protected `Zepholume-Shaders/` source or weaken the clean-tree check. The fixture/test code must be repaired in a separately authorised change, and a complete new hosted workflow run must pass before claiming CI green.

Final V1.0.6 packaging is separately documented in the [release report](../Zepholume-Shaders/docs/V1.0.6_FINAL_RELEASE.md). That report's offline pass and final archive export do not establish in-game qualification or passing hosted CI.

## Release evidence verification

The manual `.github/workflows/release-qualification.yml` workflow invokes
`Zepholume-Shaders/scripts/ci/verify_runtime_evidence.py`.
It **never publishes or approves a release**.

The operator provides a full candidate commit SHA and a sanitized JSON manifest
beneath `qualification-evidence/`. The manifest must name an existing ZIP
under `Releases/` with the exact SHA-256 digest. For the staged Minecraft
1.20.1 baseline it must contain two lanes: Fabric/Iris and Forge/Oculus,
with exact versions, Java 17, GPU model, GPU driver and a real capture timestamp.

Each lane must include checked files for:
- a loader `latest-log`
- captured `patched-glsl` source
- `frame-times` raw CSV (must expose a `frameTimeMs` column)
- PNG `screenshot` entries for each of the five quality profiles in
  Overworld, Nether and End (15 captures per loader lane)

Schema example (deliberately incomplete):

```json
{
  "schemaVersion": 1,
  "candidateCommit": "40-hex-digit-full-Git-commit",
  "package": {
    "path": "Releases/candidate.zip",
    "sha256": "64-hex-digit-SHA-256"
  },
  "lanes": [
    {
      "minecraftVersion": "1.20.1",
      "modLoader": "Fabric",
      "shaderLoader": "Iris",
      "shaderLoaderVersion": "1.7.6",
      "rendererVersion": "Sodium 0.5.13",
      "javaMajor": 17,
      "gpuModel": "Actual GPU hardware",
      "gpuDriver": "Actual driver version",
      "testDateUtc": "2026-10-23T12:00:00Z",
      "artifacts": [
        {
          "kind": "latest-log",
          "path": "qualification-evidence/sanitized-latest.log",
          "sha256": "64-hex-digit-SHA-256"
        },
        {
          "kind": "patched-glsl",
          "path": "qualification-evidence/captured-patched.glsl",
          "sha256": "64-hex-digit-SHA-256"
        },
        {
          "kind": "frame-times",
          "path": "qualification-evidence/actual-frame-times.csv",
          "sha256": "64-hex-digit-SHA-256"
        },
        {
          "kind": "screenshot",
          "profile": "Balanced",
          "dimension": "Overworld",
          "path": "qualification-evidence/balanced-overworld.png",
          "sha256": "64-hex-digit-SHA-256"
        }
      ]
    }
  ]
}
```

Hashes prove **file integrity relative to declarations**, not capture
authenticity or correct rendering. Review the real patched GLSL and loader
logs, profile UI, lighting, fog, clouds, water, translucency and matched
screenshots manually. Performance comparisons must follow the controlled
A/A and A/B protocol in
`Zepholume-Shaders/docs/BENCHMARK_PROTOCOL.md`.
Sanitize logs and never commit account credentials, player identities, IPs,
private saves or raw confidential data to the public repository.

**FULL MULTI-LOADER/VENDOR QUALIFICATION: NOT ESTABLISHED.** This remains distinct from V1.0.7's completed local export. This manual integrity checker is *not* a hosted Minecraft launcher or graphics-driver validation system.

## GitHub repository settings

Configure a ruleset protecting `main` and requiring the stable
`Required checks` status in Settings → Rules → Rulesets. A YAML file cannot
configure those settings by itself. Direct pushes should be restricted once
the current deployment policy permits that change.

## Minimum acceptance before claiming upgraded CI works

Run the entire hosted workflow on the exact source commit, then deliberately
inject mutations in separate test branches: broken GLSL source; missing
logical variant; malformed profile with CRLF; invalid ZIP content; and
missing or tampered release evidence. Verify each targeted job fails as
intended. Preserve run URLs, commit SHA and generated artifacts as proof.
