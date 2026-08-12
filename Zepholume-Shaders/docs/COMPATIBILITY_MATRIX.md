# Compatibility report

## Actual evidence

| Environment | Version | Result |
|---|---|---|
| Iris/Fabric/Sodium | Minecraft 1.20.1, Iris 1.7.6, Sodium 0.5.13 | Isolated directory, Java 17, package hash, and ZIP-root checks pass; no launch/compile/render test |
| Oculus/Forge/Embeddium | Minecraft 1.20.1, Forge 47.4.22, Oculus 1.8.0, Embeddium 0.3.31 | Isolated directory, Java 17, package hash, and ZIP-root checks pass; no launch/compile/render test |
| Intel UHD 730 | Driver 32.0.101.7080 | Hardware discovered only; no runtime test |
| NVIDIA / AMD | — | Not tested |
| Minecraft 26.1.2 | Local launcher folders only | No Zepholume evidence; not supported by this release |

All 210 unique source-expanded GLSL stages compile with the local standalone `glslangValidator` tool. The generated matrix covers five profiles plus the Ultra Lite alias, three dimensions, two loader macro models, and mocked vendor/capability identities. That is source/preprocessor validation only: it cannot establish patched-loader compilation, driver behaviour, or cross-vendor rendering.

## Runtime gate

Before claiming loader compatibility, manually launch the isolated candidate, select the 0.2.0 ZIP, test every profile, repeat shader/resource reload and world/dimension transition, and collect `latest.log`, patched shaders, screenshots, and frame-time captures. See `MANUAL_RUNTIME_TEST.md` and `VISUAL_REGRESSION.md`.
