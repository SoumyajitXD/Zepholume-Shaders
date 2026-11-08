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

    def test_field_bounds_and_camera_wrap(self):
        def sway(x, z, t, weight, strength):
            return math.sin((x + 2*z) * (2*math.pi/256) + t*(516*2*math.pi/3600))*strength*weight
        for x in (-1000, -1, 0, 55, 1000):
            for z in (-300, 0, 301):
                for t in (0, 1, 1000):
                    a=sway(x,z,t,1,0.0455)
                    self.assertLessEqual(abs(a), 0.0455)
                    self.assertAlmostEqual(a,sway(x+256,z,t,1,0.0455),places=12)
                    self.assertAlmostEqual(a,sway(x,z+256,t,1,0.0455),places=12)
                    self.assertEqual(sway(x,z,t,0,0.0455),0)
                    self.assertAlmostEqual(sway(x,z,0,1,0.0455), sway(x,z,3600,1,0.0455), places=12)
                    self.assertLess(abs(sway(x,z,t+0.001,1,0.0455)-a),0.000042)

    def test_compile_time_and_program_isolation(self):
        source=(ROOT/'shaders/lib/vertex.glsl').read_text()
        self.assertIn('defined(ZEPH_TERRAIN_PROGRAM) && ZEPH_EFFECTIVE_PROFILE_TIER > 0',source)
        self.assertIn('mc_midTexCoord', source)
        for f in (ROOT/'shaders').rglob('gbuffers_terrain.vsh'):
            self.assertIn('#define ZEPH_TERRAIN_PROGRAM',f.read_text())
        self.assertNotIn('ZEPH_TERRAIN_PROGRAM',(ROOT/'shaders/gbuffers_water.vsh').read_text())

if __name__ == '__main__':
    unittest.main()
