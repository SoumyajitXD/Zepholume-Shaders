"""Native source-derived fog boundary tests; no Minecraft installation involved."""
import ctypes as C
import importlib.util
import json
import math
from pathlib import Path
import sys

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('fixture', Path(__file__).with_name('v107-water-specular.py'))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
common = (root / 'shaders/lib/common.glsl').read_text(encoding='utf-8-sig')
atmosphere = (root / 'shaders/lib/atmosphere.glsl').read_text(encoding='utf-8-sig')
fog = (root / 'shaders/lib/fog.glsl').read_text(encoding='utf-8-sig').replace('#include "/lib/atmosphere.glsl"', atmosphere)


class Fixture(mod.NativeFixture):
    def program(self, tier, dimension):
        key = tier, dimension
        if key in self.programs:
            return self.programs[key]
        defines = f'#define ZEPH_EFFECTIVE_PROFILE_TIER {tier}\n#define ZEPH_EFFECTIVE_ATMOSPHERE_QUALITY {int(tier > 0)}\n'
        if dimension != 'Overworld':
            defines += f'#define ZEPH_DIM_{dimension.upper()}\n'
        uniforms = '''uniform vec3 fixtureNormal; uniform vec3 fixtureView;
uniform vec3 sunPosition; uniform float rainStrength;
#define fogStart fixtureNormal.y
#define fogEnd fixtureNormal.z
#define fogColor vec3(0.25, 0.5, 0.75)
#define nightVision fixtureView.y
#define isEyeInWater int(fixtureView.z)
'''
        source = ('#version 330 compatibility\n' + defines + common + uniforms + self.water +
                  '\nvoid main(){vec3 colour=zephFogColour(vec3(0,0,1)); '
                  'float factor=zephFogFactor(fixtureNormal.x,fixtureView.x); '
                  'gl_FragData[0]=vec4(factor,colour.r,colour.g,0.75);}')
        stages = []
        for code, stage in ((source, 'fsh'), ('#version 330 compatibility\nvoid main(){gl_Position=gl_Vertex;}', 'vsh')):
            shader, ok, log = self.gl.compile(code.encode(), stage)
            self.shaders.append(shader)
            assert ok, log
            stages.append(shader)
        program = self.gl.create_program()
        self.programs[key] = program
        for shader in stages:
            self.gl.attach_shader(program, shader)
        self.gl.link_program(program)
        ok = C.c_int()
        self.gl.get_program_iv(program, 0x8B82, C.byref(ok))
        assert ok.value, self.gl.log(program, False)
        return program


def exercise(source, mutation=False):
    fixture = Fixture(common, source)
    count = errors = 0
    try:
        for tier in range(5):
            for dim in ('Overworld', 'Nether', 'End'):
                for medium in range(4):
                    for start, end in ((0., 10.), (1., 1.0001), (1., 1.), (2., 1.)):
                        for distance in (start - 0.25, start, end, end + 0.25):
                            for elevation, rain in ((-1., 0.), (0., 0.5), (1., 1.)):
                                case = dict(tier=tier, dimension=dim, normal=(distance, start, end),
                                            view=(elevation, 0., medium), sun=(0., 1., 0.),
                                            moon=(0., -1., 0.), rain=rain)
                                factor, red, green = fixture.draw(case)
                                count += 1
                                assert all(math.isfinite(v) and 0. <= v <= 1. for v in (factor, red, green))
                                if end > start:
                                    expected = 0. if distance <= start else 1. if distance >= end else None
                                else:
                                    expected = float(distance >= start)
                                if expected is not None and abs(factor - expected) > 2e-5:
                                    errors += 1
                                if medium >= 2 or (medium == 1 and tier == 0):
                                    assert abs(red - 0.25) < 1e-6 and abs(green - 0.5) < 1e-6
        assert errors > 0 if mutation else errors == 0, f'endpoint failures: {errors}'
        return count, errors, fixture.driver
    finally:
        fixture.close()


draws, failures, driver = exercise(fog)
marker = 'return zephSaturate(curved * (density + (1.0 - density) * curved));'
assert fog.count(marker) == 1
control_draws, control_failures, _ = exercise(fog.replace(marker, 'return zephSaturate(curved * density);'), True)
print(json.dumps(dict(native_draws=draws, failures=failures, programs=15,
                      mutation_draws=control_draws, mutation_endpoint_failures=control_failures,
                      driver=driver, minecraft='NOT TESTED')))
