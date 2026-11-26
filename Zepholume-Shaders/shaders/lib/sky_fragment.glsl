#ifndef ZEPHO_SKY_FRAGMENT_GLSL
#define ZEPHO_SKY_FRAGMENT_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"

uniform sampler2D texture;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float rainStrength;
uniform int isEyeInWater;
uniform int renderStage;
#include "/lib/atmosphere.glsl"

varying vec2 zephSkyTexCoord;
varying vec4 zephSkyVertexColour;
varying vec3 zephSkyViewPosition;

vec3 zephWeatherSky(vec3 colour, float storm) {
    float luma = dot(colour, vec3(0.2126, 0.7152, 0.0722));
    // Cloud cover removes chroma and directs the sky towards the loader fog.
    // Scaling the fog contribution by sky luminance avoids an additive glow
    // when the loader reports a bright fog during an otherwise dark sky.
    vec3 overcast = mix(vec3(luma) * vec3(0.91, 0.96, 1.02), fogColor * luma, 0.22);
    return mix(colour, overcast, zephSaturate(storm) * 0.56);
}

#if !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
#if !defined(ZEPH_SKY_TEXTURED) && ZEPH_EFFECTIVE_PROFILE_TIER > 0
vec3 zephAnalyticSky(float elevation, float sunDot, vec3 haze, float daylight,
                     float clearTwilight, float storm) {
    // Angular layers rather than a single interpolated gradient: an optically
    // thick horizon, a broad mid-sky, and a deeper zenith. Loader colours
    // retain biome identity; the horizon meets the same fog anchor as terrain.
    float altitude = max(elevation, 0.0);
    float horizonLayer = 1.0 - smoothstep(0.0, 0.38, altitude);
    float zenithLayer = smoothstep(0.08, 0.95, altitude);
    vec3 dayZenith = mix(skyColor * vec3(0.55, 0.72, 1.02), vec3(0.18, 0.34, 0.63), 0.28);
    vec3 dayMiddle = mix(skyColor, vec3(0.38, 0.57, 0.78), 0.28);
    vec3 dayHorizon = mix(skyColor, haze, 0.86);
    vec3 nightZenith = vec3(0.009, 0.016, 0.039);
    vec3 nightMiddle = vec3(0.025, 0.037, 0.075);
    vec3 nightHorizon = mix(vec3(0.040, 0.052, 0.078), haze * 0.35, 0.35);
    vec3 middle = mix(nightMiddle, dayMiddle, daylight);
    vec3 atmosphere = mix(middle, mix(nightZenith, dayZenith, daylight), zenithLayer);
    atmosphere = mix(atmosphere, mix(nightHorizon, dayHorizon, daylight), horizonLayer);

    // The height envelope fixes twilight to the horizon while the view-sun
    // dot selects its direction, without normalizing two horizontal vectors.
    float sunward = zephSaturate(sunDot * 0.5 + 0.5);
    float warmBand = horizonLayer * sunward * sunward;
    vec3 warmHorizon = mix(haze, vec3(0.74, 0.42, 0.28), 0.53);
    atmosphere = mix(atmosphere, warmHorizon, clearTwilight * warmBand * 0.52);
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 2
    // A cool anti-solar twilight arch above a muted rose horizon creates a
    // separate transition on the opposite side of the sky.
    float opposite = 1.0 - sunward;
    float arch = smoothstep(0.02, 0.16, altitude) * (1.0 - smoothstep(0.28, 0.65, altitude));
    atmosphere = mix(atmosphere, vec3(0.22, 0.25, 0.34), clearTwilight * arch * opposite * opposite * 0.25);
    atmosphere = mix(atmosphere, vec3(0.42, 0.30, 0.33), clearTwilight * horizonLayer * opposite * opposite * 0.14);
#endif
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 3
    float forward = max(sunDot, 0.0);
    float forwardLobe = forward * forward;
    forwardLobe *= forwardLobe;
    atmosphere = mix(atmosphere, dayHorizon, forwardLobe * daylight * (1.0 - storm) * 0.14);
#endif
    return zephWeatherSky(atmosphere, storm);
}
#endif
#endif

void main() {
#ifdef ZEPH_SKY_TEXTURED
    vec4 source = texture2D(texture, zephSkyTexCoord) * zephSkyVertexColour;
#else
    vec4 source = zephSkyVertexColour;
#endif
    vec3 result = source.rgb;
#if !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END) && ZEPH_EFFECTIVE_PROFILE_TIER > 0
    float storm = zephSaturate(rainStrength);
#ifdef ZEPH_SKY_TEXTURED
    // Textured bodies retain their vanilla sprite for compatibility; the
    // background pass supplies a circular, direction-derived halo instead of
    // enlarging the square source texture.
    result = zephWeatherSky(source.rgb, storm);
#else
    vec3 worldUp = zephWorldUpView();
    vec3 sunDir = zephSafeNormalize(sunPosition);
    float sunElevation = dot(sunDir, worldUp);
    float daylight = zephDaylightFromElevation(sunElevation);
#if defined(MC_RENDER_STAGE_STARS)
    if (renderStage == MC_RENDER_STAGE_STARS) {
        result = source.rgb * mix(0.22, 0.92, (1.0 - daylight) * (1.0 - storm));
    } else
#endif
#if defined(MC_RENDER_STAGE_VOID)
    if (renderStage == MC_RENDER_STAGE_VOID) {
        result = min(source.rgb, mix(source.rgb, fogColor * 0.28, 0.32));
    } else
#endif
    {
        vec3 skyDir = zephSafeNormalize(zephSkyViewPosition);
        float elevation = dot(skyDir, worldUp);
        float sunDot = clamp(dot(skyDir, sunDir), -1.0, 1.0);
        float clearTwilight = zephClearTwilight(sunElevation, storm);
        vec3 haze = isEyeInWater == 0
            ? zephOpenAirHaze(fogColor, daylight, storm, clearTwilight, elevation, sunDot)
            : fogColor;
        vec3 analytic = zephAnalyticSky(elevation, sunDot, haze, daylight, clearTwilight, storm);
        // Below the horizon transition back into the loader's lower sky.
        float analyticWeight = 0.72 * smoothstep(-0.23, 0.0, elevation);
        result = mix(source.rgb, analytic, analyticWeight);
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 2
        if (isEyeInWater == 0 && elevation >= 0.0) {
            vec3 moonDir = zephSafeNormalize(moonPosition);
            float sunLight = zephSolarIllumination(sunElevation, storm);
            float moonLight = zephLunarIllumination(sunElevation, dot(moonDir, worldUp), storm);
            float sunHalo = smoothstep(0.90, 0.998, sunDot);
            float moonHalo = smoothstep(0.965, 0.998, dot(skyDir, moonDir));
            vec3 halo = vec3(0.26, 0.19, 0.10) * (sunHalo * sunHalo * sunLight) +
                        vec3(0.065, 0.09, 0.14) * (moonHalo * moonHalo * moonLight);
            // The loader still draws the celestial discs. Roll off the halo
            // against available headroom before it can clip bright sky.
            result += (vec3(1.0) - zephSaturate(result)) * halo;
        }
#endif
        // The sky, cloud fog, and surface fog meet at the same endpoint.
        result = mix(haze, result, smoothstep(0.0, 0.16, abs(elevation)));
    }
#endif
#endif
    gl_FragData[0] = vec4(clamp(result, 0.0, 1.0), clamp(source.a, 0.0, 1.0));
}
#endif
