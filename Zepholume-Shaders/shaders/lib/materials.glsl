#ifndef ZEPHO_MATERIALS_GLSL
#define ZEPHO_MATERIALS_GLSL

vec3 zephMaterialResponse(vec3 linearColour, vec3 normalView, float distance) {
#if ZEPH_EFFECTIVE_MATERIAL_QUALITY == 0
    return linearColour;
#else
    float upward = clamp(normalize(normalView).y * 0.5 + 0.5, 0.0, 1.0);
    float distanceFade = 1.0 - zephSaturate(distance / max(fogEnd, 1.0));
    // Subtle orientation response separates horizontal snow/ground from walls
    // without guessing texture identities or adding a texture lookup.
    return linearColour * mix(0.94, 1.035, upward * distanceFade);
#endif
}

#endif
