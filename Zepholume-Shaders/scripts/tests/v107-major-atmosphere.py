"""Numerical checks for the original analytic horizon and twilight terms.

CPU model of bounded weights, not a visual or loader test.
"""
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parents[2]


def sat(x):
    return max(0.0, min(1.0, x))


def smoothstep(a, b, x):
    t = sat((x - a) / (b - a))
    return t * t * (3.0 - 2.0 * t)


def weights(up, sun_dot, daylight, twilight, storm, tier):
    altitude = sat((up - 0.5) * 2.0)
    gradient = smoothstep(0.08, 0.95, altitude)
    horizon = 1.0 - smoothstep(0.0, 0.38, altitude)
    side = sat(sun_dot * 0.5 + 0.5)
    clear = twilight * (1.0 - storm)
    warm = clear * horizon * side * side * 0.58
    arch = smoothstep(0.02, 0.16, altitude) * (1.0 - smoothstep(0.28, 0.65, altitude))
    cool = clear * arch * (1.0 - side) ** 2 * 0.30 if tier >= 2 else 0.0
    haze = sat(sun_dot) ** 4 * daylight * (1.0 - storm) * 0.14 if tier >= 3 else 0.0
    return gradient, warm, cool, haze


def main():
    sky = (ROOT / 'shaders/lib/sky_fragment.glsl').read_text(encoding='utf-8')
    fog = (ROOT / 'shaders/lib/fog.glsl').read_text(encoding='utf-8')
    for token in ('smoothstep(0.0, 0.38, altitude)', 'twilight * (1.0 - zephSaturate(storm))',
                  'horizonLayer * sunward * sunward', 'clearTwilight * warmBand * 0.58',
                  'smoothstep(0.02, 0.16, altitude)', 'haze *= haze;',
                  '#if ZEPH_EFFECTIVE_PROFILE_TIER >= 3'):
        assert token in sky, token
    for token in ('if (isEyeInWater >= 2) return fogColor;',
                  'towardSun * towardSun', '#if ZEPH_EFFECTIVE_PROFILE_TIER >= 2'):
        assert token in fog, token
    count = 0
    for tier in range(1, 5):
        for daylight in (0.0, 0.5, 1.0):
            for twilight in (0.0, 0.5, 1.0):
                for storm in (0.0, 0.5, 1.0):
                    for dot in (-1.0, -0.5, 0.0, 0.5, 1.0):
                        rows = [weights(i / 200, dot, daylight, twilight, storm, tier)
                                for i in range(201)]
                        for row in rows:
                            assert all(math.isfinite(v) and 0.0 <= v <= 1.0 for v in row)
                        assert rows[100][0] == 0.0 and rows[-1][0] == 1.0
                        assert all(a[0] <= b[0] for a, b in zip(rows, rows[1:]))
                        assert all(max(abs(x-y) for x,y in zip(a,b)) < 0.05
                                   for a,b in zip(rows, rows[1:]))
                        if storm == 1.0:
                            assert all(row[1:] == (0.0, 0.0, 0.0) for row in rows)
                        count += len(rows)
    toward = weights(0.58, 1.0, 0.5, 1.0, 0.0, 4)
    away = weights(0.58, -1.0, 0.5, 1.0, 0.0, 4)
    assert toward[1] > away[1] and toward[2] < away[2]
    assert weights(0.5, 1.0, 1, 1, 0, 1)[2:] == (0.0, 0.0)
    assert weights(0.5, 1.0, 1, 1, 0, 2)[3] == 0.0
    print(f'PASS: {count} bounded sky-weight samples, horizon continuity, weather and tier gates')


if __name__ == '__main__':
    main()
