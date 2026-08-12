#ifndef ZEPHO_LIGHTING_GLSL
#define ZEPHO_LIGHTING_GLSL

uniform vec3 sunPosition;
uniform vec3 moonPosition;

float zephDaylightFromSun() {
    return clamp(sunPosition.y * 0.014 + 0.5, 0.0, 1.0);
}

float zephFaceLight(vec3 normalView) {
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY == 0
    return 1.0;
#else
    vec3 lightDirectionView = normalize(sunPosition);
    float direct = max(dot(normalize(normalView), lightDirectionView), 0.0);
    float halfLambert = direct * 0.72 + 0.28;
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY >= 3
    halfLambert = mix(halfLambert, sqrt(max(halfLambert, 0.0)), 0.22);
#endif
    return mix(0.78, halfLambert, zephDaylightFromSun());
#endif
}

vec3 zephApplySceneLighting(vec3 linearColour, vec3 normalView) {
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY == 0
    return linearColour;
#else
    return linearColour * zephFaceLight(normalView);
#endif
}

#endif
