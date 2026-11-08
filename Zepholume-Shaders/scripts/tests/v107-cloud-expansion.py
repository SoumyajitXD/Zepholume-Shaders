"""Numerical contracts for analytical cloud lighting; no gameplay claims."""
from math import isfinite
from pathlib import Path

f = (Path(__file__).resolve().parents[2] / 'shaders/lib/cloud_fragment.glsl').read_text()
assert '#if ZEPH_EFFECTIVE_CLOUD_QUALITY == 0' in f
assert f.index('#if ZEPH_EFFECTIVE_CLOUD_TIER >= 3') < f.index('float forwardSun')
assert f.index('#if ZEPH_EFFECTIVE_CLOUD_TIER >= 4') < f.index('float relief')
assert '0.14 * (cloudField - 0.5)' in f
assert '(0.35 + 0.65 * zephCloudNormalUp)' in f
assert 'cloud *= relief;' in f
assert 'zephSafeNormalize(zephCloudViewPosition)' in f
assert 'clamp(source.a, 0.0, 1.0)' in f

# Inputs match bounded normalized directions, normal and clamped weather.
for day in (0, .2, .5, .8, 1):
    for rain in (0, .5, 1):
        for up in (0, .5, 1):
            for cos_angle in (-1, -.5, 0, .5, 1):
                sun, moon = max(cos_angle, 0)**4, max(-cos_angle, 0)**4
                terms = [up*(1-rain)*(.14*sun*day + .025*moon*(1-day)),
                         up*(1-rain)*(.11*sun*day + .032*moon*(1-day)),
                         up*(1-rain)*(.08*sun*day + .048*moon*(1-day))]
                assert all(isfinite(x) and 0 <= x <= .14 for x in terms)
                if rain == 1 or up == 0:
                    assert all(x == 0 for x in terms)
                storm = rain * (1-up) * .55
                assert 0 <= storm <= .55
                # Coverage is a mix of bounded fractional cell values; relief
                # reuses that field rather than an independent periodic wave.
                for field in (0, .125, .25, .5, .75, 1):
                    relief = 1 + .14*(field-.5)*(.35+.65*up)
                    assert .93-1e-12 <= relief <= 1.07+1e-12
                    if field == .5:
                        assert relief == 1
print('PASS: cloud analytical-light bounds, storm gates, and coverage relief')
