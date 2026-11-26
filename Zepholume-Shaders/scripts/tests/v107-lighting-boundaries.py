"""Run production lighting and terrain material GLSL on a native GL fixture."""
import ctypes as C
import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("water_spec", Path(__file__).with_name("v107-water-specular.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
common = (root / "shaders/lib/common.glsl").read_text(encoding="utf-8-sig")
lighting = (root / "shaders/lib/lighting.glsl").read_text(encoding="utf-8-sig")
materials = (root / "shaders/lib/materials.glsl").read_text(encoding="utf-8-sig")

MIN_UV = 1 / 32
MAX_UV = 31 / 32
DIMS = ("Overworld", "Nether", "End")
LIGHT = "zephApplySceneLighting(fixtureColour, fixtureNormal, fixtureView.xy, rainStrength)"
CASE = dict(tier=2, dimension="Overworld", normal=(0., -1., 0.),
            view=(MIN_UV, MIN_UV, 0.), sun=(0., 1., 0.), moon=(0., -1., 0.),
            colour=(0.4, 0.4, 0.4), rain=0.)


class Fixture(mod.NativeFixture):
    def __init__(self, source, expression):
        super().__init__(common, source)
        self.expression = expression

    def program(self, quality, dimension):
        key = quality, dimension
        if key in self.programs:
            return self.programs[key]
        defines = f"#define ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY {quality}\n"
        if dimension != "Overworld":
            defines += f"#define ZEPH_DIM_{dimension.upper()}\n"
        source = ("#version 330 compatibility\n" + defines + self.common + self.water +
                  "\nuniform vec3 fixtureNormal; uniform vec3 fixtureView; uniform float rainStrength;\n"
                  "uniform vec3 fixtureColour; uniform float fixtureExposure;\n"
                  f"void main(){{gl_FragData[0]=vec4({self.expression},0.75);}}")
        vertex = "#version 330 compatibility\nvoid main(){gl_Position=gl_Vertex;}"
        program = self.gl.create_program()
        self.programs[key] = program
        for code, stage in ((source, "fsh"), (vertex, "vsh")):
            shader, ok, log = self.gl.compile(code.encode(), stage)
            self.shaders.append(shader)
            assert ok, log
            self.gl.attach_shader(program, shader)
        self.gl.link_program(program)
        ok = C.c_int()
        self.gl.get_program_iv(program, 0x8B82, C.byref(ok))
        assert ok.value, self.gl.log(program, False)
        return program


def run(source):
    fixture = Fixture(source, LIGHT)
    try:
        rows = []
        for quality in range(4):
            for dim in DIMS:
                for block, sky in ((MIN_UV, MIN_UV), (MAX_UV, MIN_UV),
                                   (MIN_UV, MAX_UV), (MAX_UV, MAX_UV)):
                    case = dict(CASE, tier=quality, dimension=dim, view=(block, sky, 0.))
                    pixel = fixture.draw(case)
                    assert all(0 <= c <= 1 for c in pixel)
                    rows.append((quality, dim, block, sky, pixel))
        return rows, fixture.driver
    finally:
        fixture.close()


marker = "mix(1.0, rawCelestial, skyWeight)"
assert lighting.count(marker) == 1
rows, driver = run(lighting)
mutated, _ = run(lighting.replace(marker, "rawCelestial"))
for quality, dim, block, sky, pixel in rows:
    if dim == "Overworld" and (block, sky) == (MIN_UV, MIN_UV):
        assert max(abs(c - 0.4) for c in pixel) < 1e-6
controls = [row for row in mutated
            if row[0] > 0 and row[1] == "Overworld" and row[2:4] == (MIN_UV, MIN_UV)]
assert all(max(abs(c - 0.4) for c in row[4]) > 0.01 for row in controls)

fixture = Fixture(lighting, "vec3(zephSceneSkyWeight(fixtureView.xy))")
try:
    def weight(block, sky):
        return fixture.draw(dict(CASE, view=(block, sky, 0.)))[0]
    assert abs(weight(MIN_UV, MIN_UV)) < 1e-6
    assert abs(weight(MAX_UV, MIN_UV)) < 1e-6
    assert abs(weight(MIN_UV, MAX_UV) - 1.0) < 1e-6
    assert 0.0 < weight(MAX_UV, MAX_UV) < weight(MIN_UV, MAX_UV)
finally:
    fixture.close()

fixture = Fixture(lighting, "vec3(zephLightingLevels(fixtureView.xy), 0.0)")
try:
    for level in range(16):
        uv = (2 * level + 1) / 32
        actual = fixture.draw(dict(CASE, view=(uv, uv, 0.)))
        assert max(abs(channel - level / 15) for channel in actual[:2]) < 1e-6
finally:
    fixture.close()

fixture = Fixture(lighting, LIGHT)
try:
    for dim in DIMS:
        for tier in range(4):
            dark = dict(CASE, colour=(0., 0., 0.), dimension=dim, tier=tier)
            assert max(fixture.draw(dark)) < 1e-6
    night = dict(CASE, view=(MIN_UV, MAX_UV, 0.), sun=(0., -1., 0.))
    low_lit = fixture.draw(dict(night, tier=1, moon=(0., -1., 0.)))
    low_away = fixture.draw(dict(night, tier=1, moon=(0., 1., 0.)))
    high_lit = fixture.draw(dict(night, tier=3, moon=(0., -1., 0.)))
    high_away = fixture.draw(dict(night, tier=3, moon=(0., 1., 0.)))
    assert low_lit == low_away
    assert high_lit[1] > high_away[1] + 0.02
    for dim in ("Nether", "End"):
        torch = fixture.draw(dict(CASE, dimension=dim, view=(MAX_UV, MIN_UV, 0.)))
        mixed = fixture.draw(dict(CASE, dimension=dim, view=(MAX_UV, MAX_UV, 0.)))
        assert torch == mixed
finally:
    fixture.close()

defines = "\n#define ZEPH_TERRAIN_PROGRAM\n#define ZEPH_EFFECTIVE_MATERIAL_QUALITY 1\nconst float fogEnd = 64.0;\n"
fixture = Fixture(lighting + defines + materials,
                  "zephMaterialResponse(fixtureColour, fixtureNormal, fixtureView.z, fixtureView.xy, fixtureExposure)")
try:
    exterior = dict(CASE, view=(MIN_UV, MAX_UV, 0.0))
    leaf = fixture.draw(dict(exterior, exposure=1.))
    stone = fixture.draw(dict(exterior, exposure=0.))
    assert leaf[1] > stone[1] + 0.035
    assert fixture.draw(dict(CASE, exposure=1.)) == fixture.draw(dict(CASE, exposure=0.))
    assert max(fixture.draw(dict(exterior, colour=(0., 0., 0.), exposure=1.))) < 1e-6
    for foliage in (0.0, 1.0):
        for normal in ((0., -1., 0.), (0., 1., 0.), (0., 0., 0.)):
            distant = fixture.draw(dict(exterior, view=(MIN_UV, MAX_UV, 64.0), exposure=foliage, normal=normal))
            assert max(abs(channel - 0.4) for channel in distant) < 1e-6
finally:
    fixture.close()

print(json.dumps(dict(bounds_draws=len(rows), mutation_draws=len(mutated), cave_controls_rejected=len(controls),
                      light_level_centres=16, material_draws=11, driver=driver, minecraft_runtime="NOT TESTED")))
