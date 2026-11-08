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
#if ZEPH_EFFECTIVE_PROFILE_TIER == 0
    return fogColor;
#else
    // Preserve the loader's intensity, including black, while suggesting a
    // warmer lower haze and a darker, less saturated ceiling atmosphere.
    float up = zephSaturate(zephWorldElevation(viewDir) * 0.5 + 0.5);
    vec3 netherTint = mix(vec3(0.52, 0.12, 0.035), vec3(0.28, 0.12, 0.11), up);
    return zephHazeTint(fogColor, netherTint, 0.30);
#endif
#elif defined(ZEPH_DIM_END)
#if ZEPH_EFFECTIVE_PROFILE_TIER == 0
    return fogColor;
#else
    float up = zephSaturate(zephWorldElevation(viewDir) * 0.5 + 0.5);
    vec3 endTint = mix(vec3(0.20, 0.16, 0.25), vec3(0.13, 0.16, 0.30), up);
    return zephHazeTint(fogColor, endTint, 0.24);
#endif
#else
    vec3 sunDir = zephSafeNormalize(sunPosition);
    // Both palette weights use the same world-space elevation. Compute it
    // once instead of repeating the normalization and world-up projection.
    vec3 worldUp = zephWorldUpView();
    float sunElevation = dot(sunDir, worldUp);
    float daylight = zephDaylightFromElevation(sunElevation);
    float storm = zephSaturate(rainStrength);
    float clearTwilight = zephClearTwilight(sunElevation, storm);
    vec3 haze = zephAtmosphereColour(fogColor, daylight, storm);
    // Low-order horizon warmth connects fog to the sky without replacing
    // biome/loader fog colour or producing a hard sunset band.
#if ZEPH_EFFECTIVE_PROFILE_TIER == 0
    return haze * mix(vec3(1.0), vec3(1.08, 0.97, 0.91), clearTwilight * 0.10);
#else
    float warmWeight = clearTwilight * 0.10;
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 2
    // The fog palette follows the same broad solar direction as the sky.
    // Restrict the effect near the horizon; looking downward in caves must
    // not acquire a sunset-coloured veil. No extra sample or render target.
    vec3 direction = zephSafeNormalize(viewDir);
    float elevation = abs(dot(direction, worldUp));
    float horizon = 1.0 - zephSaturate(elevation * 2.0);
    float towardSun = zephSaturate(dot(direction, sunDir) * 0.5 + 0.5);
    float warm = clearTwilight * horizon * towardSun * towardSun;
    // Combining two mixes with the same luminance-matched target avoids a
    // second tint evaluation; tinting preserves luminance by construction.
    warmWeight += (1.0 - warmWeight) * warm * 0.10;
#endif
    return zephHazeTint(haze, vec3(0.82, 0.48, 0.32), warmWeight);
#endif
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
