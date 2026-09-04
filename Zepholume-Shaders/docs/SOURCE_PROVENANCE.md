# V1.0.3 source provenance

## Boundary & Clean-Room Governance

The local Sildur's Enhanced Default Fast and Fancy packs (`SemiliarShaders/Sildur's Enhanced Default v1.19 Fast` and `Fancy`) are All Rights Reserved and served strictly as read-only conceptual research references during this pass.

**Strict clean-room rule**:
- Zero GLSL source, functions, shaders, assets, lookup tables, color palettes, comments, or directory structures were copied into Zepholume.
- Every architectural and visual technique in Zepholume is an independent derivation grounded in standard computer graphics literature.

## Clean-Room Reference Record

| Reference | Read-only observation | Permitted lesson retained |
|---|---|---|
| Sildur's Enhanced Default v1.19 Fast | Its setting defaults disable several optional effects while retaining a conventional shader-pack program inventory | Use real capability preprocessor gates so low-end/iGPU hardware avoids optional work entirely. |
| Sildur's Enhanced Default v1.19 Fancy | Its setting defaults enable a larger optional feature set (SSAO, TAA, water refractions, godrays, shadow map) | Evaluate visual-return-per-cost before adding any feature; reject multi-pass shadow maps/deferred passes in favor of single-pass ALU ambient depth. |

### Conceptual Analysis of Reference Subsystems

1. **Shadow mapping (investigated and rejected)**:
   - *Standard concept*: render from a light viewpoint, then sample a depth map during shading.
   - *Zepholume decision*: **Rejected for this pack.** It would introduce configurable extra passes, depth storage, sampling, and implementation complexity that conflict with the current direct-path scope. No universal VRAM, bandwidth, or FPS estimate is claimed.
2. **Skylight Occlusion & Cave Light Suppression**:
   - *Problem*: Outdoor celestial directional lighting leaking into underground caves or under building overhangs.
   - *Standard technique*: Lightmap skylight gating.
   - *Zepholume derivation*: Formulated continuous smoothstep transfer curves in `lib/lighting.glsl` modulating celestial direct and ambient terms using `zephLightCoord.y`.
3. **Cross-Generation Fog & Sky Integration**:
   - *Problem*: Fog color seams and horizon mismatch across Minecraft versions and render distances.
   - *Standard technique*: Dual-envelope distance fog blending.
   - *Zepholume derivation*: Aligned bounded analytical sky and horizon fog colour curves with loader-provided fog endpoints. This is a low-order colour and distance blend, not a Mie or phase-function scattering model.

## V1.0.3 change ledger

| Problem | Standard/public concept | Independent Zepholume derivation | Files |
|---|---|---|---|
| Water surface was encoded and then immediately decoded by the ordinary grade route | Colour-space working/display transforms | Keep the water result in Zepholume's existing working space and pass it directly to the existing linear scene grade; zero new sampling, pass, or buffer. | `shaders/lib/water.glsl`, `shaders/lib/fragment.glsl` |
| Block-light warmth and skylight gating need smooth transitions | Hermite interpolation | Use exact `smoothstep`-equivalent Hermite transfers with named compile-time reciprocal ranges, protected by numeric regression tests. No native-GPU performance conclusion follows. | `shaders/lib/lighting.glsl`, `scripts/tests/math-regression.ps1` |
| Water celestial specular needs a continuous day/night transition | Continuous lighting weights | Keep both sun and moon lobes so their pre-existing weighted contribution is preserved. Branch-lowering behaviour is driver-dependent and is not claimed. | `shaders/lib/water.glsl` |
| Building eaves and canopies received full direct sun lighting without shadow maps | Directional skylight occlusion | Attenuated direct celestial penetration with a Hermite skylight gate over `zephLightCoord.y` from 0.04 to 0.65, plus downward-facing facet attenuation, on Balanced, High, and Ultra. | `shaders/lib/lighting.glsl` |
| Flat ambient lighting lacked depth on complex terrain | Dual-hemisphere ambient irradiance | Integrated subtle upward/downward ambient dome modulation (cool sky dome fill on top, warm ground bounce on bottom) on High and Ultra. | `shaders/lib/lighting.glsl` |
| Distance fog and foliage experiments were not reachable through the declared option ranges | Profile compile-out verification | Rejected and removed the unreachable fog-scattering and foliage branches; no visual behaviour is claimed for them. | `shaders/lib/fog.glsl`, `shaders/lib/materials.glsl` |
| Water grazing reflectance lacked sharp dielectric sheen on high-end profiles | Fifth-power Fresnel-shaped artistic curve | Refined High and Ultra (Tier >= 3) to a fifth-power Fresnel-inspired curve; the bounded `0.035..0.46` reflectance range is deliberate artistic tuning, not the physical Fresnel-Schlick equation. | `shaders/lib/water.glsl` |
| Cloud top facets lacked solar rim illumination | Directional rim lighting | Added solar rim highlight term on upward cloud facets on High and Ultra tiers. | `shaders/lib/cloud_fragment.glsl` |
| Cross-version compatibility claims were conflating loader availability with shader validation | Loader/version matrices and backend qualification | Separated static source status, isolated readiness, patched compilation, and rendered-world evidence; designated modern Iris as primary research lane and OpenGL as required backend until Vulkan is qualified. | `docs/COMPATIBILITY_MATRIX.md`, `docs/UNRESOLVED_LOADER_ISSUES.md` |

Review rule: if any implementation resembles a third-party reference more closely than this conceptual record supports, redesign it before keeping it.
