#ifndef ZEPHO_MATERIALS_GLSL
#define ZEPHO_MATERIALS_GLSL

#if defined(ZEPH_TERRAIN_PROGRAM) && ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
vec3 zephMaterialResponse(vec3 linearColour, vec3 normal, float distance, vec2 lightCoord, float foliage) {
    float upward = zephSaturate(dot(normal, zephWorldUpView()) * 0.5 + 0.5);
    float proximity = 1.0 - zephSaturate(distance / max(fogEnd, 1.0));
    // Fade the whole orientation response toward identity as fog takes over.
    // Previously the far endpoint was a 5% loss on every surface.
    float slopeShaping = mix(0.96, 1.035, upward);
    vec3 result = linearColour * mix(1.0, slopeShaping, proximity);
#if !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
    if (foliage > 0.5) {
        // Only explicitly mapped leaves and crossed plants receive this soft
        // skylit fill. It wraps toward side and underside faces.
        float skyFill = zephSceneSkyWeight(lightCoord) * proximity * (1.0 - upward);
        result *= mix(vec3(1.0), vec3(1.035, 1.105, 0.975), skyFill);
    }
#endif
    return result;
}
#endif

#endif
