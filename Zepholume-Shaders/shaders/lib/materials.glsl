#ifndef ZEPHO_MATERIALS_GLSL
#define ZEPHO_MATERIALS_GLSL

vec3 zephMaterialResponse(vec3 linearColour, vec3 normal, float distance) {
#if ZEPH_EFFECTIVE_MATERIAL_QUALITY == 0
    return linearColour;
#else
    float upward = clamp(normal.y * 0.5 + 0.5, 0.0, 1.0);
    float distanceFade = 1.0 - zephSaturate(distance / max(fogEnd, 1.0));
    // Subtle orientation and soft wrap separates horizontal ground/foliage from walls
    // without guessing texture identities or adding expensive lookups.
    float slopeShaping = mix(0.95, 1.04, upward * distanceFade);
    return linearColour * slopeShaping;
#endif
}

#endif
