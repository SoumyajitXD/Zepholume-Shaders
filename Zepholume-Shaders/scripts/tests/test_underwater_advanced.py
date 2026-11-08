"""Numerical contract for the single-pass underwater approximation; not gameplay."""
import math
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


def model(colour, fog, distance, start, end, sky, day, rain, night, tier):
    clamp = lambda x: max(0.0, min(1.0, x))
    d = max(distance, 0.0)
    near = d / (d + 4.0)
    span = end - start
    factor = (1.0 if d >= start else 0.0) if span <= 0 else clamp((d - start) / span)
    if tier > 0:
        factor = factor * factor * (3 - 2 * factor)
    if tier == 0:
        trans = [v * (1 - near * .18) for v in colour]
        ambient = [v * clamp(sky) for v in fog]
    else:
        optical = min(d, 1024.0) / max(abs(end), 1.0) * (1 - .55 * clamp(night))
        coeff = [.35] * 3 if tier == 1 else [.70, .28, .19]
        trans = [v / (1 + optical * c) for v, c in zip(colour, coeff)]
        illumination = (.48 + .40 * clamp(day)) * (1 - .18 * clamp(rain)) * clamp(sky)
        ambient = [f * illumination * (k * (1 - clamp(night) * .45) + clamp(night) * .45)
                   for f, k in zip(fog, [.88, .98, 1.0])]
    haze = near * clamp(factor + (1 - factor) * near * .25)
    if tier > 0:
        haze *= 1 - .35 * clamp(night)
    return [a * (1 - haze) + b * haze for a, b in zip(trans, ambient)]


class UnderwaterContract(unittest.TestCase):
    def test_boundaries_are_finite(self):
        for tier in range(5):
            for d in (0, 1e-12, 1, 64, 1e12):
                for start, end in ((0, 0), (1, 1 + 1e-12), (10, -1), (0, 256)):
                    out = model([.5]*3, [.2]*3, d, start, end, 0, 0, 1, 0, tier)
                    self.assertTrue(all(math.isfinite(x) and 0 <= x <= 1 for x in out))

    def test_near_interface_and_cave_darkness(self):
        original = [.5, .4, .3]
        self.assertEqual(model(original, [.2]*3, 0, 0, 100, 0, 0, 0, 0, 2), original)
        cave = model(original, [.2]*3, 1000, 0, 100, 0, 1, 0, 0, 2)
        open_water = model(original, [.2]*3, 1000, 0, 100, 1, 1, 0, 0, 2)
        self.assertTrue(all(a < b for a, b in zip(cave, open_water)))
        self.assertEqual(model([0]*3, [.5]*3, 100, 0, 10, 0, 0, 0, 0, 2), [0]*3)

    def test_routing_and_compile_gate(self):
        src = (ROOT / 'shaders/lib/fragment.glsl').read_text(encoding='utf-8')
        self.assertIn('#if ZEPH_EFFECTIVE_UNDERWATER_QUALITY > 0', src)
        self.assertIn('if (isEyeInWater == 1)', src)
        self.assertIn('graded = zephUnderwater(', src)


if __name__ == '__main__':
    unittest.main()
