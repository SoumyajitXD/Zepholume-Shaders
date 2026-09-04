#ifndef ZEPHO_FOG_GLSL
#define ZEPHO_FOG_GLSL
#include "/lib/atmosphere.glsl"

vec3 zephFogColour(vec3 viewDir) {
#if ZEPH_EFFECTIVE_PROFILE_TIER == 0
    // Potato deliberately retains the loader-provided water/biome fog exactly.
    if (isEyeInWater == 1) return fogColor;
#else
    if (isEyeInWater == 1) {
        // This is a bounded, distance-fog-driven absorption tint, not a
        // Beer-Lambert simulation.  It keeps the loader's biome/water fog as
        // the anchor, gently reduces long-distance warm transmission, and
        // avoids an independently fluorescent blue water colour.
        vec3 absorbed = fogColor * vec3(0.76, 0.96, 0.93);
#if ZEPH_EFFECTIVE_PROFILE_TIER == 1
        float absorption = 0.20;
#elif ZEPH_EFFECTIVE_PROFILE_TIER == 2
        float absorption = 0.30;
#elif ZEPH_EFFECTIVE_PROFILE_TIER == 3
        float absorption = 0.36;
#else
        float absorption = 0.42;
#endif
        // Night vision restores part of the loader fog colour, preserving
        // readable underwater caves without a special brightness path.
        return mix(absorbed, fogColor, zephSaturate(nightVision) * 0.45) * absorption + fogColor * (1.0 - absorption);
    }
#endif
#ifdef ZEPH_DIM_NETHER
    return mix(fogColor, vec3(0.30, 0.070, 0.028), 0.22);
#elif defined(ZEPH_DIM_END)
    return mix(fogColor, vec3(0.090, 0.070, 0.145), 0.15);
#else
    vec3 sunDir = zephSafeNormalize(sunPosition);
    float daylight = zephDaylightFromElevation(sunDir.y);
    float twilight = zephTwilightFromElevation(sunDir.y);
    float storm = zephSaturate(rainStrength);
    vec3 haze = zephAtmosphereColour(fogColor, daylight, storm);
    // Low-order horizon warmth connects fog to the sky without replacing
    // biome/loader fog colour or producing a hard sunset band.
    haze = mix(haze, vec3(0.78, 0.48, 0.34), twilight * (1.0 - storm) * 0.10);
    return haze;
#endif
}

vec3 zephFogColour() {
    return zephFogColour(vec3(0.0, 0.0, 1.0));
}

float zephFogFactor(float d, float viewDirectionY) {
    float factor = zephAtmosphereFactor(d, viewDirectionY, rainStrength);
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 1
    if (isEyeInWater == 1) {
        // Reuse the existing monotonic fog distance rather than add exp/pow.
        // The small tiered multiplier only affects the already-active water
        // fog path and remains clamped at the loader fog endpoint.
#if ZEPH_EFFECTIVE_PROFILE_TIER == 1
        factor *= 1.02;
#elif ZEPH_EFFECTIVE_PROFILE_TIER == 2
        factor *= 1.06;
#elif ZEPH_EFFECTIVE_PROFILE_TIER == 3
        factor *= 1.09;
#else
        factor *= 1.12;
#endif
    }
#endif
    return zephSaturate(factor);
}
#endif
