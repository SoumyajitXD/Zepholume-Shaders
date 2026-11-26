#ifndef ZEPHO_CLOUD_FRAGMENT_GLSL
#define ZEPHO_CLOUD_FRAGMENT_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"
uniform sampler2D texture;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int isEyeInWater;
#include "/lib/atmosphere.glsl"

varying vec2 zephCloudTexCoord;
varying vec4 zephCloudVertexColour;
varying vec3 zephCloudViewPosition;
#if !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END) && ZEPH_EFFECTIVE_CLOUD_QUALITY > 0 && ZEPH_EFFECTIVE_CLOUD_TIER >= 1
varying float zephCloudNormalUp;
#if ZEPH_EFFECTIVE_CLOUD_TIER == 1
varying vec2 zephCloudSolar;
#endif
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 2
varying float zephCloudSunFacing;
#endif
#endif

#if !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END) && ZEPH_EFFECTIVE_CLOUD_QUALITY > 0 && ZEPH_EFFECTIVE_CLOUD_TIER >= 2
// The field travels with the loader's cloud UVs. It can cut shapes from the
// supplied mesh but cannot draw beyond it or create actual cloud volume.
float zephCloudCell(vec2 cell) {
    vec3 p = fract(vec3(cell.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float zephCloudBlocks(vec2 position) {
    vec2 cell = floor(position);
    vec2 local = fract(position);
    // Flat cell interiors and narrow soft joins retain an orthogonal outline.
    vec2 blend = smoothstep(vec2(0.38), vec2(0.62), local);
    float a = mix(zephCloudCell(cell), zephCloudCell(cell + vec2(1.0, 0.0)), blend.x);
    float b = mix(zephCloudCell(cell + vec2(0.0, 1.0)), zephCloudCell(cell + vec2(1.0)), blend.x);
    return mix(a, b, blend.y);
}
#endif

float zephCloudFogFactor(float distance) {
    float range = fogEnd - fogStart;
    if (range <= 0.0) return distance >= fogStart ? 1.0 : 0.0;
    float linear = clamp((distance - fogStart) / range, 0.0, 1.0);
#if ZEPH_EFFECTIVE_FOG_QUALITY == 1 && !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
    if (isEyeInWater != 0) return linear;
    float density = 0.76 + 0.24 * zephSaturate(rainStrength);
    // Weather changes interior density, never the full-fog endpoint.
    return linear * (density + (1.0 - density) * linear);
#else
    return linear;
#endif
}

void main() {
    vec4 source = texture2D(texture, zephCloudTexCoord) * zephCloudVertexColour;
    float distance = length(zephCloudViewPosition);
#if ZEPH_EFFECTIVE_CLOUD_QUALITY == 0 || defined(ZEPH_DIM_NETHER) || defined(ZEPH_DIM_END)
    vec3 cloud = source.rgb;
#else
#if ZEPH_EFFECTIVE_CLOUD_TIER == 1
    float day = zephCloudSolar.x;
    float solarElevation = zephCloudSolar.y;
#else
    vec3 worldUp = zephWorldUpView();
    vec3 sunDir = zephSafeNormalize(sunPosition);
    float solarElevation = dot(sunDir, worldUp);
    float day = zephDaylightFromElevation(solarElevation);
#endif
    float weather = zephSaturate(rainStrength);
    float twilight = zephClearTwilight(solarElevation, weather);
    // Separate moonlit and overcast palettes before applying facet lighting.
    vec3 nightTint = vec3(0.28, 0.32, 0.42);
    vec3 cloud = mix(source.rgb * nightTint, source.rgb, day);
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 1
    float sunLift = clamp(solarElevation * 0.5 + 0.5, 0.0, 1.0);
    // Preserve the block mesh silhouette while giving its vertical faces and
    // lower surface distinct body. Storm light is diffuse, so contrast fades.
    float underside = mix(0.62, 1.04, zephCloudNormalUp);
    cloud *= mix(underside, 1.0, weather * 0.32 + sunLift * 0.25);
    // Storm bases become cooler and darker, with less contrast near the top.
    float stormBase = weather * (1.0 - zephCloudNormalUp);
    cloud *= mix(vec3(1.0), vec3(0.78, 0.82, 0.90), stormBase * 0.55);
#endif
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 2
    // Light existing facets without new samples or a fragment normal.
    // Neutral at night and in storms; clear daylight reveals the relief.
    float clearSky = 1.0 - weather;
    cloud *= 1.0 + (zephCloudSunFacing - 0.5) * 0.16 * day * clearSky;
    // Sun-facing facets catch warm twilight while shaded facets stay cooler.
    float twilightLight = twilight;
    float warmFace = mix(zephCloudSunFacing, 1.0, zephCloudNormalUp * 0.35);
    vec3 twilightTint = mix(vec3(0.93, 0.92, 1.03), vec3(1.22, 0.94, 0.78), warmFace);
    cloud = mix(cloud, cloud * twilightTint, twilightLight * 0.65);

    // A broad block field cuts openings and reshapes the supplied silhouette.
    // The second, higher-frequency field creates raised-looking shelves. Both
    // are texture anchored, so no independent animation or temporal hash can
    // drift across the vanilla mesh. Rain progressively fills the openings.
    float cloudField = zephCloudBlocks(zephCloudTexCoord * 12.0);
    float threshold = mix(0.48, 0.29, weather);
    float edgeWidth = clamp(fwidth(cloudField) * 0.8, 0.035, 0.16);
    float coverage = smoothstep(threshold - edgeWidth, threshold + edgeWidth, cloudField);
    source.a *= mix(0.08, 1.0, coverage);
    float shelf = smoothstep(0.48, 0.65, cloudField);
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 3
    vec2 detailCoord = zephCloudTexCoord * 28.0 + vec2(11.3, 4.7);
    vec2 footprint = fwidth(detailCoord);
    float detailWeight = 1.0 - smoothstep(0.23, 0.65, max(footprint.x, footprint.y));
    // Fine shelves no longer contribute once their narrow transitions are
    // below a pixel. Compute derivatives before the conditional lookup.
    if (detailWeight > 0.0) {
        float detailField = zephCloudBlocks(detailCoord);
        float detailShelf = smoothstep(0.47, 0.66, mix(cloudField, detailField, 0.28));
        shelf = mix(shelf, detailShelf, detailWeight);
    }
#endif
    // Layered ambient occlusion and a lit top edge provide a bounded relief
    // cue. These are not physical shadows or additional geometry.
    float bodyShade = mix(0.77, 1.08, shelf);
    cloud *= mix(bodyShade, 1.0, weather * 0.25);
    cloud *= mix(0.87, 1.06, zephCloudSunFacing * (1.0 - weather));
#endif
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 3
    // Reuse the distance already needed for fog instead of taking a second
    // inverse length. Zero and near-zero rays retain the safe-normalize bound.
    vec3 viewDir = zephCloudViewPosition / max(distance, 0.0001);
    float viewSunDot = dot(viewDir, sunDir);
    vec3 moonDir = zephSafeNormalize(moonPosition);
    float sunward = max(viewSunDot, 0.0);
    float moonward = max(dot(viewDir, moonDir), 0.0);
    float forwardSun = sunward * sunward;
    forwardSun *= forwardSun;
    float forwardMoon = moonward * moonward;
    forwardMoon *= forwardMoon;
    float sunLight = zephSolarIllumination(solarElevation, weather) * (1.0 - weather);
    float moonLight = zephLunarIllumination(solarElevation, dot(moonDir, worldUp), weather) * (1.0 - weather);
    // Thin sun-facing regions catch light. The weaker lunar rim uses the
    // loader's actual moon, and neither body lights the mesh below the horizon.
    float thinEdge = 1.0 - coverage;
    vec3 sunRim = vec3(0.14, 0.11, 0.08) + thinEdge * vec3(0.10, 0.075, 0.05);
    vec3 moonRim = vec3(0.025, 0.032, 0.048) + thinEdge * vec3(0.012, 0.016, 0.025);
    cloud += source.rgb * zephCloudNormalUp * (sunRim * (forwardSun * sunLight) +
                                              moonRim * (forwardMoon * moonLight));
#endif
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 4
    // Reuse the already interpolated coverage field for restrained relief.
    // This avoids two additional fragment sine evaluations in Ultra; the
    // relief now follows coverage instead of an independent periodic pattern.
    float relief = 1.0 + 0.14 * (cloudField - 0.5) *
                         (0.35 + 0.65 * zephCloudNormalUp);
    cloud *= relief;
#endif
    cloud = mix(cloud, vec3(dot(cloud, vec3(0.2126, 0.7152, 0.0722))) * vec3(0.66, 0.69, 0.73), weather * 0.44);
#endif
    float cloudFog = zephCloudFogFactor(distance);
#if ZEPH_EFFECTIVE_CLOUD_QUALITY > 0 && !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
    if (cloudFog > 0.0) {
        vec3 haze = fogColor;
        if (isEyeInWater == 0) {
            float elevation = 0.0;
            float sunDot = 0.0;
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 2
            if (twilight > 0.0) {
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 3
                elevation = dot(viewDir, worldUp);
                sunDot = viewSunDot;
#else
                vec3 hazeDirection = zephCloudViewPosition / max(distance, 0.0001);
#if ZEPH_EFFECTIVE_CLOUD_TIER == 1
                elevation = dot(hazeDirection, zephWorldUpView());
                sunDot = dot(hazeDirection, zephSafeNormalize(sunPosition));
#else
                elevation = dot(hazeDirection, worldUp);
                sunDot = dot(hazeDirection, sunDir);
#endif
#endif
            }
#endif
            haze = zephOpenAirHaze(fogColor, day, weather, twilight, elevation, sunDot);
        }
        cloud = mix(cloud, haze, cloudFog);
    }
#else
    cloud = mix(cloud, fogColor, cloudFog);
#endif
#if !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END) && ZEPH_EFFECTIVE_CLOUD_QUALITY > 0 && ZEPH_EFFECTIVE_CLOUD_TIER >= 3
    // Gently soften distant mesh edges; retain alpha and never create geometry.
    source.a *= 1.0 - 0.20 * cloudFog * cloudFog;
#endif
    gl_FragData[0] = vec4(clamp(cloud, 0.0, 1.0), clamp(source.a, 0.0, 1.0));
}
#endif
