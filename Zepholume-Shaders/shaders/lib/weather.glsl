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
    linearColour = mix(linearColour, neutral * vec3(0.93, 0.96, 1.0), storm * 0.22);
    return linearColour;
#endif
}

#endif
