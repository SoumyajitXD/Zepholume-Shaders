#ifndef ZEPHO_COMMON_GLSL
#define ZEPHO_COMMON_GLSL
// Loader celestial positions and transformed normals are in view space.
// Player-space up must follow the camera before taking an elevation dot.
uniform mat4 gbufferModelView;
float zephSaturate(float v) { return clamp(v, 0.0, 1.0); }
vec3 zephSaturate(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }

// GLSL normalize(0) is undefined. Modded geometry can carry an empty normal,
// so use a bounded denominator everywhere a direction is only approximate.
vec3 zephSafeNormalize(vec3 v) {
    return v * inversesqrt(max(dot(v, v), 0.00000001));
}

vec3 zephWorldUpView() {
    return zephSafeNormalize(gbufferModelView[1].xyz);
}

float zephWorldElevation(vec3 viewDirection) {
    return dot(zephSafeNormalize(viewDirection), zephWorldUpView());
}

float zephDaylightFromElevation(float elevation) {
    return smoothstep(-0.16, 0.18, elevation);
}

float zephTwilightFromElevation(float elevation) {
    return 1.0 - smoothstep(0.06, 0.34, abs(elevation));
}

// Shared bounded controls for all open-air effects. Skylight is exposure,
// not energy: it gates celestial colour and never replaces the lightmap.
float zephClearTwilight(float elevation, float weather) {
    return zephTwilightFromElevation(elevation) * (1.0 - zephSaturate(weather));
}

float zephSkyExposure(float skyLight) {
    float t = zephSaturate((skyLight - 0.04) * 1.639344262295082);
    return t * t * (3.0 - 2.0 * t);
}

// Global celestial strengths are dimensionless [0,1]. Elevations are dot
// products with world-up in view space; weather is rainStrength [0,1]. They
// describe the atmosphere, not visibility at a particular surface. Consumers
// with a lightmap must separately apply zephSkyExposure to celestial effects.
// The sampled lightmap remains authoritative for ambient and block lighting.
float zephSolarIllumination(float sunElevation, float weather) {
#if defined(ZEPH_DIM_NETHER) || defined(ZEPH_DIM_END)
    return 0.0;
#else
    return zephDaylightFromElevation(sunElevation) *
        zephSaturate(sunElevation * 6.0 + 0.1) * (1.0 - 0.85 * zephSaturate(weather));
#endif
}

float zephLunarIllumination(float sunElevation, float moonElevation, float weather) {
#if defined(ZEPH_DIM_NETHER) || defined(ZEPH_DIM_END)
    return 0.0;
#else
    return (1.0 - zephDaylightFromElevation(sunElevation)) *
        zephSaturate(moonElevation * 6.0 + 0.1) * (1.0 - 0.85 * zephSaturate(weather));
#endif
}

// Multiplicative twilight response: no additive illumination in dark places.
vec3 zephTwilightSurfaceTint(float sunFacing) {
    return mix(vec3(0.96, 0.96, 1.035), vec3(1.14, 0.98, 0.84), zephSaturate(sunFacing));
}

// Compare view-space light directions against world up in the same space.
// Camera pitch must not change the world's day/night or twilight weights.
float zephDaylightFromDirection(vec3 lightDirection) {
    return zephDaylightFromElevation(zephWorldElevation(lightDirection));
}

float zephTwilightFromDirection(vec3 lightDirection) {
    return zephTwilightFromElevation(zephWorldElevation(lightDirection));
}
#endif
