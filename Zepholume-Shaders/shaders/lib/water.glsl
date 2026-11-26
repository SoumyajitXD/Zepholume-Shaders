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
#if (defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1)
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
#endif

// A 240-block domain divides the legacy cameraPosition 30,000-block
// rebase. Integer harmonics meet across both modulo and loader seams.
const float zephWaterPhaseScale = 0.02617993878; // 2 pi / 240
// Integer cycles over 3600 seconds keep the loader's time-counter wrap smooth.
#if defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1
vec2 zephWaterPhasePosition(vec3 viewPosition) {
    return (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xz + mod(cameraPosition.xz, 240.0);
}
#endif

vec4 zephMoveWater(vec4 p, vec2 world) {
#if ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1
    // A broad swell moves every vertex, including sides, by the same field so
    // shared waterfall edges stay joined. Fine detail is shading-only.
    float phase = dot(world, vec2(3.0, 2.0)) * zephWaterPhaseScale + frameTimeCounter * 0.5235987756;
    p.y += sin(phase) * 0.025;
#endif
    return p;
}

#if !defined(ZEPH_DIM_NETHER) && defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1
// Fragment-space analytic ripples break up the reflection independently of
// the coarse block mesh. Facet normals gate the field off vertical waterfalls;
// distance fades the fine scales before they can alias into the horizon.
vec3 zephWaterRippleNormal(vec3 normal, vec3 viewDirection, float distance, float exposure) {
    float upward = zephWorldElevation(normal);
    float top = smoothstep(0.82, 0.96, upward);
    if (top <= 0.0) return normal;
    vec2 world = zephWaterPhasePosition(-viewDirection);
    float t = frameTimeCounter * 0.001745329252;
    float broad = dot(world, vec2(3.0, 2.0)) * zephWaterPhaseScale + t * 300.0;
    vec2 slope = vec2(3.0, 2.0) * (cos(broad) * 0.018);
    if (distance < 110.0) {
        float ripple = dot(world, vec2(-7.0, 11.0)) * zephWaterPhaseScale - t * 390.0;
        slope += vec2(-7.0, 11.0) * (cos(ripple) * 0.006 * (1.0 - smoothstep(35.0, 110.0, distance)));
    }
#if ZEPH_EFFECTIVE_WATER_TIER >= 3
    if (distance < 75.0) {
        float crossRipple = dot(world, vec2(13.0, 5.0)) * zephWaterPhaseScale + t * 510.0;
        slope += vec2(13.0, 5.0) * (cos(crossRipple) * 0.004 * (1.0 - smoothstep(22.0, 75.0, distance)));
    }
#endif
    vec3 perturb = mat3(gbufferModelView) * vec3(-slope.x, 0.0, -slope.y);
    return zephSafeNormalize(normal + perturb * (top * exposure));
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
    // Preserve biome/texture colour and the sampled lightmap. This path also
    // handles fully enclosed water, where no sky term can contribute.
    vec3 transmission = zephWaterDecode(displayColour) * vec3(0.88, 0.98, 0.96);
#if defined(ZEPH_DIM_NETHER)
    // Vanilla Nether has no skylight. Skip the sky model for the dimension.
    return transmission;
#else
    if (skyExposure <= 0.0) return transmission;

    vec3 viewDir = zephSafeNormalize(viewDirection);
#if defined(ZEPH_WATER_PROGRAM) && ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1
    // Fade the shading-only ripple with exposure so the cutoff has no seam.
    normal = zephWaterRippleNormal(normal, viewDirection, distance, skyExposure);
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

#if ZEPH_EFFECTIVE_WATER_TIER >= 2
    // Let the reflected sky drive the angular colour cue. Keep the change
    // continuous at zero exposure and preserve the transmitted light there.
    transmission *= mix(vec3(1.0), vec3(0.91, 0.98, 1.02), fresnel * skyExposure * 0.35);
#endif

    // The loader sky is the common colour anchor; avoid a strong fixed blue
    // cast that contradicts sunset, weather, or biome colours.
    vec3 reflectedSky = zephWaterDecode(skyColor) * vec3(0.94, 0.97, 1.0);
    float storm = clamp(rainStrength, 0.0, 1.0);

    // A modest face-on response and stronger grazing response make the
    // transition legible while preserving transparency through the surface.
    // Skylight is a local exposure proxy, not a visibility test. Gate the
    // dimension sky before replacing transmitted colour.
    float reflectance = mix(0.025, 0.58, fresnel) * (1.0 - storm * 0.35);
    reflectance *= skyExposure;

#if defined(ZEPH_DIM_END)
    // The End omits celestial sun/moon specular calculations
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
    vec3 sunDir = zephSafeNormalize(sunPosition);
    // The daylight, horizon and twilight weights all project the same sun
    // direction. Reuse that projection without changing its normalization.
    vec3 worldUp = zephWorldUpView();
    float sunElevation = dot(sunDir, worldUp);
    float daylight = zephDaylightFromElevation(sunElevation);
    float sunWeight = zephSolarIllumination(sunElevation, storm);
    // skyColor describes the upper sky. Attenuate the indirect reflection
    // across twilight, independently of direct moon light and block light.
    reflectedSky *= mix(0.52, 1.0, daylight);
#if ZEPH_EFFECTIVE_WATER_TIER >= 2
    float sunset = zephClearTwilight(sunElevation, storm);
    vec3 reflectedDirection = reflect(-viewDir, normal);
    // Warm the reflection only around the horizon on the sunward side.
    // Sky chroma remains loader-anchored and the tint preserves black.
    float reflectedElevation = dot(reflectedDirection, worldUp);
    float reflectedHorizon = 1.0 - smoothstep(0.0, 0.55, abs(reflectedElevation));
    float reflectedSunward = zephSaturate(dot(reflectedDirection, sunDir) * 0.5 + 0.5);
    reflectedSky *= mix(vec3(1.0), zephTwilightSurfaceTint(reflectedSunward), sunset * reflectedHorizon * 0.45);
#if ZEPH_EFFECTIVE_WATER_TIER >= 3
    // Distinguish the flatter, softer horizon reflection from the upper
    // dome in clear air. Ultra extends this response without a brighter glint.
    float upperSky = smoothstep(0.05, 0.75, reflectedElevation);
#if ZEPH_EFFECTIVE_WATER_TIER >= 4
    const float domeStrength = 0.30;
#else
    const float domeStrength = 0.18;
#endif
    reflectedSky *= mix(vec3(1.0), vec3(0.80, 0.94, 1.0),
                        upperSky * daylight * (1.0 - storm) * domeStrength);
#endif
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
    if (sunWeight > 0.0) {
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
    if (daylight < 1.0) {
        vec3 moonDir = zephSafeNormalize(moonPosition);
        float moonWeight = zephLunarIllumination(sunElevation, dot(moonDir, worldUp), storm);
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

    vec3 surface = mix(transmission, reflectedSky, reflectance) + celestialSpecular;
    return max(surface, vec3(0.0));
#endif // tier 1 approximation
#endif // End or Overworld
#endif // exposed water
#endif // water enabled
}

#endif
