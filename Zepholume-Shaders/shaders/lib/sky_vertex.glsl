#ifndef ZEPHO_SKY_VERTEX_GLSL
#define ZEPHO_SKY_VERTEX_GLSL
#include "/lib/profile.glsl"
varying vec2 zephSkyTexCoord;
varying vec4 zephSkyVertexColour;
varying float zephSkyUp;
varying vec3 zephSkyDirection;

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    float safeLength = max(length(viewPosition.xyz), 0.0001);
    zephSkyUp = clamp(0.5 + 0.5 * viewPosition.y / safeLength, 0.0, 1.0);
    zephSkyDirection = viewPosition.xyz / safeLength;
    zephSkyTexCoord = gl_MultiTexCoord0.st;
    zephSkyVertexColour = gl_Color;
    gl_Position = gl_ProjectionMatrix * viewPosition;
}
#endif
