"""Bounded numerical contracts for the integrated fog and block-light model."""
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parents[2]
LUMA = (0.2126, 0.7152, 0.0722)


def tint(c, t, weight):
    scale = sum(a*b for a, b in zip(c, LUMA)) / max(sum(a*b for a, b in zip(t, LUMA)), .001)
    return tuple(a * (1-weight) + b * scale * weight for a, b in zip(c, t))


def dominance(block, sky, day, storm):
    effective = sky * (.25 + .75 * day) * (1 - storm * .25)
    return block / (block + effective * .75 + .001)


def main():
    lighting = (ROOT / 'shaders/lib/lighting.glsl').read_text()
    fog = (ROOT / 'shaders/lib/fog.glsl').read_text()
    atmosphere = (ROOT / 'shaders/lib/atmosphere.glsl').read_text()
    assert lighting.count('zephSafeNormalize(sunPosition)') == 1
    assert 'float effectiveSky = skyLight * mix(0.25, 1.0, daylight)' in lighting
    assert 'return zephHazeTint(haze' in fog
    assert 'dot(colour, luma)' in atmosphere
    for c in ((0., 0., 0.), (.01, .01, .01), (.1, .3, .7), (1., 1., 1.)):
        for t in ((.72, .78, .82), (.055, .070, .105), (.82, .48, .32)):
            for i in range(101):
                output = tint(c, t, i/100)
                assert all(math.isfinite(x) and x >= 0 for x in output)
                assert abs(sum(a*b for a, b in zip(c, LUMA)) - sum(a*b for a, b in zip(output, LUMA))) < 1e-12
                if c == (0., 0., 0.):
                    assert output == c
    for sky in (0., .2, .5, 1.):
        for block in (0., .2, .5, 1.):
            previous = None
            for i in range(101):
                value = dominance(block, sky, i/100, .4)
                assert 0 <= value <= 1
                if previous is not None:
                    assert value <= previous + 1e-12
                previous = value
            assert dominance(block, sky, .5, 1) >= dominance(block, sky, .5, 0)
    print('PASS: luminance-preserving fog tint, dark boundaries, solar/weather block-light dominance and shared sun direction')


if __name__ == '__main__':
    main()
