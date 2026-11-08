#ifndef ZEPHO_FRAGMENT_GLSL
#define ZEPHO_FRAGMENT_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"

#ifndef ZEPH_UNTEXTURED_PROGRAM
uniform sampler2D texture;
varying vec2 zephTexCoord;
#endif
#ifdef ZEPH_LIGHTMAP_LIT_PROGRAM
// The loader binds Minecraft's per-surface block/sky lighting here.  Keep it
// separate from the albedo atlas: zephLightCoord is not illumination by itself.
uniform sampler2D lightmap;
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
#if !defined(ZEPH_HAND_PROGRAM) && (ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY > 0 || ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0 || (defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER > 0 && ZEPH_EFFECTIVE_WATER_QUALITY > 0))
varying vec3 zephNormalView;
#endif
varying vec3 zephViewDirection;
#ifdef ZEPH_WATER_PROGRAM
#if ZEPH_EFFECTIVE_WATER_TIER > 0 && ZEPH_EFFECTIVE_WATER_QUALITY > 0
flat varying float zephIsWater;
#endif
#if ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
flat varying float zephTranslucentMaterial;
#endif
#endif

// These helpers reference the fog uniforms above, which GLSL 330 requires to
// be declared before the function bodies are parsed.
#include "/lib/fog.glsl"
#if ZEPH_EFFECTIVE_UNDERWATER_QUALITY > 0
#include "/lib/underwater.glsl"
#endif
#define ZEPH_HAS_RAIN_STRENGTH
#define ZEPH_HAS_SUN_POSITION
#define ZEPH_HAS_MOON_POSITION
#include "/lib/water.glsl"
#include "/lib/color.glsl"
#include "/lib/lighting.glsl"
#include "/lib/materials.glsl"
#if defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
#include "/lib/translucent_material.glsl"
#endif
#include "/lib/weather.glsl"
#undef ZEPH_HAS_RAIN_STRENGTH
#undef ZEPH_HAS_SUN_POSITION
#undef ZEPH_HAS_MOON_POSITION

void main() {
    // Length is nonlinear: derive distance from the interpolated position,
    // rather than interpolating corner lengths across a triangle diagonal.
    float zephDistance = length(zephViewDirection);
#ifdef ZEPH_UNTEXTURED_PROGRAM
    vec4 source = zephVertexColour;
#else
    vec4 source = texture2D(texture, zephTexCoord) * zephVertexColour;
#endif
#ifdef ZEPH_LIGHTMAP_LIT_PROGRAM
    // The lightmap is the authoritative per-surface irradiance.  Earlier
    // versions transported zephLightCoord only for artistic modifiers and
    // never applied this texture, which made zero-light cave surfaces retain
    // nearly full albedo.  Apply it before display-to-working-space decoding
    // so the existing colour pipeline receives the game's lit colour.
    source.rgb *= texture2D(lightmap, zephLightCoord).rgb;
#endif
#if !defined(ZEPH_HAND_PROGRAM) && (ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY > 0 || ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0 || (defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER > 0 && ZEPH_EFFECTIVE_WATER_QUALITY > 0))
    // Do not normalize a normal on profiles/programs that have no consumer.
    // This makes Potato's direct scene path genuinely omit that source-level
    // analytical work instead of relying on later compiler elimination.
    vec3 normal = zephSafeNormalize(zephNormalView);
#endif
    vec3 graded;
#ifdef ZEPH_HAND_PROGRAM
    // Hands have no reliable world normal here, but share the same sampled
    // lightmap, block-light warmth and display grade as the surrounding scene.
    // Avoid inventing a sun-facing response from a first-person normal.
    vec3 handLinear = zephDecodeDisplay(source.rgb);
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY > 0
#if !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
    float handDaylight = zephDaylightFromSun();
#else
    float handDaylight = 0.0;
#endif
    handLinear = zephBlockLightWarmth(handLinear, zephLightCoord, handDaylight, rainStrength);
#endif
    graded = zephGradeLinearScene(handLinear);
#else
#if defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER > 0 && ZEPH_EFFECTIVE_WATER_QUALITY > 0
    // Keep the water result in working space.  This removes the former
    // encode/decode round trip (a sqrt plus its inverse square) from every
    // active water fragment while preserving the same bounded surface value.
    // The program also carries non-water translucent terrain; keep that on
    // the ordinary scene route instead of applying water Fresnel/specular.
    vec3 linear = zephIsWater > 0.5
        ? zephWaterSurfaceLinear(source.rgb, normal, zephViewDirection, zephDistance, zephSkyExposure(zephLightCoord.y))
        : zephDecodeDisplay(source.rgb);
#else
    vec3 linear = zephDecodeDisplay(source.rgb);
#endif
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY > 0
    linear = zephApplySceneLighting(linear, normal, zephLightCoord, rainStrength);
#endif
#if ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
    linear = zephMaterialResponse(linear, normal, zephDistance, zephViewDirection, zephLightCoord);
#endif
#if defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
    linear = zephTranslucentResponse(linear, normal, zephViewDirection, zephTranslucentMaterial);
#endif
#ifdef ZEPH_WEATHER_PROGRAM
    linear = zephWeatherResponse(linear);
#endif
    graded = zephGradeLinearScene(linear);
#endif
#ifndef ZEPH_NO_FOG
#if ZEPH_EFFECTIVE_UNDERWATER_QUALITY > 0
    if (isEyeInWater == 1) {
        graded = zephUnderwater(graded, zephDistance, zephLightCoord);
    } else
#endif
    {
    // The Potato atmosphere factor ignores elevation entirely. Keep the
    // varying, because distance is still needed for the loader fog range.
#if ZEPH_EFFECTIVE_ATMOSPHERE_QUALITY == 0
    float fogFactor = zephFogFactor(zephDistance, 0.0);
#else
    float fogFactor = zephFogFactor(zephDistance, zephWorldElevation(zephViewDirection));
#endif
    // Zero factor is common before the fog start: the mix is exactly the
    // original colour, so avoid evaluating the atmosphere palette there.
    if (fogFactor > 0.0) {
        // Fog and sky use camera-to-scene rays; the shared varying points
        // from the surface to the camera for water and material lighting.
        graded = mix(graded, zephFogColour(-zephViewDirection), fogFactor);
    }
    }
#endif
    gl_FragData[0] = vec4(graded, clamp(source.a, 0.0, 1.0));
}
#endif
