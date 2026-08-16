#ifndef ZEPHO_WATER_GLSL
#define ZEPHO_WATER_GLSL

uniform vec3 skyColor;
uniform float frameTimeCounter;
#ifndef ZEPH_HAS_RAIN_STRENGTH
uniform float rainStrength;
#endif

vec4 zephMoveWater(vec4 p) {
#if ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1
    // Two low-amplitude, time-based waves add movement without pretending to
    // know fluid depth or using a second buffer. Frame time is loader-owned.
    float waveTime = frameTimeCounter * 0.65;
    p.y += sin(p.x * 0.10 + p.z * 0.07 + waveTime) * 0.014;
    p.y += cos(p.z * 0.12 - p.x * 0.035 + waveTime * 0.73) * 0.008;
#if ZEPH_EFFECTIVE_WATER_TIER >= 3
    p.y += sin(p.x * 0.035 - p.z * 0.055 + waveTime * 0.41) * 0.006;
#endif
#endif
    return p;
}

vec3 zephWaterDecode(vec3 colour) {
    return max(colour, vec3(0.0)) * max(colour, vec3(0.0));
}

vec3 zephWaterEncode(vec3 colour) {
    return sqrt(max(colour, vec3(0.0)));
}

vec3 zephWaterSurface(vec3 displayColour, vec3 normalView, vec3 viewDirection, float distance) {
#if ZEPH_EFFECTIVE_WATER_TIER == 0 || ZEPH_EFFECTIVE_WATER_QUALITY == 0
    return displayColour;
#else
    vec3 water = zephWaterDecode(displayColour);
    vec3 normal = zephSafeNormalize(normalView);
    float fresnelBase = 1.0 - clamp(dot(normal, zephSafeNormalize(viewDirection)), 0.0, 1.0);
    float fresnel = fresnelBase * fresnelBase;
    vec3 transmission = water * vec3(0.82, 0.98, 0.94);
    transmission = mix(transmission, transmission * vec3(0.75, 0.92, 0.90), clamp(distance * 0.00025, 0.0, 1.0) * 0.18);
    vec3 reflectedSky = zephWaterDecode(skyColor) * vec3(0.80, 0.90, 0.98);
    float storm = clamp(rainStrength, 0.0, 1.0);
    float reflectance = mix(0.08, 0.34, fresnel) * (1.0 - storm * 0.35);
#if ZEPH_EFFECTIVE_WATER_TIER == 1
    reflectance *= 0.55;
#elif ZEPH_EFFECTIVE_WATER_TIER >= 4
    reflectance = min(reflectance * 1.16, 0.52);
#endif
    return zephWaterEncode(mix(transmission, reflectedSky, reflectance));
#endif
}

#endif
