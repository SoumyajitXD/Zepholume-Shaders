# Unresolved loader issues

- Minecraft 26.2 exposes an experimental Vulkan backend. Zepholume has no Iris/Vulkan compile or render evidence, so testing must use Prefer OpenGL until that changes.
- No Iris-patched or Oculus-patched Zepholume source has been captured. Standalone `glslangValidator` is deliberately not a substitute.
- Modern Iris is the primary compatibility research lane. Classic Oculus is a legacy 1.20/1.20.1 lane; community Forge ports require separate exact-version qualification.
- No runtime test covers shader reload, all profiles, all dimensions, water/transparency, or Intel/NVIDIA/AMD/Mesa rendering.
- No controlled frame-time benchmark exists. The source-level optimization in this pass is not an FPS or frame-pacing result.
