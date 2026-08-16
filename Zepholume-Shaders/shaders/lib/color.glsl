#ifndef ZEPHO_COLOR_GLSL
#define ZEPHO_COLOR_GLSL
#include "/lib/colour_space.glsl"

float zephExposureMultiplier() {
#if ZEPH_EFFECTIVE_EXPOSURE == 0
    return 0.88;
#elif ZEPH_EFFECTIVE_EXPOSURE == 2
    return 1.10;
#else
    return 1.0;
#endif
}

float zephContrastMultiplier() {
#if ZEPH_EFFECTIVE_CONTRAST == 0
    return 0.96;
#elif ZEPH_EFFECTIVE_CONTRAST == 2
    return 1.08;
#else
    return 1.02;
#endif
}

float zephSaturationMultiplier() {
#if ZEPH_EFFECTIVE_SATURATION == 0
    return 0.92;
#elif ZEPH_EFFECTIVE_SATURATION == 2
    return 1.05;
#else
    return 0.98;
#endif
}

vec3 zephDimensionTone(vec3 colour) {
#ifdef ZEPH_DIM_NETHER
    // Preserve Nether emissive readability without applying an Overworld
    // sunset grade to every surface.
    return colour * vec3(1.025, 0.980, 0.945);
#elif defined(ZEPH_DIM_END)
    // The End stays sparse and cool, with deliberately restrained chroma.
    return colour * vec3(0.965, 0.970, 1.020);
#else
    return colour;
#endif
}

vec3 zephGradeLinearScene(vec3 linear) {
    linear = zephDimensionTone(linear);
    linear *= zephExposureMultiplier();
    linear = zephApplyContrast(linear, zephContrastMultiplier());
    linear = zephApplySaturation(linear, zephSaturationMultiplier());
    // Neutral-to-warm balance counters the old uniform cyan-blue bias without
    // turning the pack into a global dimmer.
#if ZEPH_EFFECTIVE_COLOUR_TEMPERATURE == 0
    linear *= vec3(0.99, 1.00, 1.025);
#elif ZEPH_EFFECTIVE_COLOUR_TEMPERATURE == 2
    linear *= vec3(1.025, 1.00, 0.965);
#else
    linear *= vec3(1.015, 1.0, 0.985);
#endif
    return zephEncodeDisplay(zephHighlightCompress(linear));
}

vec3 zephGradeScene(vec3 displayColour) {
    return zephGradeLinearScene(zephDecodeDisplay(displayColour));
}

vec3 zephGradeHand(vec3 displayColour) {
    vec3 linear = zephDecodeDisplay(displayColour);
    linear = zephApplySaturation(linear, 0.90);
    return zephEncodeDisplay(zephHighlightCompress(linear));
}
#endif
