#ifndef ZEPHO_TRANSLUCENT_MATERIAL_GLSL
#define ZEPHO_TRANSLUCENT_MATERIAL_GLSL

// Call only after the lightmap is applied, in linear working space. IDs are
// flat per primitive: 0 is the unchanged general/water path, 1 glass, 2 ice.
// Multiplicative response preserves darkness and the supplied texture tint;
// no surface light source, sample, opacity change or refraction is invented.
#if ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
vec3 zephTranslucentResponse(vec3 colour, vec3 normal, vec3 viewDirection, float material) {
    if (material < 0.5) return colour;
    vec3 view = zephSafeNormalize(viewDirection);
    float grazing = 1.0 - clamp(abs(dot(normal, view)), 0.0, 1.0);
    grazing *= grazing;
    // Interpolate toward a neutral, lightly coloured edge in proportion to
    // already-lit luminance. No additive source means caves remain dark and
    // arbitrary resource-pack tint remains visible through the face.
    float luminance = dot(max(colour, vec3(0.0)), vec3(0.2126, 0.7152, 0.0722));
    if (material < 1.5) {
        // Keep stained-glass hue at the edge: a small neutral contribution
        // reads as glass without turning strongly coloured panes grey.
        vec3 glassEdge = mix(colour, vec3(luminance), 0.18) * vec3(0.98, 1.00, 1.02);
        return mix(colour, glassEdge, 0.32 * grazing) * (1.0 + 0.06 * grazing);
    }
    // Frosted ice has a cool body and a broader, softer edge than glass.
    // This stays proportional to lighting and leaves alpha untouched.
    vec3 iceBody = colour * vec3(0.96, 1.0, 1.04);
    vec3 iceEdge = mix(colour, vec3(luminance), 0.35) * vec3(0.93, 1.00, 1.09);
    return mix(iceBody, iceEdge, 0.30 * grazing) * (1.0 + 0.08 * grazing);
}
#endif
#endif
