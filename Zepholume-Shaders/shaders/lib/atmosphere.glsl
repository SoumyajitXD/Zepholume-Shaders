#ifndef ZEPHO_ATMOSPHERE_GLSL
#define ZEPHO_ATMOSPHERE_GLSL

vec3 zephAtmosphereColour(vec3 baseFog, float daylight, float storm) {
    vec3 dayHaze = mix(baseFog, vec3(0.72, 0.78, 0.82), 0.16);
    vec3 nightHaze = mix(baseFog, vec3(0.055, 0.070, 0.105), 0.42);
    vec3 haze = mix(nightHaze, dayHaze, daylight);
    return mix(haze, vec3(dot(haze, vec3(0.2126, 0.7152, 0.0722))) * vec3(0.76, 0.79, 0.82), storm * 0.35);
}

float zephAtmosphereFactor(float distance, float viewDirectionY, float rain) {
    float start = max(fogStart, 1.0);
    float end = max(fogEnd, start + 1.0);
    float linear = zephSaturate((distance - start) / (end - start));
#if ZEPH_EFFECTIVE_ATMOSPHERE_QUALITY == 0
    return linear;
#else
    float curved = linear * linear * (3.0 - 2.0 * linear);
    float horizonFactor = 1.0 - abs(viewDirectionY) * 0.18;
    return zephSaturate(curved * horizonFactor * (0.84 + rain * 0.28));
#endif
}

#endif
