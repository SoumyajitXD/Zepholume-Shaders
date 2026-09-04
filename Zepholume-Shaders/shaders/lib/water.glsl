#ifndef ZEPHO_WATER_GLSL
#define ZEPHO_WATER_GLSL

uniform vec3 skyColor;
uniform float frameTimeCounter;
#ifndef ZEPH_HAS_SUN_POSITION
uniform vec3 sunPosition;
#endif
#ifndef ZEPH_HAS_MOON_POSITION
uniform vec3 moonPosition;
#endif
#ifndef ZEPH_HAS_RAIN_STRENGTH
uniform float rainStrength;
#endif

vec4 zephMoveWater(vec4 p) {
#if ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1
    // Two low-amplitude, time-based waves add movement without pretending to
    // know fluid depth or using a second buffer. Frame time is loader-owned.
    float waveTime = frameTimeCounter * 0.65;
    p.y += sin(p.x * 0.10 + p.z * 0.07 + waveTime) * 0.014;
    p.y += cos(p.z * 0.12 - p.x * 0.035 + waveTime * 0.73) * 0.008;
#if ZEPH_EFFECTIVE_WATER_TIER >= 3
    p.y += sin(p.x * 0.035 - p.z * 0.055 + waveTime * 0.41) * 0.006;
#endif
#endif
    return p;
}

vec3 zephWaterDecode(vec3 colour) {
    return max(colour, vec3(0.0)) * max(colour, vec3(0.0));
}

// Bounded Blinn-Phong power 64 specular with dual-lobe intermediate
float zephSpecularLobe(float nDotH) {
    float n2 = nDotH * nDotH;
    float n4 = n2 * n2;
    float n8 = n4 * n4;
    float n16 = n8 * n8;
    float n32 = n16 * n16;
    float n64 = n32 * n32;
#if ZEPH_EFFECTIVE_WATER_TIER >= 2
    return mix(n64, n16, 0.12);
#else
    return n64;
#endif
}

// Returns working-space colour.  The ordinary scene route already grades in
// that space, so encoding here only for fragment.glsl to decode immediately
// afterward was redundant per-fragment work.
vec3 zephWaterSurfaceLinear(vec3 displayColour, vec3 normal, vec3 viewDirection, float distance) {
#if ZEPH_EFFECTIVE_WATER_TIER == 0 || ZEPH_EFFECTIVE_WATER_QUALITY == 0
    return displayColour;
#else
    vec3 water = zephWaterDecode(displayColour);
    vec3 viewDir = zephSafeNormalize(viewDirection);

    // Bounded fourth-power Fresnel-inspired approximation. Conventional
    // Fresnel-Schlick uses a fifth power; 0.035 is a deliberate artistic
    // baseline above common water-dielectric references (~0.02), not a claim
    // of physical accuracy.
    float NdotV = clamp(dot(normal, viewDir), 0.0, 1.0);
    float fBase = 1.0 - NdotV;
    float f2 = fBase * fBase;
#if ZEPH_EFFECTIVE_WATER_TIER >= 3
    // High and Ultra use fifth-power Fresnel-Schlick for refined grazing reflectance
    float fresnel = f2 * f2 * fBase;
#else
    float fresnel = f2 * f2;
#endif

    vec3 transmission = water * vec3(0.82, 0.98, 0.94);
    transmission = mix(transmission, transmission * vec3(0.75, 0.92, 0.90), clamp(distance * 0.00025, 0.0, 1.0) * 0.18);

    vec3 reflectedSky = zephWaterDecode(skyColor) * vec3(0.80, 0.90, 0.98);
    float storm = clamp(rainStrength, 0.0, 1.0);

    float reflectance = mix(0.035, 0.46, fresnel) * (1.0 - storm * 0.35);

#if defined(ZEPH_DIM_NETHER) || defined(ZEPH_DIM_END)
    // Non-Overworld dimensions omit celestial sun/moon specular calculations
    vec3 surface = mix(transmission, reflectedSky, reflectance * 0.65);
    return max(surface, vec3(0.0));
#else
    // Analytical celestial specular highlight.  Keep both lobes evaluated so
    // the V1.0.2 continuous day/night transfer remains exactly intact; branch
    // lowering and savings are implementation-dependent without GPU ISA data.
    vec3 sunDir = zephSafeNormalize(sunPosition);
    float daylight = zephDaylightFromElevation(sunDir.y);
    vec3 sunHalf = zephSafeNormalize(viewDir + sunDir);
    float sunNdotH = max(dot(normal, sunHalf), 0.0);
    float sunHorizonFade = zephSaturate(sunDir.y * 6.0 + 0.1);
    float sunSpecFactor = zephSpecularLobe(sunNdotH) * daylight * sunHorizonFade;
    vec3 sunSpecular = vec3(1.15, 1.08, 0.92) * (sunSpecFactor * 0.60);

    vec3 moonDir = zephSafeNormalize(moonPosition);
    vec3 moonHalf = zephSafeNormalize(viewDir + moonDir);
    float moonNdotH = max(dot(normal, moonHalf), 0.0);
    float moonHorizonFade = zephSaturate(moonDir.y * 6.0 + 0.1);
    float moonSpecFactor = zephSpecularLobe(moonNdotH) * (1.0 - daylight) * moonHorizonFade;
    vec3 moonSpecular = vec3(0.55, 0.68, 0.88) * (moonSpecFactor * 0.25);
    vec3 celestialSpecular = sunSpecular + moonSpecular;

    celestialSpecular *= (1.0 - storm * 0.85);

#if ZEPH_EFFECTIVE_WATER_TIER == 1
    reflectance *= 0.55;
    celestialSpecular *= 0.35;
#elif ZEPH_EFFECTIVE_WATER_TIER >= 4
    reflectance = min(reflectance * 1.16, 0.52);
    celestialSpecular *= 1.20;
#endif

    vec3 surface = mix(transmission, reflectedSky, reflectance) + celestialSpecular;
    return max(surface, vec3(0.0));
#endif
#endif
}

#endif
