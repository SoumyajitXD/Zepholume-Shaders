#ifndef ZEPHO_WEATHER_GLSL
#define ZEPHO_WEATHER_GLSL

vec3 zephWeatherResponse(vec3 linearColour) {
#if ZEPH_EFFECTIVE_WEATHER_QUALITY == 0
    return linearColour;
#else
    float storm = clamp(max(rainStrength, thunderStrength), 0.0, 1.0);
    vec3 neutral = vec3(zephLuminance(linearColour));
    linearColour = mix(linearColour, neutral * vec3(0.93, 0.96, 1.0), storm * 0.22);
#if ZEPH_EFFECTIVE_WEATHER_QUALITY >= 3
    linearColour += vec3(thunderStrength * 0.045);
#endif
    return linearColour;
#endif
}

#endif
