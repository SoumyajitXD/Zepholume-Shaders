#ifndef ZEPHO_VERTEX_GLSL
#define ZEPHO_VERTEX_GLSL
#include "/lib/profile.glsl"
#include "/lib/common.glsl"
#include "/lib/water.glsl"
#if defined(ZEPH_TERRAIN_PROGRAM) && ZEPH_EFFECTIVE_PROFILE_TIER > 0
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;
#if ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
flat varying float zephTerrainMaterial;
#endif

vec4 zephMoveFoliage(vec4 p) {
    float id = mc_Entity.x;
    if (id < 10100.0 || id > 10103.0) return p;
    // Texture midpoint distinguishes the upper vertices of upright crossed
    // plant quads; upper halves of double plants move as a unit. Leaves use
    // a continuous world-space field rather than per-block random offsets.
    float weight = id > 10102.5 ? 0.32 :
                   (id > 10101.5 ? 1.0 : float(gl_MultiTexCoord0.t < mc_midTexCoord.t));
    if (weight == 0.0) return p;

    // Work from the existing view-space vertex. The wavelength divides Iris's
    // 30,000-block camera rebase stride, keeping either side in the same phase.
    const float spatialFrequency = 6.28318530718 / 240.0;
    vec2 world = (gbufferModelViewInverse * p).xz + mod(cameraPosition.xz, 240.0);
    float phase = (world.x + 2.0 * world.y) * spatialFrequency + frameTimeCounter * 0.900589893;
    float strength = 0.018;
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 2
    strength = 0.035 * (1.0 + 0.3 * clamp(rainStrength, 0.0, 1.0));
#endif
    // A broad traveling gust varies bend across the landscape instead of
    // rocking all vegetation on a single axis in lockstep. Both harmonics
    // remain continuous at the camera and frame-time wrap boundaries.
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 2
    float gust = sin((2.0 * world.x - world.y) * spatialFrequency + frameTimeCounter * 0.0977384381);
    float sway = (sin(phase) + 0.30 * gust) * strength * weight;
#else
    // Low retains anchored motion with one periodic field and no gust sine.
    float sway = sin(phase) * strength * weight;
#endif
    vec2 movement = vec2(sway, sway * 0.45);
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 3
    // A small quadrature component breaks the rigid single-axis motion at
    // higher tiers; identical weighting keeps plant bases fixed and the two
    // halves of tall plants continuous. The period matches the time reset.
    movement.y += sin(phase + 1.570796327) * strength * weight * 0.22;
#endif
#if ZEPH_EFFECTIVE_PROFILE_TIER >= 4
    // The same slow gust controls bend amplitude as well as drift. This lets
    // stands briefly settle and pick up again without another sampled field.
    movement *= 0.85 + 0.15 * gust;
#endif
    // Leaf canopies and rooted plants lean in different directions without an
    // extra trigonometric evaluation or a per-block discontinuous hash.
    if (id > 10102.5) movement.y = -movement.y;
    p.xyz += gbufferModelView[0].xyz * movement.x + gbufferModelView[2].xyz * movement.y;
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
#if defined(ZEPH_TERRAIN_PROGRAM) && ZEPH_EFFECTIVE_PROFILE_TIER > 0
#if ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0
    zephTerrainMaterial = float(mc_Entity.x >= 10100.0 && mc_Entity.x <= 10103.0);
#endif
    viewPosition = zephMoveFoliage(viewPosition);
#endif
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
