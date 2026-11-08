# Offline underwater and two-sided water numerical contracts; not gameplay.
import math
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]

def sat(x): return min(1.0, max(0.0, x))
def smooth_range(d, start, end):
    x = (float(d >= start) if end <= start else sat((d-start)/(end-start)))
    return x*x*(3-2*x)
def underwater(colour, fog, d, start, end, sky, day, rain, vision):
    d = max(d, 0.0)
    near = d/(d+4)
    f = smooth_range(d, start, end)
    v = sat(vision)
    optical = min(d,1024)/max(abs(end),1)*(1-.55*v)
    trans = [x/(1+optical*c) for x,c in zip(colour,(.70,.28,.19))]
    illum = sat(sky)*(.48+.4*sat(day))*(1-.18*sat(rain))
    ambient = [x*illum*(k*(1-.45*v)+.45*v) for x,k in zip(fog,(.88,.98,1))]
    haze = near*sat(f+(1-f)*near*.25)*(1-.35*v)
    return [a*(1-haze)+b*haze for a,b in zip(trans,ambient)]

class WaterIntegration(unittest.TestCase):
    def test_range_endpoints_continuity_and_degenerate(self):
        self.assertEqual(smooth_range(0,10,100),0)
        self.assertEqual(smooth_range(100,10,100),1)
        self.assertEqual(smooth_range(9,10,10),0)
        self.assertEqual(smooth_range(10,10,10),1)
        for x in (10, 100):
            self.assertLess(abs(smooth_range(x+1e-4,10,100)-smooth_range(x-1e-4,10,100)),1e-9)
    def test_underwater_limits_and_vision(self):
        for d in (0,1e-9,1,50,100,1024,1e12):
            for vision in (0,.5,1):
                out=underwater((.6,.4,.2),(.1,.2,.3),d,10,100,0,0,1,vision)
                self.assertTrue(all(math.isfinite(x) and 0<=x<=1 for x in out))
            if d>0:
                base=underwater((.6,.4,.2),(.1,.2,.3),d,10,100,0,0,1,0)
                enhanced=underwater((.6,.4,.2),(.1,.2,.3),d,10,100,0,0,1,1)
                self.assertTrue(all(a<=b for a,b in zip(base,enhanced)))
        self.assertEqual(underwater((.6,.4,.2),(.1,.2,.3),0,10,100,0,0,1,1),[.6,.4,.2])
        self.assertEqual(underwater((0,0,0),(.1,.2,.3),50,10,100,0,1,0,0),[0,0,0])
    def test_two_sided_fresnel_and_source_routing(self):
        for n in (0,.1,.5,1):
            self.assertEqual((1-abs(n))**5,(1-abs(-n))**5)
        water=(ROOT/'shaders/lib/water.glsl').read_text()
        frag=(ROOT/'shaders/lib/fragment.glsl').read_text()
        under=(ROOT/'shaders/lib/underwater.glsl').read_text()
        self.assertIn('abs(signedNdotV)',water)
        self.assertIn('zephIsWater > 0.5',frag)
        self.assertIn('if (isEyeInWater == 1)',frag)
        self.assertIn('defined(ZEPH_DIM_NETHER) || defined(ZEPH_DIM_END)',under)
        self.assertIn('#if ZEPH_EFFECTIVE_PROFILE_TIER > 0',under)
        self.assertIn('#if ZEPH_EFFECTIVE_PROFILE_TIER > 0\n    loaderFog = loaderFog * loaderFog', under)

if __name__ == '__main__': unittest.main()
