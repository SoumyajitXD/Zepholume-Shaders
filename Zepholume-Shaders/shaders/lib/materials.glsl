#ifndef ZEPHO_MATERIALS_GLSL
#define ZEPHO_MATERIALS_GLSL

#ifndef ZEPH_HAS_SUN_POSITION
uniform vec3 sunPosition;
#endif

vec3 zephMaterialResponse(vec3 linearColour, vec3 normal, float distance, vec3 viewDir, vec2 lightCoord) {
#if ZEPH_EFFECTIVE_MATERIAL_QUALITY == 0
    return linearColour;
#else
    float upward = clamp(normal.y * 0.5 + 0.5, 0.0, 1.0);
    float distanceFade = 1.0 - zephSaturate(distance / max(fogEnd, 1.0));
    // Subtle orientation and soft wrap separates horizontal ground/foliage from walls
    // without guessing texture identities or adding expensive lookups.
    float slopeShaping = mix(0.95, 1.04, upward * distanceFade);
    vec3 result = linearColour * slopeShaping;
    return result;
#endif
}

vec3 zephMaterialResponse(vec3 linearColour, vec3 normal, float distance) {
    return zephMaterialResponse(linearColour, normal, distance, vec3(0.0), vec2(0.0));
}

#endif
