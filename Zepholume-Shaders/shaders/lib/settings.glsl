#ifndef ZEPHO_SETTINGS_GLSL
#define ZEPHO_SETTINGS_GLSL

// Balanced is the source default. profile.glsl consumes these raw controls
// and exposes capability-clamped ZEPH_EFFECTIVE_* macros to rendering code.
#define ZEPH_PROFILE_TIER 2 // [0 1 2 3 4]
#define ZEPH_EXPOSURE 1 // [0 1 2]
#define ZEPH_CONTRAST 1 // [0 1 2]
#define ZEPH_SATURATION 1 // [0 1 2]
#define ZEPH_COLOUR_TEMPERATURE 2 // [0 1 2]
#define ZEPH_FOG_QUALITY 1 // [0 1]
#define ZEPH_ATMOSPHERE_QUALITY 1 // [0 1]
#define ZEPH_FACE_LIGHTING_QUALITY 2 // [0 1 2 3]
#define ZEPH_MATERIAL_QUALITY 1 // [0 1]
#define ZEPH_CLOUD_QUALITY 1 // [0 1]
#define ZEPH_CLOUD_TIER 2 // [0 1 2 3 4]
#define ZEPH_WATER_QUALITY 1 // [0 1]
#define ZEPH_WATER_TIER 2 // [0 1 2 3 4]
#define ZEPH_WATER_WAVES 1 // [0 1]
#define ZEPH_WEATHER_QUALITY 1 // [0 1 2 3]
#endif
