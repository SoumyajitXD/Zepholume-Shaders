"""Numerical continuity and source contracts; does not substitute for gameplay."""
import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def slope(x, z, t, distance, tier):
    phase = math.tau / 256
    time = math.tau / 3600
    a = (3*x + 2*z)*phase + t*time*300
    b = (-7*x + 11*z)*phase - t*time*390
    def fade(lo, hi):
        p = min(1, max(0, (distance-lo)/(hi-lo)))
        return 1-p*p*(3-2*p)
    sx = 3*math.cos(a)*.018 - 7*math.cos(b)*.006*fade(35,110)
    sz = 2*math.cos(a)*.018 + 11*math.cos(b)*.006*fade(35,110)
    if tier >= 3:
        c = (13*x + 5*z)*phase + t*time*510
        sx += 13*math.cos(c)*.004*fade(22,75)
        sz += 5*math.cos(c)*.004*fade(22,75)
    return sx, sz


class WaterRippleContract(unittest.TestCase):
    def test_periodic_position_and_time(self):
        for tier in (2, 3, 4):
            for d in (0, 40, 120):
                original = slope(13.2, -7.9, 41, d, tier)
                for other in (slope(269.2, -7.9, 41, d, tier),
                              slope(13.2, 248.1, 41, d, tier),
                              slope(13.2, -7.9, 3641, d, tier)):
                    for a, b in zip(original, other):
                        self.assertAlmostEqual(a, b, places=12)

    def test_finite_bounded_and_profile_detail(self):
        for x in range(-32, 33, 4):
            for t in range(0, 3600, 300):
                for tier in (2, 3):
                    self.assertLess(math.hypot(*slope(x, 2*x, t, 0, tier)), .25)
        self.assertNotEqual(slope(3, 4, 30, 0, 2), slope(3, 4, 30, 0, 3))
        self.assertEqual(slope(3, 4, 30, 120, 2), slope(3, 4, 30, 120, 3))

    def test_source_gates(self):
        water = (ROOT/'shaders/lib/water.glsl').read_text()
        vertex = (ROOT/'shaders/lib/vertex.glsl').read_text()
        self.assertIn('if (top <= 0.0) return normal;', water)
        self.assertIn('reflectance *= skyExposure;', water)
        self.assertIn('celestialSpecular *= skyExposure;', water)
        self.assertIn('ZEPH_EFFECTIVE_WATER_WAVES == 1', water)
        self.assertIn('if (zephIsWater > 0.5)', vertex)
        self.assertIn('waterWorld', vertex)


if __name__ == '__main__':
    unittest.main()
