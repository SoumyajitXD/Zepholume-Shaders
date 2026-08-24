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

varying vec2 zephCloudTexCoord;
varying vec4 zephCloudVertexColour;
varying float zephCloudDistance;
varying float zephCloudNormalUp;

float zephCloudFogFactor(float distance) {
    float start = max(fogStart, 1.0);
    float end = max(fogEnd, start + 1.0);
    float linear = clamp((distance - start) / (end - start), 0.0, 1.0);
#if ZEPH_EFFECTIVE_FOG_QUALITY == 1
    return linear * (0.76 + 0.24 * rainStrength);
#else
    return linear;
#endif
}

void main() {
    vec4 source = texture2D(texture, zephCloudTexCoord) * zephCloudVertexColour;
    vec3 sunDir = zephSafeNormalize(sunPosition);
    float day = zephDaylightFromElevation(sunDir.y);
    float weather = clamp(rainStrength, 0.0, 1.0);
    vec3 nightTint = vec3(0.28, 0.32, 0.42);
#if ZEPH_EFFECTIVE_CLOUD_QUALITY == 0
    vec3 cloud = source.rgb;
#else
    vec3 cloud = mix(source.rgb * nightTint, source.rgb, day);
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 1
    float sunLift = clamp(sunDir.y * 0.5 + 0.5, 0.0, 1.0);
    float underside = mix(0.68, 1.0, zephCloudNormalUp);
    cloud *= mix(underside, 1.0, sunLift * 0.58);
#endif
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 2
    float twilight = zephTwilightFromElevation(sunDir.y);
    cloud = mix(cloud, cloud * vec3(1.08, 0.88, 0.74), twilight * (1.0 - zephCloudNormalUp) * (1.0 - weather) * 0.20);
#endif
    cloud = mix(cloud, vec3(dot(cloud, vec3(0.2126, 0.7152, 0.0722))) * vec3(0.66, 0.69, 0.73), weather * 0.44);
#endif
    cloud = mix(cloud, fogColor, zephCloudFogFactor(zephCloudDistance));
    gl_FragData[0] = vec4(clamp(cloud, 0.0, 1.0), clamp(source.a, 0.0, 1.0));
}
#endif
