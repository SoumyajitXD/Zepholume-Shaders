#ifndef ZEPHO_VERTEX_GLSL
#define ZEPHO_VERTEX_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"
#include "/lib/water.glsl"
#ifdef ZEPH_WATER_PROGRAM
// block.properties assigns a stable pack-local ID only to Minecraft water.
// gbuffers_water also renders glass, ice, and other translucent terrain, so
// water displacement and shading must be explicitly material-gated.
attribute vec4 mc_Entity;
flat varying float zephIsWater;
#endif
#ifndef ZEPH_UNTEXTURED_PROGRAM
varying vec2 zephTexCoord;
#endif
varying vec2 zephLightCoord;
varying vec4 zephVertexColour;
varying vec3 zephNormalView;
varying vec3 zephViewDirection;
void main() {
    vec4 position = gl_Vertex;
#ifdef ZEPH_WATER_PROGRAM
    zephIsWater = abs(mc_Entity.x - 10001.0) < 0.5 ? 1.0 : 0.0;
    if (zephIsWater > 0.5) {
        position = zephMoveWater(position);
    }
#endif
    vec4 viewPosition = gl_ModelViewMatrix * position;
    zephNormalView = gl_NormalMatrix * gl_Normal;
    // Interpolate the affine view-space ray before normalizing in consumers.
    // Unit rays at unequal-distance corners do not interpolate to the true
    // fragment ray and introduce diagonal-dependent Fresnel on planar water.
    zephViewDirection = -viewPosition.xyz;
    zephLightCoord = clamp((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy, 0.0, 1.0);
#ifndef ZEPH_UNTEXTURED_PROGRAM
    zephTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#endif
    zephVertexColour = gl_Color;
    gl_Position = gl_ProjectionMatrix * viewPosition;
}
#endif
