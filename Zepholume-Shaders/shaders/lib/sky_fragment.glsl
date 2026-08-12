#ifndef ZEPHO_SKY_FRAGMENT_GLSL
#define ZEPHO_SKY_FRAGMENT_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"
#include "/lib/colour_space.glsl"

uniform sampler2D texture;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float rainStrength;
uniform float thunderStrength;
uniform int renderStage;

varying vec2 zephSkyTexCoord;
varying vec4 zephSkyVertexColour;
varying float zephSkyUp;
varying vec3 zephSkyDirection;

float zephSkyDaylight() {
    return clamp(normalize(sunPosition).y * 0.70 + 0.46, 0.0, 1.0);
}

vec3 zephWeatherSky(vec3 colour, float storm) {
    float luma = dot(colour, vec3(0.2126, 0.7152, 0.0722));
    return mix(colour, mix(vec3(luma), fogColor, 0.34), storm * 0.48);
}

vec3 zephAnalyticSky(float up, vec3 direction, float daylight, float storm) {
    vec3 zenithDay = vec3(0.28, 0.48, 0.72);
    vec3 horizonDay = vec3(0.72, 0.76, 0.77);
    vec3 zenithNight = vec3(0.018, 0.029, 0.065);
    vec3 horizonNight = vec3(0.075, 0.090, 0.130);
    float horizonMix = smoothstep(0.06, 0.84, up);
    vec3 atmosphere = mix(mix(horizonNight, zenithNight, horizonMix), mix(horizonDay, zenithDay, horizonMix), daylight);
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 1
    float dawn = (1.0 - abs(normalize(sunPosition).y)) * smoothstep(0.04, 0.62, daylight);
    float sunSide = zephSaturate(dot(normalize(direction), normalize(sunPosition)) * 0.5 + 0.5);
    atmosphere = mix(atmosphere, vec3(0.94, 0.49, 0.25), dawn * (1.0 - horizonMix) * sunSide * 0.42);
#endif
    return zephWeatherSky(atmosphere, storm);
}

vec3 zephCelestialGlow(vec3 direction, float daylight, float storm) {
#if ZEPH_EFFECTIVE_PROFILE_TIER == 0
    return vec3(0.0);
#else
    float sunDot = zephSaturate(dot(normalize(direction), normalize(sunPosition)));
    float sunCore = smoothstep(0.9975, 0.9995, sunDot);
    float sunHalo = smoothstep(0.90, 0.998, sunDot);
    sunHalo *= sunHalo;
    float moonDot = zephSaturate(dot(normalize(direction), normalize(moonPosition)));
    float moonHalo = smoothstep(0.965, 0.998, moonDot);
    moonHalo *= moonHalo;
    vec3 sun = vec3(1.0, 0.76, 0.42) * (sunCore * 0.75 + sunHalo * 0.22) * daylight;
    vec3 moon = vec3(0.42, 0.53, 0.72) * moonHalo * (1.0 - daylight) * 0.42;
    return (sun + moon) * (1.0 - storm * 0.75);
#endif
}

void main() {
#ifdef ZEPH_SKY_TEXTURED
    vec4 source = texture2D(texture, zephSkyTexCoord) * zephSkyVertexColour;
#else
    vec4 source = zephSkyVertexColour;
#endif
    float storm = clamp(max(rainStrength, thunderStrength), 0.0, 1.0);
    float daylight = zephSkyDaylight();
    vec3 analytic = zephAnalyticSky(zephSkyUp, zephSkyDirection, daylight, storm);
    vec3 result;

#ifdef ZEPH_SKY_TEXTURED
    // Textured bodies retain their vanilla sprite for compatibility; the
    // background pass supplies a circular, direction-derived halo instead of
    // enlarging the square source texture.
    result = zephWeatherSky(source.rgb, storm);
#else
    result = mix(source.rgb, analytic, 0.72);
    result += zephCelestialGlow(zephSkyDirection, daylight, storm);
#endif

#if defined(MC_RENDER_STAGE_STARS)
    if (renderStage == MC_RENDER_STAGE_STARS) {
        result = source.rgb * mix(0.22, 0.92, (1.0 - daylight) * (1.0 - storm));
    }
#endif
#if defined(MC_RENDER_STAGE_VOID)
    if (renderStage == MC_RENDER_STAGE_VOID) {
        result = min(result, mix(result, fogColor * 0.28, 0.32));
    }
#endif
    gl_FragData[0] = vec4(clamp(result, 0.0, 1.0), clamp(source.a, 0.0, 1.0));
}
#endif
