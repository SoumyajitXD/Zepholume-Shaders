#ifndef ZEPHO_FOG_GLSL
#define ZEPHO_FOG_GLSL
#include "/lib/atmosphere.glsl"
vec3 zephFogColour() {
#ifdef ZEPH_DIM_NETHER
    return mix(fogColor, vec3(0.32, 0.075, 0.030), 0.28);
#elif defined(ZEPH_DIM_END)
    return mix(fogColor, vec3(0.10, 0.075, 0.16), 0.18);
#else
    return fogColor;
#endif
}
float zephFogFactor(float d, float viewUp) {
    return zephAtmosphereFactor(d, viewUp, rainStrength);
}
#endif
