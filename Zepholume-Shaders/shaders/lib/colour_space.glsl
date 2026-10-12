#ifndef ZEPHO_COLOUR_SPACE_GLSL
#define ZEPHO_COLOUR_SPACE_GLSL

// Minecraft's fixed-function inputs are display-referred.  These inexpensive
// approximations give the grading path a stable working space without three
// expensive transfer-function pow calls per fragment.
vec3 zephDecodeDisplay(vec3 colour) {
    return max(colour, vec3(0.0)) * max(colour, vec3(0.0));
}

vec3 zephEncodeDisplay(vec3 colour) {
    return sqrt(max(colour, vec3(0.0)));
}

float zephLuminance(vec3 colour) {
    return dot(colour, vec3(0.2126, 0.7152, 0.0722));
}

vec3 zephHighlightCompress(vec3 colour) {
    // Keep ordinary lightmapped colour unchanged. Only values above display
    // white need a shoulder; compressing the entire 0..1 range darkened terrain
    // while the independently rendered sky stayed bright.
    vec3 positive = max(colour, vec3(0.0));
    return positive / (vec3(1.0) + max(positive - vec3(1.0), vec3(0.0)) * 0.58);
}

vec3 zephApplySaturation(vec3 colour, float amount) {
    return mix(vec3(zephLuminance(colour)), colour, amount);
}

vec3 zephApplyContrast(vec3 colour, float amount) {
    // A pivoted affine contrast clips every valid low-light value below its
    // zero crossing. Scale around the same pivot instead, preserving a smooth
    // positive toe and keeping neutral grey fixed.
    vec3 positive = max(colour, vec3(0.0));
    return positive * (vec3(1.0) + (amount - 1.0) * (clamp(positive, vec3(0.0), vec3(1.0)) - vec3(0.18)));
}

#endif
