#ifndef ZEPHO_CLOUD_VERTEX_GLSL
#define ZEPHO_CLOUD_VERTEX_GLSL
#include "/lib/profile.glsl"
varying vec2 zephCloudTexCoord;
varying vec4 zephCloudVertexColour;
varying float zephCloudDistance;
varying float zephCloudNormalUp;

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    zephCloudTexCoord = gl_MultiTexCoord0.st;
    zephCloudVertexColour = gl_Color;
    zephCloudDistance = length(viewPosition.xyz);
    zephCloudNormalUp = clamp((gl_NormalMatrix * gl_Normal).y * 0.5 + 0.5, 0.0, 1.0);
    gl_Position = gl_ProjectionMatrix * viewPosition;
}
#endif
