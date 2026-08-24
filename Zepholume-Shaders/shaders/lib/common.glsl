#ifndef ZEPHO_COMMON_GLSL
#define ZEPHO_COMMON_GLSL
float zephSaturate(float v) { return clamp(v, 0.0, 1.0); }
vec3 zephSaturate(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }

// GLSL normalize(0) is undefined. Modded geometry can carry an empty normal,
// so use a bounded denominator everywhere a direction is only approximate.
vec3 zephSafeNormalize(vec3 v) {
    return v * inversesqrt(max(dot(v, v), 0.00000001));
}

float zephDaylightFromElevation(float elevation) {
    return smoothstep(-0.16, 0.18, elevation);
}

float zephTwilightFromElevation(float elevation) {
    return 1.0 - smoothstep(0.06, 0.34, abs(elevation));
}

// sunPosition is loader supplied and has a stable direction, unlike the
// historical fixed-scale approximation. Keeping this in one helper makes
// terrain, sky, clouds and fog transition through day/night together.
float zephDaylightFromDirection(vec3 lightDirection) {
    float invLen = inversesqrt(max(dot(lightDirection, lightDirection), 0.00000001));
    return zephDaylightFromElevation(lightDirection.y * invLen);
}

float zephTwilightFromDirection(vec3 lightDirection) {
    float invLen = inversesqrt(max(dot(lightDirection, lightDirection), 0.00000001));
    return zephTwilightFromElevation(lightDirection.y * invLen);
}
#endif
