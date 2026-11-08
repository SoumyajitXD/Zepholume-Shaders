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
#include "/lib/atmosphere.glsl"

varying vec2 zephCloudTexCoord;
varying vec4 zephCloudVertexColour;
varying vec3 zephCloudViewPosition;
#if ZEPH_EFFECTIVE_CLOUD_QUALITY > 0 && ZEPH_EFFECTIVE_CLOUD_TIER >= 1
varying float zephCloudNormalUp;
#if ZEPH_EFFECTIVE_CLOUD_TIER == 1
varying vec2 zephCloudSolar;
#endif
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 2
varying float zephCloudSunFacing;
#endif
#endif

#if ZEPH_EFFECTIVE_CLOUD_QUALITY > 0 && ZEPH_EFFECTIVE_CLOUD_TIER >= 2
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
#if ZEPH_EFFECTIVE_FOG_QUALITY == 1
    float density = 0.76 + 0.24 * rainStrength;
    // Weather changes interior density, never the full-fog endpoint.
    return linear * (density + (1.0 - density) * linear);
#else
    return linear;
#endif
}

void main() {
    vec4 source = texture2D(texture, zephCloudTexCoord) * zephCloudVertexColour;
#if ZEPH_EFFECTIVE_CLOUD_QUALITY == 0
    vec3 cloud = source.rgb;
#else
#if ZEPH_EFFECTIVE_CLOUD_TIER == 1
    float day = zephCloudSolar.x;
#else
    vec3 sunDir = zephSafeNormalize(sunPosition);
    float solarElevation = zephWorldElevation(sunDir);
    float day = zephDaylightFromElevation(solarElevation);
#endif
    float weather = clamp(rainStrength, 0.0, 1.0);
    // Separate moonlit and overcast palettes before applying facet lighting.
    vec3 nightTint = vec3(0.28, 0.32, 0.42);
    vec3 cloud = mix(source.rgb * nightTint, source.rgb, day);
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 1
#if ZEPH_EFFECTIVE_CLOUD_TIER == 1
    float sunLift = zephCloudSolar.y;
#else
    float sunLift = clamp(solarElevation * 0.5 + 0.5, 0.0, 1.0);
#endif
    // Preserve the block mesh silhouette while giving its vertical faces and
    // lower surface distinct body. Storm light is diffuse, so contrast fades.
    float underside = mix(0.62, 1.04, zephCloudNormalUp);
    cloud *= mix(underside, 1.0, weather * 0.32 + sunLift * 0.25);
    // Storm bases become cooler and darker, with less contrast near the top.
    float stormBase = weather * (1.0 - zephCloudNormalUp);
    cloud *= mix(vec3(1.0), vec3(0.78, 0.82, 0.90), stormBase * 0.55);
#endif
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 2
    float twilight = zephClearTwilight(solarElevation, weather);
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
    float detailField = zephCloudBlocks(zephCloudTexCoord * 28.0 + vec2(11.3, 4.7));
    shelf = smoothstep(0.47, 0.66, cloudField * 0.72 + detailField * 0.28);
#endif
    // Layered ambient occlusion and a lit top edge provide a bounded relief
    // cue. These are not physical shadows or additional geometry.
    float bodyShade = mix(0.77, 1.08, shelf);
    cloud *= mix(bodyShade, 1.0, weather * 0.25);
    cloud *= mix(0.87, 1.06, zephCloudSunFacing * (1.0 - weather));
#endif
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 3
    // A bounded forward-scattering cue suggests a brighter cloud edge facing
    // the sun. The view vector is safe even at the camera origin. Night uses
    // the opposite direction as a subtle moonward cue; storms suppress both.
    vec3 viewDir = zephSafeNormalize(zephCloudViewPosition);
    float sunward = max(dot(viewDir, sunDir), 0.0);
    float moonward = max(-dot(viewDir, sunDir), 0.0);
    float forwardSun = sunward * sunward;
    forwardSun *= forwardSun;
    float forwardMoon = moonward * moonward;
    forwardMoon *= forwardMoon;
    float clearLight = 1.0 - weather;
    cloud += source.rgb * zephCloudNormalUp * clearLight *
        (vec3(0.14, 0.11, 0.08) * forwardSun * day +
         vec3(0.025, 0.032, 0.048) * forwardMoon * (1.0 - day));
    // Thin sun-facing regions catch light; night uses a much smaller cool
    // rim, while weather continuously suppresses both.
    float thinEdge = (1.0 - coverage) * clearLight;
    cloud += source.rgb * thinEdge * zephCloudNormalUp *
             (vec3(0.10, 0.075, 0.05) * forwardSun * day +
              vec3(0.012, 0.016, 0.025) * forwardMoon * (1.0 - day));
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
    float cloudFog = zephCloudFogFactor(length(zephCloudViewPosition));
#if ZEPH_EFFECTIVE_CLOUD_QUALITY > 0 && !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
    // Match the surface fog's day/night and weather palette at the distant
    // endpoint. No local skylight or invented visibility is available here.
    vec3 cloudHaze = zephAtmosphereColour(fogColor, day, weather);
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 1
#if ZEPH_EFFECTIVE_CLOUD_TIER == 1
    float hazeElevation = zephCloudSolar.y * 2.0 - 1.0;
#else
    float hazeElevation = solarElevation;
#endif
    cloudHaze = zephHazeTint(cloudHaze, vec3(0.82, 0.48, 0.32),
                             zephClearTwilight(hazeElevation, weather) * 0.10);
#endif
    cloud = mix(cloud, cloudHaze, cloudFog);
#else
    cloud = mix(cloud, fogColor, cloudFog);
#endif
#if ZEPH_EFFECTIVE_CLOUD_QUALITY > 0 && ZEPH_EFFECTIVE_CLOUD_TIER >= 3
    // Gently soften distant mesh edges; retain alpha and never create geometry.
    source.a *= 1.0 - 0.20 * cloudFog * cloudFog;
#endif
    gl_FragData[0] = vec4(clamp(cloud, 0.0, 1.0), clamp(source.a, 0.0, 1.0));
}
#endif
