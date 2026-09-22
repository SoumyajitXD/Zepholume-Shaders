# Zepholume Shaders 1.0.4

V1.0.4 focuses on internal efficiency, portability, shader-path cleanup, and validation hardening while preserving the direct GLSL 330 compatibility architecture and existing visual design.

- Avoids unnecessary celestial-specular work on water when the relevant light contribution is inactive.
- Retains a single-colour-target path with no shadows, temporal effects, extra buffers, or vendor-specific extensions.
- Uses reproducible, fixed-timestamp packaging and expanded static validation.

No FPS percentage or runtime performance conclusion is claimed. Iris and Oculus live loading, patched-shader inspection, rendered visual coverage, and controlled A/A and A/B benchmarking remain pending runtime qualification.
