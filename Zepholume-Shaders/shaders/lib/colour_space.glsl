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
    // A rational shoulder preserves bright texture variation instead of hard
    // clipping it; its neutral point is deliberately close to vanilla light.
    return colour / (vec3(1.0) + colour * 0.58);
}

vec3 zephApplySaturation(vec3 colour, float amount) {
    return mix(vec3(zephLuminance(colour)), colour, amount);
}

vec3 zephApplyContrast(vec3 colour, float amount) {
    return max((colour - vec3(0.18)) * amount + vec3(0.18), vec3(0.0));
}

#endif
