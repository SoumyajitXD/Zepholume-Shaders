#ifndef ZEPHO_FOG_GLSL
#define ZEPHO_FOG_GLSL
#include "/lib/atmosphere.glsl"
vec3 zephFogColour() {
#ifdef ZEPH_DIM_NETHER
    return mix(fogColor, vec3(0.30, 0.070, 0.028), 0.22);
#elif defined(ZEPH_DIM_END)
    return mix(fogColor, vec3(0.090, 0.070, 0.145), 0.15);
#else
    float daylight = zephDaylightFromDirection(sunPosition);
    float twilight = zephTwilightFromDirection(sunPosition);
    float storm = zephSaturate(rainStrength);
    vec3 haze = zephAtmosphereColour(fogColor, daylight, storm);
    // A low-order horizon warmth connects fog to the sky without replacing
    // biome/loader fog colour or producing a hard sunset band.
    haze = mix(haze, vec3(0.78, 0.48, 0.34), twilight * (1.0 - storm) * 0.10);
    return haze;
#endif
}
float zephFogFactor(float d, float viewUp) {
    return zephAtmosphereFactor(d, viewUp, rainStrength);
}
#endif
