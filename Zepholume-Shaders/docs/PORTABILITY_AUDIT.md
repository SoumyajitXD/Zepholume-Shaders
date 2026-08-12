# Portability audit

## GLSL 330 and interfaces

All 48 stages declare `#version 330 compatibility`; validation rejects extensions, post-330 image/atomic/gather/barrier features, precision qualifiers, extra colour attachments, invalid pair interfaces, and unsupported stage files. Every fragment path writes `gl_FragData[0]` with explicit alpha. Vertex paths assign all shared varyings on every path.

## Numerical and preprocessing audit

Fog denominators are bounded by `start + 1.0`; sky elevation bounds vector length before division; colour, alpha, interpolation factors, and weather inputs are clamped. There are no fragment loops, normalizations, inverse trigonometry, logarithms, powers, or fragment trigonometry. All shared include files have guards; validation rejects include cycles and depth over 8.

## Vendor and loader considerations

| Area | Confirmed defect | Preventive generic fix | Vendor workaround | Untested assumption |
| --- | --- | --- | --- | --- |
| NVIDIA | None | Standards-correct GLSL 330, one common path | None | Final runtime compile/render |
| AMD | None | Defined arithmetic and explicit interfaces | None | Final runtime compile/render |
| Intel | None | Bounded divisions and predictable preprocessing | None | Final runtime compile/render |
| Mesa | None | No assumption that Mesa equals AMD hardware | None | Final runtime compile/render |
| Iris patcher | None | Guards, shallow includes, no required Iris macros | None | Final patch/compile |
| Oculus | None | Conservative fallback when stage macros are absent | None | Final patch/compile |

No vendor macros occur in shader source. Mocked macro cases are only preprocessor corpus inputs. Runtime testing remains required for all vendors and loaders.
