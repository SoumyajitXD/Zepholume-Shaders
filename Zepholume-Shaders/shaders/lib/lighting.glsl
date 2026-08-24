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

float zephFaceLight(vec3 normal, vec2 lightCoord, float storm) {
#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY == 0
    return 1.0;
#elif defined(ZEPH_DIM_NETHER)
    // Nether has no celestial bodies. Ambient vertical fill creates cavern depth
    // without phantom directional shadows from an invisible sun.
    float upward = normal.y * 0.5 + 0.5;
    return mix(0.85, 1.05, upward);
#elif defined(ZEPH_DIM_END)
    // The End has no celestial sun/moon. Omnidirectional void-grounded ambient.
    float upward = max(normal.y, 0.0);
    return mix(0.88, 1.02, upward * 0.6 + 0.4);
#else
    vec3 sunDir = zephSafeNormalize(sunPosition);
    vec3 moonDir = zephSafeNormalize(moonPosition);
    float daylight = zephDaylightFromElevation(sunDir.y);

    // Day direct celestial lighting
    float sunDirect = max(dot(normal, sunDir), 0.0);
    float dayFace = sunDirect * 0.65 + 0.35;

    // Night directional moonlight with grounded non-facing ambient
    float moonDirect = max(dot(normal, moonDir), 0.0);
    float nightFace = mix(0.72, 0.88, moonDirect * 0.55 + 0.45);

#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY >= 3
    // High and Ultra apply softened wrap curve for smoother facet transitions
    dayFace = mix(dayFace, sqrt(max(dayFace, 0.0)), 0.22);
    nightFace = mix(nightFace, sqrt(max(nightFace, 0.0)), 0.15);
#endif

    // Soften directional contrast during overcast storms
    dayFace = mix(dayFace, 0.78, storm * 0.45);
    nightFace = mix(nightFace, 0.80, storm * 0.30);

    float rawCelestial = mix(nightFace, dayFace, daylight);

    // Ground directional contrast using skylight (lightCoord.y).
    // Deep caves and interiors (skyLight -> 0) transition to isotropic ambient (1.0),
    // preventing outdoor sun/moon directional contrast from penetrating underground.
    float skyLight = lightCoord.y;
    float celestialWeight = smoothstep(0.04, 0.65, skyLight);
    return mix(1.0, rawCelestial, celestialWeight);
#endif
}

vec3 zephBlockLightWarmth(vec3 linearColour, vec2 lightCoord) {
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
    float dominance = blockLight / max(blockLight + skyLight * 0.75 + 0.001, 0.001);
    float warmthFactor = smoothstep(0.10, 0.90, blockLight) * dominance;

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
    vec3 lit = linearColour * zephFaceLight(normal, lightCoord, storm);
    return zephBlockLightWarmth(lit, lightCoord);
#endif
}

#endif
