#ifndef ZEPHO_CLOUD_FRAGMENT_GLSL
#define ZEPHO_CLOUD_FRAGMENT_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"
uniform sampler2D texture;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform float rainStrength;
uniform float thunderStrength;
uniform float sunAngle;
uniform vec3 sunPosition;

varying vec2 zephCloudTexCoord;
varying vec4 zephCloudVertexColour;
varying float zephCloudDistance;
varying float zephCloudNormalUp;

float zephCloudDaylight() {
    return clamp(smoothstep(0.02, 0.25, sunAngle) * (1.0 - smoothstep(0.50, 0.75, sunAngle)), 0.0, 1.0);
}

float zephCloudFogFactor(float distance) {
    float start = max(fogStart, 1.0);
    float end = max(fogEnd, start + 1.0);
#if ZEPH_FOG_QUALITY == 1
    return clamp((distance - start) / (end - start), 0.0, 1.0) * (0.76 + 0.24 * rainStrength);
#else
    return clamp((distance - start) / (end - start), 0.0, 1.0);
#endif
}

void main() {
    vec4 source = texture2D(texture, zephCloudTexCoord) * zephCloudVertexColour;
    float day = zephCloudDaylight();
    float weather = clamp(max(rainStrength, thunderStrength), 0.0, 1.0);
    vec3 nightTint = vec3(0.26, 0.30, 0.38);
    vec3 cloud = mix(source.rgb * nightTint, source.rgb, day);
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 1 && ZEPH_EFFECTIVE_CLOUD_QUALITY == 1
    float sunLift = clamp(normalize(sunPosition).y * 0.5 + 0.5, 0.0, 1.0);
    float underside = mix(0.68, 1.0, zephCloudNormalUp);
    cloud *= mix(underside, 1.0, sunLift * 0.58);
#endif
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 3
    cloud = mix(cloud, cloud * vec3(1.06, 0.94, 0.80), day * (1.0 - zephCloudNormalUp) * 0.12);
#endif
    cloud = mix(cloud, vec3(dot(cloud, vec3(0.2126, 0.7152, 0.0722))) * vec3(0.66, 0.69, 0.73), weather * 0.44);
    cloud = mix(cloud, fogColor, zephCloudFogFactor(zephCloudDistance));
    gl_FragData[0] = vec4(clamp(cloud, 0.0, 1.0), clamp(source.a, 0.0, 1.0));
}
#endif
