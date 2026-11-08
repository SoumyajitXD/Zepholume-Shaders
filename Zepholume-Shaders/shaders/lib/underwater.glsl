#ifndef ZEPHO_UNDERWATER_GLSL
#define ZEPHO_UNDERWATER_GLSL
// A bounded view-distance approximation: neither water-column depth nor the
// surface intersection is available in this single-pass pipeline. Loader fog
// remains the biome-colour anchor. No textures, history, or depth buffer.
vec3 zephUnderwater(vec3 colour, float distance, vec2 lightCoord) {
    float d = max(distance, 0.0);
    // Near geometry stays close to its original appearance at the interface.
    float nearFade = d / (d + 4.0);
    float fogRange = fogEnd - fogStart;
    float loaderFog = fogRange <= 0.0 ? (d >= fogStart ? 1.0 : 0.0)
        : zephSaturate((d - fogStart) / fogRange);
    // Ease the loader-range boundaries without extra samples. The two
    // endpoints remain exact while slope changes no longer make visible bands.
#if ZEPH_EFFECTIVE_PROFILE_TIER > 0
    loaderFog = loaderFog * loaderFog * (3.0 - 2.0 * loaderFog);
#endif
#if ZEPH_EFFECTIVE_PROFILE_TIER == 0
    float attenuation = nearFade * 0.18;
    vec3 transmitted = colour * (1.0 - attenuation);
    vec3 ambient = fogColor * zephSaturate(lightCoord.y);
#else
    // Rational attenuation avoids exponentials and stays finite for large d.
    float vision = zephSaturate(nightVision);
    // Night vision reduces both absorption and haze rather than only their
    // hue; it never removes the medium completely.
    float optical = min(d, 1024.0) / max(abs(fogEnd), 1.0);
    optical *= 1.0 - 0.55 * vision;
#if ZEPH_EFFECTIVE_PROFILE_TIER == 1
    vec3 transmitted = colour * (1.0 / (1.0 + optical * 0.35));
#else
    vec3 transmitted = colour / (vec3(1.0) + optical * vec3(0.70, 0.28, 0.19));
#endif
    // Sky light is a local surface proxy, not water depth. Gate atmospheric
    // colour in caves; retain block-lit detail through transmitted colour.
    float sky = zephSaturate(lightCoord.y);
    // Celestial elevation and rain describe the Overworld only. Other
    // dimensions use neutral illumination anchored by their loader fog.
#if defined(ZEPH_DIM_NETHER) || defined(ZEPH_DIM_END)
    float daylight = 0.5;
    float weather = 0.0;
#else
    float daylight = zephDaylightFromDirection(sunPosition);
    float weather = zephSaturate(rainStrength);
#endif
    float illumination = sky * mix(0.48, 0.88, daylight) * (1.0 - 0.18 * weather);
    vec3 ambient = fogColor * vec3(0.88, 0.98, 1.0) * illumination;
    ambient = mix(ambient, fogColor * illumination, vision * 0.45);
#endif
    // Loader endpoint dominates at distance; the fade also bounds the
    // transition for fragments close to a water/air interface.
    float haze = nearFade * zephSaturate(loaderFog + (1.0 - loaderFog) * nearFade * 0.25);
#if ZEPH_EFFECTIVE_PROFILE_TIER > 0
    haze *= 1.0 - 0.35 * vision;
#endif
    return mix(transmitted, ambient, haze);
}
#endif
