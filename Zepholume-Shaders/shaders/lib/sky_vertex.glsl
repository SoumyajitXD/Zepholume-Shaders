#ifndef ZEPHO_SKY_VERTEX_GLSL
#define ZEPHO_SKY_VERTEX_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"
varying vec2 zephSkyTexCoord;
varying vec4 zephSkyVertexColour;
varying vec3 zephSkyViewPosition;

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    // Perspective-correct interpolation reconstructs the view-space position
    // on the primitive; normalization is nonlinear and belongs per fragment.
    zephSkyViewPosition = viewPosition.xyz;
    zephSkyTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    zephSkyVertexColour = gl_Color;
    gl_Position = gl_ProjectionMatrix * viewPosition;
}
#endif
