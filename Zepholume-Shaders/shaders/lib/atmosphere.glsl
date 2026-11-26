#ifndef ZEPHO_ATMOSPHERE_GLSL
#define ZEPHO_ATMOSPHERE_GLSL

// Chroma changes preserve the loader fog's approximate luminance. In
// particular black remains black instead of becoming an artificial light.
vec3 zephHazeTint(vec3 colour, vec3 tint, float weight) {
    vec3 luma = vec3(0.2126, 0.7152, 0.0722);
    vec3 matchedTint = tint * (dot(colour, luma) / max(dot(tint, luma), 0.001));
    return mix(colour, matchedTint, zephSaturate(weight));
}

#if ZEPH_EFFECTIVE_PROFILE_TIER > 0 && !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
// Shared display-space endpoint for clouds, terrain, and the Overworld sky.
// Palette vectors have unit Rec. 709 luma, so one input dot serves every tint.
vec3 zephOpenAirHaze(vec3 baseFog, float daylight, float storm,
                    float clearTwilight, float elevation, float sunDot) {
    const vec3 lumaWeights = vec3(0.2126, 0.7152, 0.0722);
    const vec3 dayTint = vec3(0.72, 0.78, 0.82) / dot(lumaWeights, vec3(0.72, 0.78, 0.82));
    const vec3 nightTint = vec3(0.055, 0.070, 0.105) / dot(lumaWeights, vec3(0.055, 0.070, 0.105));
    const vec3 warmTint = vec3(0.82, 0.48, 0.32) / dot(lumaWeights, vec3(0.82, 0.48, 0.32));
    float luminance = dot(baseFog, lumaWeights);
    vec3 dayHaze = mix(baseFog, dayTint * luminance, 0.16);
    vec3 nightHaze = mix(baseFog, nightTint * luminance, 0.26);
    vec3 haze = mix(nightHaze, dayHaze, daylight);
    float warmWeight = clearTwilight * 0.08;
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 2
    // A smooth horizon weight keeps the change in slope continuous across
    // the horizon. Signed elevation and ray direction are in world space.
    float horizon = 1.0 - smoothstep(0.0, 0.44, abs(elevation));
    float towardSun = zephSaturate(sunDot * 0.5 + 0.5);
    warmWeight += clearTwilight * horizon * towardSun * towardSun * 0.15;
#endif
    haze = mix(haze, warmTint * luminance, warmWeight);
    return zephSaturate(mix(haze, luminance * vec3(0.76, 0.79, 0.82), storm * 0.35));
}
#endif

float zephAtmosphereFactor(float distance, float viewDirectionY, float rain) {
    float range = fogEnd - fogStart;
    if (range <= 0.0) return distance >= fogStart ? 1.0 : 0.0;
    float linear = zephSaturate((distance - fogStart) / range);
#if ZEPH_EFFECTIVE_ATMOSPHERE_QUALITY == 0 || defined(ZEPH_DIM_NETHER) || defined(ZEPH_DIM_END)
    return linear;
#else
    // Blend a distance-squared clear-air extinction with an earlier smooth
    // overcast veil. Both have exact zero and full-fog endpoints.
    float clearExtinction = linear * linear;
    float overcastExtinction = linear * (2.0 - linear);
    float horizon = 1.0 - zephSaturate(abs(viewDirectionY));
    float weather = zephSaturate(rain);
    return mix(clearExtinction, overcastExtinction, weather * 0.50 + horizon * 0.20);
#endif
}

#endif
