#ifndef ZEPHO_VERTEX_GLSL
#define ZEPHO_VERTEX_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"
#include "/lib/water.glsl"
#if defined(ZEPH_TERRAIN_PROGRAM) && ZEPH_EFFECTIVE_PROFILE_TIER > 0
attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;

vec4 zephMoveFoliage(vec4 p) {
    float id = mc_Entity.x;
    if (id < 10100.0 || id > 10103.0) return p;
    // Texture midpoint distinguishes the upper vertices of upright crossed
    // plant quads; upper halves of double plants move as a unit. Leaves use
    // a continuous world-space field rather than per-block random offsets.
    float weight = id > 10102.5 ? 0.32 :
                   (id > 10101.5 ? 1.0 : float(gl_MultiTexCoord0.t < mc_midTexCoord.t));
    vec3 relative = (gbufferModelViewInverse * (gl_ModelViewMatrix * p)).xyz;
    vec2 world = relative.xz + mod(cameraPosition.xz, 256.0);
    // Integer spatial frequencies are periodic over 256 blocks: camera
    // modulo wrap and chunk boundaries are continuous; loader origin resets
    // or teleports can still change the phase.
    float phase = (world.x + 2.0 * world.y) * 0.0245436926 + frameTimeCounter * 0.900589893;
    float strength = 0.018;
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 2
    strength = 0.035 * (1.0 + 0.3 * clamp(rainStrength, 0.0, 1.0));
#endif
    // A broad traveling gust varies bend across the landscape instead of
    // rocking all vegetation on a single axis in lockstep. Both harmonics
    // remain continuous at the camera and frame-time wrap boundaries.
    float gust = sin((2.0 * world.x - world.y) * 0.0245436926 + frameTimeCounter * 0.0977384381);
    float sway = (sin(phase) + 0.30 * gust) * strength * weight;
    vec2 movement = vec2(sway, sway * 0.45);
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 3
    // A small quadrature component breaks the rigid single-axis motion at
    // higher tiers; identical weighting keeps plant bases fixed and the two
    // halves of tall plants continuous. The period matches the time reset.
    movement.y += sin(phase + 1.570796327) * strength * weight * 0.22;
#endif
    // Leaf canopies and rooted plants lean in different directions without an
    // extra trigonometric evaluation or a per-block discontinuous hash.
    if (id > 10102.5) movement.y = -movement.y;
    p.xz += movement;
    return p;
}
#endif
#ifdef ZEPH_WATER_PROGRAM
// block.properties assigns a stable pack-local ID only to Minecraft water.
// gbuffers_water also renders glass, ice, and other translucent terrain, so
// water displacement and shading must be explicitly material-gated.
#if (ZEPH_EFFECTIVE_WATER_TIER > 0 && ZEPH_EFFECTIVE_WATER_QUALITY > 0) || (ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1) || ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
attribute vec4 mc_Entity;
#endif
#if (ZEPH_EFFECTIVE_WATER_TIER > 0 && ZEPH_EFFECTIVE_WATER_QUALITY > 0) || (ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1)
flat varying float zephIsWater;
#endif
#if ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
flat varying float zephTranslucentMaterial;
#endif
#endif
#ifndef ZEPH_UNTEXTURED_PROGRAM
varying vec2 zephTexCoord;
#endif
varying vec2 zephLightCoord;
varying vec4 zephVertexColour;
#if !defined(ZEPH_HAND_PROGRAM) && (ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY > 0 || ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0 || (defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER > 0 && ZEPH_EFFECTIVE_WATER_QUALITY > 0))
varying vec3 zephNormalView;
#endif
varying vec3 zephViewDirection;
void main() {
    vec4 position = gl_Vertex;
#if defined(ZEPH_TERRAIN_PROGRAM) && ZEPH_EFFECTIVE_PROFILE_TIER > 0
    position = zephMoveFoliage(position);
#endif
#ifdef ZEPH_WATER_PROGRAM
#if (ZEPH_EFFECTIVE_WATER_TIER > 0 && ZEPH_EFFECTIVE_WATER_QUALITY > 0) || (ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1)
    zephIsWater = abs(mc_Entity.x - 10001.0) < 0.5 ? 1.0 : 0.0;
#endif
#if ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
    zephTranslucentMaterial = abs(mc_Entity.x - 10002.0) < 0.5 ? 1.0 :
                              (abs(mc_Entity.x - 10003.0) < 0.5 ? 2.0 : 0.0);
#endif
#if ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1
    // Omit the material-dependent displacement branch entirely when waves
    // compile to an identity. Keep the material flag for fragment shading.
    if (zephIsWater > 0.5) {
        vec2 waterWorld = zephWaterPhasePosition((gl_ModelViewMatrix * position).xyz);
        position = zephMoveWater(position, waterWorld);
    }
#endif
#endif
    vec4 viewPosition = gl_ModelViewMatrix * position;
#if !defined(ZEPH_HAND_PROGRAM) && (ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY > 0 || ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0 || (defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER > 0 && ZEPH_EFFECTIVE_WATER_QUALITY > 0))
    vec3 surfaceNormal = gl_Normal;
    zephNormalView = gl_NormalMatrix * surfaceNormal;
#endif
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
