#ifndef ZEPHO_LIGHTING_GLSL
#define ZEPHO_LIGHTING_GLSL

#ifndef ZEPH_HAS_SUN_POSITION
uniform vec3 sunPosition;
#endif
#ifndef ZEPH_HAS_MOON_POSITION
uniform vec3 moonPosition;
#endif

float zephDaylightFromSun() {
    return zephDaylightFromDirection(sunPosition);
}

// Lightmap UVs address the centers of sixteen texels. Use the full [0,1]
// light-level range for artistic controls while leaving texture sampling alone.
vec2 zephLightingLevels(vec2 lightCoord) {
    return clamp((lightCoord - vec2(1.0 / 32.0)) * (16.0 / 15.0), 0.0, 1.0);
}

// Bounded proxy for how strongly outdoor colour should affect a surface.
// The lightmap remains authoritative; this cannot resolve occlusion. Reducing
// the weight for block-lit surfaces avoids tinting local light as if it were
// entirely sky illumination. No additive light is introduced.
float zephSceneSkyWeight(vec2 lightCoord) {
    vec2 levels = zephLightingLevels(lightCoord);
    float sky = zephSkyExposure(levels.y);
    float blockProtection = 1.0 - 0.55 * levels.x * (1.0 - 0.5 * levels.y);
    return sky * blockProtection;
}

vec3 zephBlockLightWarmth(vec3 linearColour, vec2 lightCoord, float daylight, float storm) {
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY == 0
    return linearColour;
#else
    vec2 levels = zephLightingLevels(lightCoord);
    float blockLight = levels.x;
#if !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
    // Allow an outdoor torch more influence after sunset or under cloud.
    float skyLight = levels.y;
    float effectiveSky = skyLight * mix(0.25, 1.0, daylight) * (1.0 - zephSaturate(storm) * 0.25);
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY == 1
    // Low uses a bounded linear attenuation in place of a ratio.
    float dominance = 1.0 - 0.55 * effectiveSky;
#else
    float dominance = blockLight / (blockLight + effectiveSky * 0.75 + 0.001);
#endif
#else
    // Non-Overworld lightmap sky coordinates do not represent an outdoor
    // solar source. Keep the block-light palette independent of that axis.
    float dominance = 1.0;
#endif
    const float ZEPH_BLOCK_LIGHT_INV_RANGE = 1.25;
    float tWarmth = clamp((blockLight - 0.10) * ZEPH_BLOCK_LIGHT_INV_RANGE, 0.0, 1.0);
    float warmthFactor = (tWarmth * tWarmth * (3.0 - 2.0 * tWarmth)) * dominance;

#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY == 1
    float strength = 0.28;
#elif ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY == 2
    float strength = 0.42;
#else
    float strength = 0.55;
#endif

    vec3 warmTint = vec3(1.09, 0.985, 0.87);
    return linearColour * mix(vec3(1.0), warmTint, warmthFactor * strength);
#endif
}

vec3 zephApplySceneLighting(vec3 linearColour, vec3 normal, vec2 lightCoord, float storm) {
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY == 0
    return linearColour;
#elif defined(ZEPH_DIM_NETHER)
    float upward = dot(normal, zephWorldUpView()) * 0.5 + 0.5;
    vec3 lit = linearColour * mix(0.85, 1.05, upward);
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY >= 2
    lit *= vec3(1.01225, 0.99475, 0.98425);
#endif
    return zephBlockLightWarmth(lit, lightCoord, 0.0, 0.0);
#elif defined(ZEPH_DIM_END)
    float upward = max(dot(normal, zephWorldUpView()), 0.0);
    vec3 lit = linearColour * mix(0.88, 1.02, upward * 0.6 + 0.4);
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY >= 2
    lit *= vec3(0.99125, 0.99125, 1.014);
#endif
    return zephBlockLightWarmth(lit, lightCoord, 0.0, 0.0);
#else
    vec3 worldUp = zephWorldUpView();
    vec3 sunDir = zephSafeNormalize(sunPosition);
    float sunElevation = dot(sunDir, worldUp);
    float daylight = zephDaylightFromElevation(sunElevation);
    float facing = zephSaturate(dot(normal, sunDir) * 0.5 + 0.5);
    float skyWeight = zephSceneSkyWeight(lightCoord);
    float weather = zephSaturate(storm);

    // Only the upper tiers shape moonlight. Low keeps the midpoint response
    // at night, with no moon-direction normalization or normal dot product.
    float dayFace = mix(0.84, 1.06, facing);
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY == 1
    float nightFace = 0.955;
#else
    float moonFacing = zephSaturate(dot(normal, zephSafeNormalize(moonPosition)) * 0.5 + 0.5);
    float nightFace = mix(0.91, 1.00, moonFacing);
#endif
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY >= 3
    float smoothSun = facing * facing * (3.0 - 2.0 * facing);
    dayFace = mix(dayFace, mix(0.84, 1.06, smoothSun), 0.35);
#endif
    dayFace = mix(dayFace, 0.97, weather * 0.65);
    nightFace = mix(nightFace, 0.96, weather * 0.55);
    float rawCelestial = mix(nightFace, dayFace, daylight);
    vec3 lit = linearColour * mix(1.0, rawCelestial, skyWeight);

#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY >= 2
    float normalUp = dot(normal, worldUp);
    // Reduce the exposed-sky contribution to overhanging faces. Block-lit
    // interiors retain their lightmap colour and receive no celestial tint.
    float overhang = max(-normalUp, 0.0);
    lit *= 1.0 - 0.065 * skyWeight * overhang * overhang;
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY >= 3
    vec3 skyHemisphere = vec3(0.96, 0.98, 1.04);
    vec3 groundBounce = vec3(1.02, 0.99, 0.96);
    vec3 domeFill = mix(groundBounce, skyHemisphere, normalUp * 0.5 + 0.5);
    lit *= mix(vec3(1.0), domeFill, skyWeight * 0.12);
#endif
    float duskTint = zephClearTwilight(sunElevation, weather);
    vec3 ambientTint = mix(vec3(0.94, 0.97, 1.06), vec3(1.015, 1.005, 0.985), daylight);
    vec3 duskColour = zephTwilightSurfaceTint(facing);
    ambientTint = mix(ambientTint, duskColour, duskTint * 0.65);
    lit *= mix(vec3(1.0), ambientTint, skyWeight * 0.55);
#endif
    return zephBlockLightWarmth(lit, lightCoord, daylight, weather);
#endif
}

#endif
