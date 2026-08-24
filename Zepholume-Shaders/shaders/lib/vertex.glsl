#ifndef ZEPHO_VERTEX_GLSL
#define ZEPHO_VERTEX_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"
#include "/lib/water.glsl"
#ifndef ZEPH_UNTEXTURED_PROGRAM
varying vec2 zephTexCoord;
#endif
varying vec2 zephLightCoord;
varying vec4 zephVertexColour;
varying float zephDistance;
varying vec3 zephNormalView;
varying vec3 zephViewDirection;
void main() {
    vec4 position = gl_Vertex;
#ifdef ZEPH_WATER_PROGRAM
    position = zephMoveWater(position);
#endif
    vec4 viewPosition = gl_ModelViewMatrix * position;
    zephDistance = length(viewPosition.xyz);
    zephNormalView = gl_NormalMatrix * gl_Normal;
    zephViewDirection = -viewPosition.xyz / max(zephDistance, 0.0001);
    zephLightCoord = clamp((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy, 0.0, 1.0);
#ifndef ZEPH_UNTEXTURED_PROGRAM
    zephTexCoord = gl_MultiTexCoord0.st;
#endif
    zephVertexColour = gl_Color;
    gl_Position = gl_ProjectionMatrix * viewPosition;
}
#endif
