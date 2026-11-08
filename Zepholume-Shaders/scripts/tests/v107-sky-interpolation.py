"""Source-bound sky interpolation checks; synthetic, not Minecraft geometry."""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def safe(v):
    length = math.sqrt(max(sum(x*x for x in v), 1e-8))
    return tuple(x / length for x in v)

def dot(a, b):
    return sum(x*y for x,y in zip(a,b))

def mix(a, b, t):
    return tuple(x*(1-t)+y*t for x,y in zip(a,b))

def rotate(v, a):
    x,y,z = v
    return (x, y*math.cos(a)-z*math.sin(a), y*math.sin(a)+z*math.cos(a))

def validate(v, f):
    assert 'zephSkyViewPosition = viewPosition.xyz;' in v
    assert 'varying vec3 zephSkyViewPosition;' in v and 'varying vec3 zephSkyViewPosition;' in f
    assert 'skyDir = zephSafeNormalize(zephSkyViewPosition);' in f
    assert 'dot(skyDir, zephWorldUpView())' in f
    assert 'zephSkyDirection' not in v+f and 'zephSkyUp' not in v+f

v = (ROOT / 'shaders/lib/sky_vertex.glsl').read_text(encoding='utf-8')
f = (ROOT / 'shaders/lib/sky_fragment.glsl').read_text(encoding='utf-8')
validate(v, f)
try:
    validate(v.replace('zephSkyViewPosition = viewPosition.xyz;', 'zephSkyViewPosition = normalize(viewPosition.xyz);'), f)
except AssertionError:
    pass
else:
    raise AssertionError('Vertex-normalization mutation escaped')

count = 0
max_old_angle = max_old_up = max_new_delta = max_reconstruction = 0.0
# Equal-radius and unequal-radius planar quads, rotated with their world-up vector.
for x,y,w,h,z in [(-1,-1,2,2,4),(-3,-1,4,2,4),(-0.001,-0.002,0.003,0.004,0.01),(-30000,-10000,40000,20000,40000),(-2,-0.01,3,0.02,3)]:
    vertices = [(x,y,z),(x+w,y,z),(x+w,y+h,z),(x,y+h,z)]
    for angle in (-0.3,0.0,0.35):
        p = [rotate(q,angle) for q in vertices]
        up = rotate((0,1,0),angle)
        assert min(q[2] for q in p) > 0
        expected = mix(p[0],p[2],0.5)
        results, old, old_up = [], [], []
        for a,b in ((0,2),(1,3)):
            # Screen-space coordinate of the projected 3D midpoint.
            t = p[b][2] / (p[a][2]+p[b][2])
            wa,wb = (1-t)/p[a][2], t/p[b][2]
            q = mix(p[a],p[b],wb/(wa+wb))
            results.append(safe(q))
            old.append(safe(mix(safe(p[a]),safe(p[b]),wb/(wa+wb))))
            old_up.append((dot(safe(p[a]),up)+dot(safe(p[b]),up))*0.25+0.5)
            max_reconstruction = max(max_reconstruction, max(abs(i-j) for i,j in zip(q,expected)))
        max_new_delta = max(max_new_delta, math.sqrt(sum((a-b)**2 for a,b in zip(*results))))
        max_old_angle = max(max_old_angle, math.degrees(math.acos(max(-1,min(1,dot(*old))))))
        max_old_up = max(max_old_up, abs(old_up[0]-old_up[1]))
        assert max(abs(a-b) for a,b in zip(results[0],safe(expected))) < 1e-12
        count += 1
for p in ((0,0,0),(1e-12,-1e-12,0),(1e-5,1e-5,1e-5)):
    assert all(math.isfinite(x) for x in safe(p))
assert max_new_delta < 1e-12 and max_old_angle > 1 and max_old_up > 0.01
print(json.dumps({'status':'PASS','cases':count,'old_max_diagonal_angle_degrees':max_old_angle,
    'old_max_elevation_coordinate_delta':max_old_up,'new_max_diagonal_direction_delta':max_new_delta,
    'max_position_reconstruction_error':max_reconstruction,'rejected_mutations':1,
    'geometry':'synthetic planar quads; actual game geometry not verified'},indent=2))
