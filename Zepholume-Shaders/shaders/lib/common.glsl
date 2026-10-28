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

// Compare view-space light directions against world up in the same space.
// Camera pitch must not change the world's day/night or twilight weights.
float zephDaylightFromDirection(vec3 lightDirection) {
    return zephDaylightFromElevation(zephWorldElevation(lightDirection));
}

float zephTwilightFromDirection(vec3 lightDirection) {
    return zephTwilightFromElevation(zephWorldElevation(lightDirection));
}
#endif
