#ifndef ZEPHO_COMMON_GLSL
#define ZEPHO_COMMON_GLSL
float zephSaturate(float v) { return clamp(v, 0.0, 1.0); }
vec3 zephSaturate(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }
#endif
