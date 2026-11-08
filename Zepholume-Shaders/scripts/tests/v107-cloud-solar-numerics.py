"""Check mathematical invariance of interpolating a draw-uniform cloud weight.

CPU double precision only; this does not model rasterizer or GPU precision.
Production shader execution is covered separately by the synthetic GLSL suite.
"""
import math
import random


def norm(v):
    scale = 1.0 / math.sqrt(max(sum(x*x for x in v), 1e-8))
    return tuple(x*scale for x in v)


def weights(sun, up):
    # The original cloud path normalizes the sun and then invokes the bounded
    # world-elevation helper, which normalizes its input a second time.
    d = sum(a*b for a, b in zip(norm(norm(sun)), norm(up)))
    t = min(1.0, max(0.0, (d + 0.16) / 0.34))
    return (t*t*(3.0 - 2.0*t), min(1.0, max(0.0, d*0.5 + 0.5)))


def main():
    rng = random.Random(107)
    directions = [(0.0, 0.0, 0.0), (0.0, 1e-12, 0.0),
                  (0.0, 1e-5, 0.0), (0.0, -1e-4, 0.0)]
    directions += [tuple(rng.uniform(-1.0, 1.0) for _ in range(3)) for _ in range(10000)]
    max_error = 0.0
    for sun in directions:
        solar = weights(sun, (0.2, 0.9, 0.3))
        # Perspective interpolation of a constant remains constant in exact
        # arithmetic, regardless of triangle shape or barycentric weights.
        a, b = rng.random(), rng.random()
        if a + b > 1.0:
            a, b = 1.0-a, 1.0-b
        bary = (a, b, 1.0-a-b)
        reciprocal_w = (0.1, 1.0, 10.0)
        denom = sum(x*y for x, y in zip(bary, reciprocal_w))
        for expected in solar:
            actual = sum(x*y*expected for x, y in zip(bary, reciprocal_w)) / denom
            assert math.isfinite(actual) and 0.0 <= actual <= 1.0 + 1e-15
            max_error = max(max_error, abs(actual - expected))
    assert max_error < 1e-12
    print(f"PASS {len(directions)} sun vectors; max interpolation error {max_error:.3g} (CPU double)")


if __name__ == "__main__":
    main()
