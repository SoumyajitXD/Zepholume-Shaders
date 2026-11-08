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
#if (defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1) || (defined(ZEPH_TERRAIN_PROGRAM) && ZEPH_EFFECTIVE_PROFILE_TIER > 0)
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
#endif

// Integer harmonics of a 256-block domain avoid seams at camera modulo wrap.
// Integer cycles over 3600 seconds keep the loader's time-counter wrap smooth.
#if defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1
vec2 zephWaterPhasePosition(vec3 viewPosition) {
    return (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xz + mod(cameraPosition.xz, 256.0);
}
#endif

vec4 zephMoveWater(vec4 p, vec2 world) {
#if ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1
    // A broad swell moves every vertex, including sides, by the same field so
    // shared waterfall edges stay joined. Fine detail is shading-only.
    float phase = dot(world, vec2(3.0, 2.0)) * 0.024543692606 + frameTimeCounter * 0.5235987756;
    p.y += sin(phase) * 0.025;
#endif
    return p;
}

#if defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1
// Fragment-space analytic ripples break up the reflection independently of
// the coarse block mesh. Facet normals gate the field off vertical waterfalls;
// distance fades the fine scales before they can alias into the horizon.
vec3 zephWaterRippleNormal(vec3 normal, vec3 viewDirection, float distance) {
    float upward = zephWorldElevation(normal);
    float top = smoothstep(0.82, 0.96, upward);
    if (top <= 0.0) return normal;
    vec2 world = zephWaterPhasePosition(-viewDirection);
    float t = frameTimeCounter * 0.001745329252;
    float broad = dot(world, vec2(3.0, 2.0)) * 0.024543692606 + t * 300.0;
    float ripple = dot(world, vec2(-7.0, 11.0)) * 0.024543692606 - t * 390.0;
    vec2 slope = vec2(3.0, 2.0) * (cos(broad) * 0.018);
    slope += vec2(-7.0, 11.0) * (cos(ripple) * 0.006 * (1.0 - smoothstep(35.0, 110.0, distance)));
#if ZEPH_EFFECTIVE_WATER_TIER >= 3
    float crossRipple = dot(world, vec2(13.0, 5.0)) * 0.024543692606 + t * 510.0;
    slope += vec2(13.0, 5.0) * (cos(crossRipple) * 0.004 * (1.0 - smoothstep(22.0, 75.0, distance)));
#endif
    vec3 perturb = mat3(gbufferModelView) * vec3(-slope.x, 0.0, -slope.y);
    return zephSafeNormalize(normal + perturb * top);
}
#endif

vec3 zephWaterDecode(vec3 colour) {
    return max(colour, vec3(0.0)) * max(colour, vec3(0.0));
}

// Bounded Blinn-Phong power 64 specular with dual-lobe intermediate
float zephSpecularLobe(float nDotH) {
    // A normalized dot can round slightly above one; bound the power chain.
    nDotH = clamp(nDotH, 0.0, 1.0);
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
vec3 zephWaterSurfaceLinear(vec3 displayColour, vec3 normal, vec3 viewDirection, float distance, float skyExposure) {
#if ZEPH_EFFECTIVE_WATER_TIER == 0 || ZEPH_EFFECTIVE_WATER_QUALITY == 0
    return displayColour;
#else
    vec3 water = zephWaterDecode(displayColour);
    vec3 viewDir = zephSafeNormalize(viewDirection);
#if defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1
    normal = zephWaterRippleNormal(normal, viewDirection, distance);
#endif

    // Bounded fourth-power Fresnel-inspired approximation. Conventional
    // Fresnel-Schlick uses a fifth power; the 0.025 face-on response and
    // capped grazing strength are artistic, not physically accurate.
    float signedNdotV = dot(normal, viewDir);
    float NdotV = clamp(signedNdotV, 0.0, 1.0);
    // Reflection is two-sided: a viewer below a surface sees the same
    // angular response. Keep signed NdotV for the front-face light lobes.
    float fBase = 1.0 - clamp(abs(signedNdotV), 0.0, 1.0);
    float f2 = fBase * fBase;
#if ZEPH_EFFECTIVE_WATER_TIER >= 3
    // High and Ultra use fifth-power Fresnel-Schlick for refined grazing reflectance
    float fresnel = f2 * f2 * fBase;
#else
    float fresnel = f2 * f2;
#endif

    // Preserve the supplied biome/texture colour. Camera-to-surface distance
    // is not water depth, so it must not darken distant shorelines.
    vec3 transmission = water * vec3(0.88, 0.98, 0.96);
#if ZEPH_EFFECTIVE_WATER_TIER >= 2
    // A bounded angular colour cue, not an estimate of the water column.
    transmission *= mix(vec3(1.0), vec3(0.91, 0.98, 1.02), fresnel * 0.35);
#endif

    // The loader sky is the common colour anchor; avoid a strong fixed blue
    // cast that contradicts sunset, weather, or biome colours.
    vec3 reflectedSky = zephWaterDecode(skyColor) * vec3(0.94, 0.97, 1.0);
    float storm = clamp(rainStrength, 0.0, 1.0);

    // A modest face-on response and stronger grazing response make the
    // transition legible while preserving transparency through the surface.
    float reflectance = mix(0.025, 0.58, fresnel) * (1.0 - storm * 0.35);

#if defined(ZEPH_DIM_NETHER) || defined(ZEPH_DIM_END)
    // Non-Overworld dimensions omit celestial sun/moon specular calculations
    vec3 surface = mix(transmission, reflectedSky, reflectance * 0.65);
    return max(surface, vec3(0.0));
#else
    // Analytical celestial specular highlight. Day/night and world-horizon
    // weights depend only on per-draw uniforms. At their exact zero states,
    // skip the lobe-only half-vector, dot and power chain; its prior result
    // was multiplied by exactly zero.  Keep twilight continuous by testing
    // only the already-clamped, exact-zero uniform weights.
    // Interpolated lightmap skylight is a local proxy, not a visibility test.
    // Gate only sky-derived terms; transmitted block-lit water stays intact.
    reflectance *= skyExposure;
    vec3 sunDir = zephSafeNormalize(sunPosition);
    // The daylight, horizon and twilight weights all project the same sun
    // direction. Reuse that projection without changing its normalization.
    float sunElevation = zephWorldElevation(sunDir);
    float daylight = zephDaylightFromElevation(sunElevation);
    float sunWeight = zephSolarIllumination(sunElevation, storm);
#if ZEPH_EFFECTIVE_WATER_TIER >= 2
    // Tie the grazing reflection to the same broad twilight palette as the
    // sky. The sky colour remains the anchor and storm suppresses warmth.
    float sunset = zephClearTwilight(sunElevation, storm);
    reflectedSky = mix(reflectedSky, reflectedSky * zephTwilightSurfaceTint(1.0), sunset * 0.35);
#endif
#if ZEPH_EFFECTIVE_WATER_TIER == 1
    // Low keeps a broad, bounded daylight sheen without per-fragment
    // half-vector normalization or a second celestial direction. This is an
    // intentionally cheaper response, not the higher-tier specular lobe.
    float facing = max(dot(normal, sunDir), 0.0) * NdotV;
    float sheen = facing * facing * sunWeight * skyExposure;
    vec3 surface = mix(transmission, reflectedSky, reflectance * 0.55);
    return max(surface + vec3(0.10, 0.094, 0.080) * sheen, vec3(0.0));
#else
    vec3 sunSpecular = vec3(0.0);
    if (sunWeight > 0.0 && skyExposure > 0.0) {
        // A light above the world horizon can still lie behind this facet.
        // Local incident cosine makes its contribution vanish continuously
        // at the facet horizon. The half-vector alone cannot enforce this.
        float sunIncidence = max(dot(normal, sunDir), 0.0);
        if (sunIncidence > 0.0 && NdotV > 0.0) {
            vec3 sunHalf = zephSafeNormalize(viewDir + sunDir);
            float sunNdotH = max(dot(normal, sunHalf), 0.0);
            float sunSpecFactor = zephSpecularLobe(sunNdotH) * sunWeight;
            sunSpecular = vec3(1.15, 1.08, 0.92) * (sunSpecFactor * 0.60);
            // Use the same weather-suppressed twilight palette as the sky
            // reflection, rather than retaining a white noon-coloured glint.
            sunSpecular *= mix(vec3(1.0), zephTwilightSurfaceTint(1.0), sunset * 0.65);
            sunSpecular *= sunIncidence;
        }
    }

    vec3 moonSpecular = vec3(0.0);
    if (daylight < 1.0 && skyExposure > 0.0) {
        vec3 moonDir = zephSafeNormalize(moonPosition);
        float moonWeight = zephLunarIllumination(sunElevation, zephWorldElevation(moonDir), storm);
        if (moonWeight > 0.0) {
            float moonIncidence = max(dot(normal, moonDir), 0.0);
            if (moonIncidence > 0.0 && NdotV > 0.0) {
                vec3 moonHalf = zephSafeNormalize(viewDir + moonDir);
                float moonNdotH = max(dot(normal, moonHalf), 0.0);
                float moonSpecFactor = zephSpecularLobe(moonNdotH) * moonWeight;
                moonSpecular = vec3(0.55, 0.68, 0.88) * (moonSpecFactor * 0.25);
                moonSpecular *= moonIncidence;
            }
        }
    }
    vec3 celestialSpecular = sunSpecular + moonSpecular;

    celestialSpecular *= skyExposure;

#if ZEPH_EFFECTIVE_WATER_TIER >= 4
    reflectance = min(reflectance * 1.10, 0.64);
    celestialSpecular *= 1.20;
#endif

    vec3 surface = mix(transmission, reflectedSky, reflectance) + celestialSpecular;
    return max(surface, vec3(0.0));
#endif // tier 1 approximation
#endif // dimension
#endif // water enabled
}

#endif
