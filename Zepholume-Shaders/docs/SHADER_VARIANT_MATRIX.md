# Shader variant matrix

The generated offline corpus is `artifacts/portability-matrix/`. It expands all includes for every program stage under 252 mocked cases: seven vendor/renderer identities, three loader identities, two profiles, three dimensions, and two capability descriptions. Vendor macros are test inputs, not hardware tests; the pack contains no vendor-specific branch.

| Item | Value |
| --- | --- |
| Programs | 24 pairs / 48 stages |
| Profiles | Ultra Lite, Balanced |
| Dimensions | Overworld, Nether, End |
| Loader macro sets | Iris-compatible, conservative Oculus-compatible, unknown fallback |
| Vendor sets | NVIDIA GeForce, NVIDIA Quadro, AMD Radeon, Intel, Mesa Radeon, Mesa Intel, unknown |
| Capability sets | OpenGL 3.3 GLSL 330 with no optional extensions; higher capability while retaining GLSL 330 |
| Include depth | At most 3 currently; validator limit 8 |

Expansion records source completeness and inputs only. It does not execute Iris/Oculus patching or prove driver compilation.
