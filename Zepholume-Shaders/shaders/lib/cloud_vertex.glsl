#ifndef ZEPHO_CLOUD_VERTEX_GLSL
#define ZEPHO_CLOUD_VERTEX_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"
varying vec2 zephCloudTexCoord;
varying vec4 zephCloudVertexColour;
varying vec3 zephCloudViewPosition;
#if ZEPH_EFFECTIVE_CLOUD_QUALITY > 0 && ZEPH_EFFECTIVE_CLOUD_TIER >= 1
varying float zephCloudNormalUp;
// Low clouds need only two draw-uniform solar weights. Evaluate them per
// vertex instead of repeating direction normalization across cloud pixels.
#if ZEPH_EFFECTIVE_CLOUD_TIER == 1
uniform vec3 sunPosition;
varying vec2 zephCloudSolar;
#endif
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 2
uniform vec3 sunPosition;
varying float zephCloudSunFacing;
#endif
#endif

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    zephCloudTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    zephCloudVertexColour = gl_Color;
    // Interpolate the affine position; corner lengths are not affine and
    // made the fog amount depend on the cloud mesh's triangle diagonal.
    zephCloudViewPosition = viewPosition.xyz;
#if ZEPH_EFFECTIVE_CLOUD_QUALITY > 0 && ZEPH_EFFECTIVE_CLOUD_TIER >= 1
    vec3 cloudNormal = zephSafeNormalize(gl_NormalMatrix * gl_Normal);
    zephCloudNormalUp = clamp(zephWorldElevation(cloudNormal) * 0.5 + 0.5, 0.0, 1.0);
#if ZEPH_EFFECTIVE_CLOUD_TIER == 1
    // Match the existing bounded double-normalization even for degenerate
    // loader input; this value is uniform across the primitive.
    float solarElevation = zephWorldElevation(zephSafeNormalize(sunPosition));
    zephCloudSolar = vec2(zephDaylightFromElevation(solarElevation),
                          clamp(solarElevation * 0.5 + 0.5, 0.0, 1.0));
#endif
#if ZEPH_EFFECTIVE_CLOUD_TIER >= 2
    // Facet illumination is evaluated per vertex on the existing cloud mesh.
    zephCloudSunFacing = clamp(dot(cloudNormal, zephSafeNormalize(sunPosition)) * 0.5 + 0.5, 0.0, 1.0);
#endif
#endif
    gl_Position = gl_ProjectionMatrix * viewPosition;
}
#endif
