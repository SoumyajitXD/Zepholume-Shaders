#ifndef ZEPHO_ATMOSPHERE_GLSL
#define ZEPHO_ATMOSPHERE_GLSL

// Chroma changes preserve the loader fog's approximate luminance. In
// particular black remains black instead of becoming an artificial light.
vec3 zephHazeTint(vec3 colour, vec3 tint, float weight) {
    vec3 luma = vec3(0.2126, 0.7152, 0.0722);
    vec3 matchedTint = tint * (dot(colour, luma) / max(dot(tint, luma), 0.001));
    return mix(colour, matchedTint, zephSaturate(weight));
}

vec3 zephAtmosphereColour(vec3 baseFog, float daylight, float storm) {
#if ZEPH_EFFECTIVE_PROFILE_TIER == 0
    // Multiplicative colour keeps black fog black without the luminance
    // matching divisions used by the higher tiers.
    vec3 dayHaze = baseFog * vec3(0.97, 1.00, 1.03);
    vec3 nightHaze = baseFog * vec3(0.88, 0.95, 1.08);
#else
    vec3 dayHaze = zephHazeTint(baseFog, vec3(0.72, 0.78, 0.82), 0.16);
    vec3 nightHaze = zephHazeTint(baseFog, vec3(0.055, 0.070, 0.105), 0.42);
#endif
    vec3 haze = mix(nightHaze, dayHaze, daylight);
    return mix(haze, vec3(dot(haze, vec3(0.2126, 0.7152, 0.0722))) * vec3(0.76, 0.79, 0.82), storm * 0.35);
}

float zephAtmosphereFactor(float distance, float viewDirectionY, float rain) {
    float range = fogEnd - fogStart;
    if (range <= 0.0) return distance >= fogStart ? 1.0 : 0.0;
    float linear = zephSaturate((distance - fogStart) / range);
#if ZEPH_EFFECTIVE_ATMOSPHERE_QUALITY == 0
    return linear;
#else
    // Blend a distance-squared clear-air extinction with an earlier smooth
    // overcast veil. Both have exact zero and full-fog endpoints.
    float clearExtinction = linear * linear;
    float overcastExtinction = linear * (2.0 - linear);
    float horizon = 1.0 - zephSaturate(abs(viewDirectionY));
    float weather = zephSaturate(rain);
    float curved = mix(clearExtinction, overcastExtinction, weather * 0.50 + horizon * 0.20);
    float density = 1.0;
    // Shape the interior without weakening the loader's full-fog endpoint.
    // Multiplying the final factor by density left distant geometry visible
    // forever (as little as 0.6888 fog in a clear vertical view).
    return zephSaturate(curved * (density + (1.0 - density) * curved));
#endif
}

#endif
