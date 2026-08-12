# GPU compatibility policy

Zepholume targets Minecraft Java 1.20.1 loaders with a `#version 330 compatibility` design baseline. It requires no OpenGL 4.x features, extensions, compute/geometry/tessellation stages, images, SSBOs, bindless resources, half precision, or vendor-specific GLSL.

| Status | Meaning |
| --- | --- |
| Required design baseline | Desktop OpenGL 3.3 and GLSL 330 compatibility available to the selected Minecraft loader. |
| Statically checked | Source structure, include graph, interface matching, forbidden features, profile definitions, and mocked macro expansion. |
| Manually tested | None for this final artifact. |
| Reported by users | None. |
| Untested | NVIDIA, AMD, Intel, Mesa, Iris, and Oculus runtime compilation and rendering of this final artifact. |
| Unsupported | Hardware, drivers, Minecraft/loader combinations, or operating systems that cannot provide the required baseline. |

Vendor and renderer macros are not used for visual policy. They may only support a reproduced, documented driver workaround marked `ZEPH_VENDOR_WORKAROUND`, with issue evidence, affected loader/driver, generic fix analysis, fallback behavior, test requirement, and removal condition.
