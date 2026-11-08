#ifndef ZEPHO_WEATHER_GLSL
#define ZEPHO_WEATHER_GLSL

vec3 zephWeatherResponse(vec3 linearColour) {
#if ZEPH_EFFECTIVE_WEATHER_QUALITY == 0
    return linearColour;
#else
    // rainStrength is shared by the Iris/Oculus common format. Do not require
    // an Iris-only thunder uniform for the normal forward rendering route.
    float storm = clamp(rainStrength, 0.0, 1.0);
    vec3 neutral = vec3(zephLuminance(linearColour));
    // Compile-time levels retain the same inexpensive single colour blend.
    // Balanced keeps its previous response; higher levels deepen storm mood.
#if ZEPH_EFFECTIVE_WEATHER_QUALITY == 1
    const float weatherBlend = 0.22;
#elif ZEPH_EFFECTIVE_WEATHER_QUALITY == 2
    const float weatherBlend = 0.28;
#else
    const float weatherBlend = 0.34;
#endif
    linearColour = mix(linearColour, neutral * vec3(0.93, 0.96, 1.0), storm * weatherBlend);
    return linearColour;
#endif
}

#endif
