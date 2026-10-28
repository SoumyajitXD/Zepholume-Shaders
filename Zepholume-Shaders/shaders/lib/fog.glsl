#ifndef ZEPHO_FOG_GLSL
#define ZEPHO_FOG_GLSL
#include "/lib/atmosphere.glsl"

vec3 zephFogColour(vec3 viewDir) {
    // Iris/OptiFine define 2 as lava and 3 as powdered snow. These media own
    // their loader-provided fog colour; never recolour them as open air.
    if (isEyeInWater >= 2) return fogColor;
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
    float daylight = zephDaylightFromDirection(sunDir);
    float twilight = zephTwilightFromDirection(sunDir);
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
    if (isEyeInWater >= 1) {
        // A non-positive loader range has no interior. Use a step at its
        // start; positive ranges, however small, retain their exact endpoints.
        float mediumRange = fogEnd - fogStart;
        if (mediumRange <= 0.0) return d >= fogStart ? 1.0 : 0.0;
        float factor = zephSaturate((d - fogStart) / mediumRange);
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 1
        if (isEyeInWater == 1) {
            // Keep underwater fog independent of open-air horizon and weather.
            // Reach the loader fog endpoint even in clear vertical views.
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
    return zephAtmosphereFactor(d, viewDirectionY, rainStrength);
}
#endif
