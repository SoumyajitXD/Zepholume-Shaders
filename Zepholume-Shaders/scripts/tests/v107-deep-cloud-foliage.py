'''Numerical contracts for cloud fog/relief and tiered foliage movement.'''
from math import sin, pi, hypot
from pathlib import Path
root = Path(__file__).resolve().parents[2]
cloud = (root / 'shaders/lib/cloud_fragment.glsl').read_text()
vertex = (root / 'shaders/lib/vertex.glsl').read_text()
assert '0.14 * (cloudField - 0.5)' in cloud
assert '1.0 - 0.20 * cloudFog * cloudFog' in cloud
assert 'sin(zephCloudTexCoord' not in cloud
assert '#if ZEPH_EFFECTIVE_PROFILE_TIER >= 3' in vertex
assert 'sin(phase + 1.570796327)' in vertex
for i in range(101):
    field = i / 100
    for up in (0, .5, 1):
        relief = 1 + .14 * (field-.5) * (.35+.65*up)
        assert .93 - 1e-12 <= relief <= 1.07 + 1e-12
    for alpha in (0, .2, 1):
        fog = field
        out = alpha * (1 - .2*fog*fog)
        assert 0 <= out <= alpha
        assert out >= .8*alpha - 1e-12
for i in range(360):
    phase = 2*pi*i/360
    for weight in (0, .32, 1):
        strength = .0455
        x = sin(phase)*strength*weight
        y = x*.45 + sin(phase+pi/2)*strength*weight*.22
        assert hypot(x,y) <= strength*weight*1.13 + 1e-12
        if weight == 0: assert x == y == 0
        assert abs(sin(phase+516*2*pi)-sin(phase)) < 1e-11
print('PASS: bounded cloud relief and fog alpha; anchored, bounded tiered vegetation motion')
