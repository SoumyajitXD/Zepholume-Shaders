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

// Bounded proxy for how strongly outdoor colour should affect a surface.
// The lightmap remains authoritative; this cannot resolve occlusion. Reducing
// the weight for block-lit surfaces avoids tinting local light as if it were
// entirely sky illumination. No additive light is introduced.
float zephSceneSkyWeight(vec2 lightCoord) {
    float sky = zephSkyExposure(lightCoord.y);
    float blockProtection = 1.0 - 0.55 * zephSaturate(lightCoord.x) *
        (1.0 - 0.5 * zephSaturate(lightCoord.y));
    return sky * blockProtection;
}
float zephFaceLight(vec3 normal, vec2 lightCoord, float storm, vec3 sunDir, float daylight) {
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY == 0
    return 1.0;
#elif defined(ZEPH_DIM_NETHER)
    // Nether has no celestial bodies. Ambient vertical fill creates cavern depth
    // without phantom directional shadows from an invisible sun.
    float upward = zephWorldElevation(normal) * 0.5 + 0.5;
    return mix(0.85, 1.05, upward);
#elif defined(ZEPH_DIM_END)
    // The End has no celestial sun/moon. Omnidirectional void-grounded ambient.
    float upward = max(zephWorldElevation(normal), 0.0);
    return mix(0.88, 1.02, upward * 0.6 + 0.4);
#else
    vec3 moonDir = zephSafeNormalize(moonPosition);

    // The lightmap already supplies illumination. This is a bounded face-shape
    // response, not a visibility test or a second shadowing system. A wrapped
    // lobe keeps block faces readable while preserving a clear solar direction.
    float sunDirect = zephSaturate(dot(normal, sunDir) * 0.5 + 0.5);
    float moonDirect = zephSaturate(dot(normal, moonDir) * 0.5 + 0.5);
    float dayFace = mix(0.84, 1.06, sunDirect);
    float nightFace = mix(0.91, 1.00, moonDirect);

#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY >= 3
    // A smoother terminator on upper tiers keeps large block faces from
    // switching abruptly as the sun crosses the horizon.
    float smoothSun = sunDirect * sunDirect * (3.0 - 2.0 * sunDirect);
    dayFace = mix(dayFace, mix(0.84, 1.06, smoothSun), 0.35);
#endif
    // Clouds scatter directional contrast. Keep the response neutral when
    // overcast rather than darkening the whole world a second time.
    dayFace = mix(dayFace, 0.97, zephSaturate(storm) * 0.65);
    nightFace = mix(nightFace, 0.96, zephSaturate(storm) * 0.55);
    float rawCelestial = mix(nightFace, dayFace, daylight);

    // Lightmap coordinates are proxies, never geometric visibility. Reduce
    // celestial shaping when local block light dominates, including a torch
    // against an otherwise skylit face; black sampled light remains black.
    return mix(1.0, rawCelestial, zephSceneSkyWeight(lightCoord));
#endif
}

vec3 zephBlockLightWarmth(vec3 linearColour, vec2 lightCoord, float daylight, float storm) {
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY == 0
    return linearColour;
#else
    // Relative block-light dominance:
    // Torches, lanterns, and fire emit warm incandescent light (~2700K-3200K).
    // Modulate warmth by the ratio of block light (lightCoord.x) to skylight (lightCoord.y),
    // preventing broad daylight from acquiring an orange tint while making dark interiors
    // and caves richly incandescent without clipping or destroying cool material chroma.
    float blockLight = lightCoord.x;
    float skyLight = lightCoord.y;
    // The sky lightmap channel describes exposure, not incident solar energy.
    // At night or in rain, an exposed torch still contributes warm light.
    // Keep a night floor to avoid discontinuous tint changes around twilight.
#if !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
    float effectiveSky = skyLight * mix(0.25, 1.0, daylight) * (1.0 - zephSaturate(storm) * 0.25);
#else
    float effectiveSky = skyLight;
#endif
    float dominance = blockLight / max(blockLight + effectiveSky * 0.75 + 0.001, 0.001);
    // Exact smoothstep shape with a compile-time reciprocal range.
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
#else
#if !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
    // Share the normalized solar direction and day weight between direct and
    // ambient lighting. The former was normalized twice per fragment.
    vec3 sunDir = zephSafeNormalize(sunPosition);
    float sunElevation = dot(sunDir, zephWorldUpView());
    float daylight = zephDaylightFromElevation(sunElevation);
#else
    vec3 sunDir = vec3(0.0);
    float daylight = 0.0;
#endif
    vec3 lit = linearColour * zephFaceLight(normal, lightCoord, storm, sunDir, daylight);
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY >= 3 && !defined(ZEPH_DIM_NETHER) && !defined(ZEPH_DIM_END)
    // High & Ultra dual-hemisphere ambient irradiance: upward surfaces receive subtle cool sky fill,
    // downward surfaces receive subtle warm ground bounce.
    float up = zephWorldElevation(normal) * 0.5 + 0.5;
    vec3 skyHemisphere = vec3(0.96, 0.98, 1.04);
    vec3 groundBounce = vec3(1.02, 0.99, 0.96);
    vec3 domeFill = mix(groundBounce, skyHemisphere, up);
    lit *= mix(vec3(1.0), domeFill, zephSceneSkyWeight(lightCoord) * 0.12);
#endif
    lit = zephBlockLightWarmth(lit, lightCoord, daylight, storm);
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY >= 2
    // Artistic ambient colour is strictly multiplicative: black lightmap results
    // remain black, and celestial tint cannot leak into unlit caves.  Storms
    // suppress the coloured component rather than adding a brightness floor.
#if defined(ZEPH_DIM_NETHER)
    vec3 ambientTint = vec3(1.035, 0.985, 0.955);
    float ambientWeight = 0.35;
#elif defined(ZEPH_DIM_END)
    vec3 ambientTint = vec3(0.975, 0.975, 1.04);
    float ambientWeight = 0.35;
#else
    float duskTint = zephClearTwilight(sunElevation, storm);
    vec3 ambientTint = mix(vec3(0.94, 0.97, 1.06), vec3(1.015, 1.005, 0.985), daylight);
    // Twilight warms sun-facing surfaces and cools their shaded sides. This
    // modulates the sampled lightmap, so an unlit cave cannot gain light.
    float facing = zephSaturate(dot(normal, sunDir) * 0.5 + 0.5);
    vec3 duskColour = zephTwilightSurfaceTint(facing);
    ambientTint = mix(ambientTint, duskColour, duskTint * 0.65);
    float ambientWeight = zephSceneSkyWeight(lightCoord) * 0.55;
#endif
    lit *= mix(vec3(1.0), ambientTint, ambientWeight);
#endif
    return lit;
#endif
}

#endif
