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
uniform float rainStrength;
uniform vec3 sunPosition;
varying vec4 zephVertexColour;
varying float zephDistance;
varying vec3 zephNormalView;
varying float zephViewUp;
varying vec3 zephViewDirection;

// These helpers reference the fog uniforms above, which GLSL 330 requires to
// be declared before the function bodies are parsed.
#include "/lib/fog.glsl"
#define ZEPH_HAS_RAIN_STRENGTH
#include "/lib/water.glsl"
#undef ZEPH_HAS_RAIN_STRENGTH
#include "/lib/color.glsl"
#include "/lib/lighting.glsl"
#include "/lib/materials.glsl"
#include "/lib/weather.glsl"

void main() {
#ifdef ZEPH_UNTEXTURED_PROGRAM
    vec4 source = zephVertexColour;
#else
    vec4 source = texture2D(texture, zephTexCoord) * zephVertexColour;
#endif
#ifdef ZEPH_WATER_PROGRAM
    source.rgb = zephWaterSurface(source.rgb, zephNormalView, zephViewDirection, zephDistance);
#endif
    vec3 graded;
#ifdef ZEPH_HAND_PROGRAM
    graded = zephGradeHand(source.rgb);
#else
    vec3 linear = zephDecodeDisplay(source.rgb);
    linear = zephApplySceneLighting(linear, zephNormalView);
    linear = zephMaterialResponse(linear, zephNormalView, zephDistance);
#ifdef ZEPH_WEATHER_PROGRAM
    linear = zephWeatherResponse(linear);
#endif
    graded = zephGradeLinearScene(linear);
#endif
#ifndef ZEPH_NO_FOG
    graded = mix(graded, zephFogColour(), zephFogFactor(zephDistance, zephViewUp));
#endif
    gl_FragData[0] = vec4(graded, clamp(source.a, 0.0, 1.0));
}
#endif
