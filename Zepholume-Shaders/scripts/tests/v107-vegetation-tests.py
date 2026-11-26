from pathlib import Path
import math
import unittest

ROOT = Path(__file__).resolve().parents[2]

class FoliageTests(unittest.TestCase):
    def test_explicit_nonoverlapping_classification(self):
        entries = {}
        for line in (ROOT/'shaders/block.properties').read_text().splitlines():
            if line.startswith('block.'):
                key, values = line.split('=', 1)
                for value in values.split():
                    self.assertNotIn(value, entries)
                    entries[value] = key
        self.assertEqual(entries['minecraft:water'], 'block.10001')
        self.assertEqual(entries['minecraft:glass'], 'block.10002')
        self.assertEqual(entries['minecraft:ice'], 'block.10003')
        self.assertEqual(entries['minecraft:tall_grass:half=lower'], 'block.10101')
        self.assertEqual(entries['minecraft:tall_grass:half=upper'], 'block.10102')
        self.assertEqual(entries['minecraft:oak_leaves'], 'block.10103')
        self.assertNotIn('minecraft:stone', entries)

    def test_profile_motion_continuity_and_anchors(self):
        # Exercise the two-field equations at the shader modulo, Iris camera
        # rebase and loader time wrap. This is a numerical model.
        source = (ROOT/'shaders/lib/vertex.glsl').read_text()
        for token in ('6.28318530718 / 240.0', 'mod(cameraPosition.xz, 240.0)',
                      '0.900589893', '0.0977384381', '0.30 * gust',
                      'if (weight == 0.0) return p;', '0.85 + 0.15 * gust'):
            self.assertIn(token, source)

        def movement(x, z, t, weight, tier):
            frequency = 6.28318530718 / 240.0
            phase = (x + 2*z) * frequency + t * 0.900589893
            strength = 0.018 if tier == 1 else 0.035 * 1.3
            sway = math.sin(phase)
            if tier >= 2:
                gust = math.sin((2*x-z) * frequency + t * 0.0977384381)
                sway += 0.30 * gust
            sway *= strength * weight
            y = sway * 0.45
            if tier >= 3:
                y += math.sin(phase + 1.570796327) * strength * weight * 0.22
            if tier >= 4:
                envelope = 0.85 + 0.15 * gust
                sway *= envelope
                y *= envelope
            return sway, y

        for tier in (1, 2, 3, 4):
            for x, z, t in ((0, 0, 0), (239.999, -62, 42), (-320, 550, 3599.999)):
                a = movement(x, z, t, 1, tier)
                self.assertLessEqual(math.hypot(*a), 0.07)
                self.assertEqual(movement(x, z, t, 0, tier), (0, 0))
                for b in (movement(x+240, z, t, 1, tier),
                          movement(x, z-240, t, 1, tier),
                          movement(x+30000, z, t, 1, tier),
                          movement(x, z-30000, t, 1, tier),
                          movement(x, z, t+3600, 1, tier)):
                    for actual, expected in zip(a, b):
                        self.assertAlmostEqual(actual, expected, delta=1e-6)
                for actual, expected in zip(a, movement(x, z, t+0.001, 1, tier)):
                    self.assertLess(abs(actual-expected), 0.0001)

        # The old field fails at a live loader rebase, even though its own
        # modulo test used to pass.
        old_frequency = math.tau / 256
        self.assertGreater(abs(math.sin(30000 * old_frequency)) * 0.018, 0.01)
        self.assertNotEqual(movement(0, 0, 0, 1, 3), movement(0, 0, 0, 1, 4))

    def test_compile_time_and_program_isolation(self):
        source=(ROOT/'shaders/lib/vertex.glsl').read_text()
        self.assertIn('defined(ZEPH_TERRAIN_PROGRAM) && ZEPH_EFFECTIVE_PROFILE_TIER > 0',source)
        self.assertIn('mc_midTexCoord', source)
        self.assertIn('viewPosition = zephMoveFoliage(viewPosition);', source)
        self.assertIn('(gbufferModelViewInverse * p).xz', source)
        self.assertIn('gbufferModelView[0].xyz * movement.x + gbufferModelView[2].xyz * movement.y', source)
        for f in (ROOT/'shaders').rglob('gbuffers_terrain.vsh'):
            self.assertIn('#define ZEPH_TERRAIN_PROGRAM',f.read_text())
            self.assertIn('#define ZEPH_TERRAIN_PROGRAM',f.with_suffix('.fsh').read_text())
        self.assertNotIn('ZEPH_TERRAIN_PROGRAM',(ROOT/'shaders/gbuffers_water.vsh').read_text())

if __name__ == '__main__':
    unittest.main()
