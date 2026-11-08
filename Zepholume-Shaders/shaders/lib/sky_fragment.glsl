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
uniform int renderStage;

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
vec3 zephAnalyticSky(float up, vec3 direction, vec3 sunDir, float daylight, float twilight, float storm) {
    // Angular layers rather than a single interpolated gradient: an optically
    // thick horizon, a broad mid-sky, and a deeper zenith. Loader colours
    // retain biome identity; the horizon meets the same fog anchor as terrain.
    float altitude = zephSaturate((up - 0.5) * 2.0);
    float horizonLayer = 1.0 - smoothstep(0.0, 0.38, altitude);
    float zenithLayer = smoothstep(0.08, 0.95, altitude);
    vec3 dayZenith = mix(skyColor * vec3(0.55, 0.72, 1.02), vec3(0.18, 0.34, 0.63), 0.28);
    vec3 dayMiddle = mix(skyColor, vec3(0.38, 0.57, 0.78), 0.28);
    vec3 dayHorizon = mix(skyColor, fogColor, 0.86);
    vec3 nightZenith = vec3(0.009, 0.016, 0.039);
    vec3 nightMiddle = vec3(0.025, 0.037, 0.075);
    vec3 nightHorizon = mix(vec3(0.045, 0.057, 0.090), fogColor * 0.35, 0.35);
    vec3 middle = mix(nightMiddle, dayMiddle, daylight);
    vec3 atmosphere = mix(middle, mix(nightZenith, dayZenith, daylight), zenithLayer);
    atmosphere = mix(atmosphere, mix(nightHorizon, dayHorizon, daylight), horizonLayer);

    // Azimuth and elevation are separated so the warm band remains at the
    // horizon as the sun moves, instead of following a circular spot upward.
    vec3 worldUp = zephWorldUpView();
    vec3 viewHorizontal = direction - worldUp * dot(direction, worldUp);
    vec3 sunHorizontal = sunDir - worldUp * dot(sunDir, worldUp);
    float azimuth = dot(zephSafeNormalize(viewHorizontal), zephSafeNormalize(sunHorizontal));
    float sunward = zephSaturate(azimuth * 0.5 + 0.5);
    float clearTwilight = twilight * (1.0 - zephSaturate(storm));
    float warmBand = horizonLayer * sunward * sunward;
    vec3 warmHorizon = mix(fogColor, vec3(0.88, 0.45, 0.30), 0.62);
    atmosphere = mix(atmosphere, warmHorizon, clearTwilight * warmBand * 0.58);
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 2
    // A cool anti-solar twilight arch above a muted rose horizon creates a
    // separate transition on the opposite side of the sky.
    float opposite = 1.0 - sunward;
    float arch = smoothstep(0.02, 0.16, altitude) * (1.0 - smoothstep(0.28, 0.65, altitude));
    atmosphere = mix(atmosphere, vec3(0.22, 0.25, 0.37), clearTwilight * arch * opposite * opposite * 0.30);
    atmosphere = mix(atmosphere, vec3(0.53, 0.34, 0.38), clearTwilight * horizonLayer * opposite * opposite * 0.18);
#endif
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 3
    float forward = zephSaturate(dot(direction, sunDir));
    float haze = forward * forward;
    haze *= haze;
    atmosphere = mix(atmosphere, dayHorizon, haze * daylight * (1.0 - storm) * 0.14);
#endif
    return zephWeatherSky(atmosphere, storm);
}
#endif

#if !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
vec3 zephCelestialGlow(vec3 direction, vec3 sunDir, vec3 moonDir, float daylight, float storm) {
#if ZEPH_EFFECTIVE_PROFILE_TIER == 0
    return vec3(0.0);
#else
    float sunDot = zephSaturate(dot(direction, sunDir));
    float sunCore = smoothstep(0.9975, 0.9995, sunDot);
    float sunHalo = smoothstep(0.90, 0.998, sunDot);
    sunHalo *= sunHalo;
    float moonDot = zephSaturate(dot(direction, moonDir));
    float moonHalo = smoothstep(0.965, 0.998, moonDot);
    moonHalo *= moonHalo;
    vec3 sun = vec3(1.0, 0.76, 0.42) * (sunCore * 0.75 + sunHalo * 0.22) * daylight;
    vec3 moon = vec3(0.42, 0.53, 0.72) * moonHalo * (1.0 - daylight) * 0.42;
    return (sun + moon) * (1.0 - storm * 0.75);
#endif
}
#endif

void main() {
#ifdef ZEPH_SKY_TEXTURED
    vec4 source = texture2D(texture, zephSkyTexCoord) * zephSkyVertexColour;
#else
    vec4 source = zephSkyVertexColour;
#endif
    float storm = clamp(rainStrength, 0.0, 1.0);
    vec3 sunDir = zephSafeNormalize(sunPosition);
    float sunElevation = dot(sunDir, zephWorldUpView());
    float daylight = zephDaylightFromElevation(sunElevation);
    vec3 result;

#ifdef ZEPH_SKY_TEXTURED
    // Textured bodies retain their vanilla sprite for compatibility; the
    // background pass supplies a circular, direction-derived halo instead of
    // enlarging the square source texture.
    result = zephWeatherSky(source.rgb, storm);
#else
#if ZEPH_EFFECTIVE_PROFILE_TIER == 0
    // Potato deliberately preserves the loader/vanilla sky with no analytic
    // gradients or celestial work beyond the required source path.
    result = source.rgb;
#elif !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
    vec3 moonDir = zephSafeNormalize(moonPosition);
    vec3 skyDir = zephSafeNormalize(zephSkyViewPosition);
    float skyUp = clamp(0.5 + 0.5 * dot(skyDir, zephWorldUpView()), 0.0, 1.0);
    vec3 analytic = zephAnalyticSky(skyUp, skyDir, sunDir, daylight, zephTwilightFromElevation(sunElevation), storm);
    result = mix(source.rgb, analytic, 0.72);
    result += zephCelestialGlow(skyDir, sunDir, moonDir, daylight, storm);
    // Meet the loader's horizon colour at the sky disc edge. Without this,
    // the independently coloured sky and horizon form a visible hard seam.
    float horizonDistance = abs(dot(skyDir, zephWorldUpView()));
    result = mix(fogColor, result, smoothstep(0.0, 0.16, horizonDistance));
#else
    // Nether and End retain the loader-provided sky; their light model is not
    // the Overworld sun/moon analytic path.
    result = source.rgb;
#endif
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
