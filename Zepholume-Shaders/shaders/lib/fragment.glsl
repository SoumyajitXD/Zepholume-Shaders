#ifndef ZEPHO_FRAGMENT_GLSL
#define ZEPHO_FRAGMENT_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"

#ifndef ZEPH_UNTEXTURED_PROGRAM
uniform sampler2D texture;
varying vec2 zephTexCoord;
#endif
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
// isEyeInWater and nightVision are legacy shader-pack uniforms supported by
// the Iris/OptiFine compatibility surface; neither is Iris-exclusive.
uniform int isEyeInWater;
uniform float nightVision;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
varying vec2 zephLightCoord;
varying vec4 zephVertexColour;
varying float zephDistance;
varying vec3 zephNormalView;
varying vec3 zephViewDirection;

// These helpers reference the fog uniforms above, which GLSL 330 requires to
// be declared before the function bodies are parsed.
#include "/lib/fog.glsl"
#define ZEPH_HAS_RAIN_STRENGTH
#define ZEPH_HAS_SUN_POSITION
#define ZEPH_HAS_MOON_POSITION
#include "/lib/water.glsl"
#include "/lib/color.glsl"
#include "/lib/lighting.glsl"
#undef ZEPH_HAS_RAIN_STRENGTH
#undef ZEPH_HAS_SUN_POSITION
#undef ZEPH_HAS_MOON_POSITION
#include "/lib/materials.glsl"
#include "/lib/weather.glsl"

void main() {
#ifdef ZEPH_UNTEXTURED_PROGRAM
    vec4 source = zephVertexColour;
#else
    vec4 source = texture2D(texture, zephTexCoord) * zephVertexColour;
#endif
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY > 0 || ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0 || (defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER > 0 && ZEPH_EFFECTIVE_WATER_QUALITY > 0)
    // Do not normalize a normal on profiles/programs that have no consumer.
    // This makes Potato's direct scene path genuinely omit that source-level
    // analytical work instead of relying on later compiler elimination.
    vec3 normal = zephSafeNormalize(zephNormalView);
#endif
#if defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER > 0 && ZEPH_EFFECTIVE_WATER_QUALITY > 0
    source.rgb = zephWaterSurface(source.rgb, normal, zephViewDirection, zephDistance);
#endif
    vec3 graded;
#ifdef ZEPH_HAND_PROGRAM
    graded = zephGradeHand(source.rgb);
#else
    vec3 linear = zephDecodeDisplay(source.rgb);
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY > 0
    linear = zephApplySceneLighting(linear, normal, zephLightCoord, rainStrength);
#endif
#if ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
    linear = zephMaterialResponse(linear, normal, zephDistance);
#endif
#ifdef ZEPH_WEATHER_PROGRAM
    linear = zephWeatherResponse(linear);
#endif
    graded = zephGradeLinearScene(linear);
#endif
#ifndef ZEPH_NO_FOG
    graded = mix(graded, zephFogColour(), zephFogFactor(zephDistance, zephViewDirection.y));
#endif
    gl_FragData[0] = vec4(graded, clamp(source.a, 0.0, 1.0));
}
#endif
