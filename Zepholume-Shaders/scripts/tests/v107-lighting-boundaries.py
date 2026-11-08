"""Run production lighting GLSL on a native GL fixture; no Minecraft launch."""
import ctypes as C
import importlib.util
import json
import math
from pathlib import Path
import sys

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('water_spec', Path(__file__).with_name('v107-water-specular.py'))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
common = (root / 'shaders/lib/common.glsl').read_text(encoding='utf-8-sig')
lighting = (root / 'shaders/lib/lighting.glsl').read_text(encoding='utf-8-sig')
marker = 'return mix(1.0, rawCelestial, zephSceneSkyWeight(lightCoord));'
assert lighting.count(marker) == 1

class Fixture(mod.NativeFixture):
    def program(self, quality, dimension):
        key = quality, dimension
        if key in self.programs:
            return self.programs[key]
        defines = f'#define ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY {quality}\n'
        if dimension != 'Overworld':
            defines += f'#define ZEPH_DIM_{dimension.upper()}\n'
        source = ('#version 330 compatibility\n' + defines + self.common + self.water +
                  '\nuniform vec3 fixtureNormal; uniform vec3 fixtureView; uniform float rainStrength;\n'
                  'void main(){gl_FragData[0]=vec4(zephApplySceneLighting(vec3(0.4), fixtureNormal, fixtureView.xy, rainStrength),0.75);}')
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

def run(source):
    fixture = Fixture(common, source)
    try:
        rows = []
        for quality in range(4):
            for dim in ('Overworld', 'Nether', 'End'):
                for block, sky in ((0., 0.), (1., 0.), (0., 1.), (1., 1.)):
                    case = dict(tier=quality, dimension=dim, normal=(0., -1., 0.),
                                view=(block, sky, 0.), sun=(0., 1., 0.),
                                moon=(0., -1., 0.), rain=0.)
                    pixel = fixture.draw(case)
                    assert all(math.isfinite(c) and 0 <= c <= 1 for c in pixel)
                    rows.append((quality, dim, block, sky, pixel))
        return rows, fixture.driver
    finally:
        fixture.close()

rows, driver = run(lighting)
mutated, _ = run(lighting.replace(marker, 'return rawCelestial;'))
for quality, dim, block, sky, pixel in rows:
    if dim == 'Overworld' and sky == 0. and block == 0.:
        assert max(abs(c - 0.4) for c in pixel) < 1e-6
controls = [row for row in mutated if row[0] > 0 and row[1] == 'Overworld' and row[2:4] == (0., 0.)]
assert all(max(abs(c - 0.4) for c in row[4]) > 0.01 for row in controls)
print(json.dumps(dict(native_draws=len(rows), programs=12, mutation_draws=len(mutated),
                      cave_controls_rejected=len(controls), driver=driver)))

# Execute the production weight helper directly, independently of block tint.
class WeightFixture(Fixture):
    def program(self, quality, dimension):
        key = quality, dimension
        if key in self.programs:
            return self.programs[key]
        source = ('#version 330 compatibility\n#define ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY 2\n' +
                  self.common + self.water +
                  '\nuniform vec3 fixtureNormal; uniform vec3 fixtureView; uniform float rainStrength;\n'
                  'void main(){gl_FragData[0]=vec4(vec3(zephSceneSkyWeight(fixtureView.xy)),0.75);}')
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

fixture = WeightFixture(common, lighting)
try:
    def weight(block, sky):
        return fixture.draw(dict(tier=2, dimension='Overworld', normal=(0., 1., 0.),
                                 view=(block, sky, 0.), sun=(0., 1., 0.),
                                 moon=(0., -1., 0.), rain=0.))[0]
    assert abs(weight(0., 0.)) < 1e-6
    assert abs(weight(1., 0.)) < 1e-6
    assert 0.0 < weight(1., 1.) < weight(0., 1.) <= 1.0
finally:
    fixture.close()
print('PASS: production sky weight stays zero in caves and decreases with block light')