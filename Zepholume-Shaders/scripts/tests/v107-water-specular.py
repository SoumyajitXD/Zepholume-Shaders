"""Water local-incidence regression; optional native source execution, never Minecraft.

The native path compiles the actual common/water libraries into a one-pixel
RGBA32F fixture. Black albedo and sky isolate celestial specular. An independent
CPU reference checks both the corrected source and the retained pre-fix source.
No third-party Python modules, game files or existing evidence are modified.
"""
import argparse
import ctypes as C
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def norm(a):
    return tuple(x / math.sqrt(max(dot(a, a), 1e-8)) for x in a)


def sat(x):
    return min(max(x, 0.0), 1.0)


def reference(n, v, sun, moon, tier, dimension, rain, corrected=True, current_low=True):
    if tier == 0 or dimension != "Overworld":
        return (0.0, 0.0, 0.0)
    v, sun, moon = map(norm, (v, sun, moon))
    t = sat((sun[1] + 0.16) / 0.34)
    day = t * t * (3 - 2 * t)
    if tier == 1 and current_low:
        facing = max(dot(n, sun), 0.0) * sat(dot(n, v))
        sheen = facing * facing * day * sat(sun[1] * 6 + 0.1) * (1 - sat(rain) * 0.85)
        return tuple(c * sheen for c in (0.10, 0.094, 0.080))
    result = [0.0] * 3
    for light, weight, colour, strength in (
        (sun, day, (1.15, 1.08, 0.92), 0.60),
        (moon, 1 - day, (0.55, 0.68, 0.88), 0.25),
    ):
        weight *= sat(light[1] * 6 + 0.1)
        incidence = max(dot(n, light), 0.0) if corrected else 1.0
        if corrected and dot(n, v) <= 0:
            incidence = 0.0
        h = norm(tuple(a + b for a, b in zip(v, light)))
        ndh = max(dot(n, h), 0.0)
        lobe = ndh ** 64 if tier == 1 else 0.88 * ndh ** 64 + 0.12 * ndh ** 16
        scale = lobe * weight * incidence * strength * (1 - sat(rain) * 0.85)
        scale *= 0.35 if tier == 1 else 1.20 if tier == 4 else 1.0
        result = [a + c * scale for a, c in zip(result, colour)]
    return tuple(result)


def fixtures():
    # Light remains above the WORLD horizon while crossing a vertical facet's
    # LOCAL horizon. At exact local tangent the old half-vector has a lobe.
    cases = []
    for tier in range(5):
        for dimension in ("Overworld", "Nether", "End"):
            for phase in ("sun", "moon"):
                for x in (-0.8, -0.1, -0.001, 0.0, 0.001, 0.1, 0.8):
                    light = norm((x, 0.6, 0.0))
                    opposite = tuple(-a for a in light)
                    sun, moon = (light, opposite) if phase == "sun" else (opposite, light)
                    for side in (1.0, -0.1):
                        # Slightly tilted view maximizes the former tangent lobe.
                        v = norm((side, -0.3, 0.0))
                        cases.append(dict(tier=tier, dimension=dimension, normal=(1.0, 0.0, 0.0),
                                          view=v, sun=sun, moon=moon, rain=0.0))
            # Direct frontal control preserves the former maximum.
            cases.append(dict(tier=tier, dimension=dimension, normal=(0.0, 1.0, 0.0),
                              view=(0.0, 1.0, 0.0), sun=(0.0, 1.0, 0.0), moon=(0.0, -1.0, 0.0), rain=1.0))
    return cases


class NativeFixture:
    def __init__(self, common, water):
        sys.dont_write_bytecode = True
        path = Path(__file__).with_name("native-gl-compile.py")
        spec = importlib.util.spec_from_file_location("zeph_water_native", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.gl = gl = module.WGL()
        self.driver = gl.strings()
        self.common, self.water = common, water
        self.programs = {}
        self.shaders = []
        u, i, f, p = C.c_uint, C.c_int, C.c_float, C.c_void_p
        def legacy(name, restype, *types):
            fn = getattr(gl.gl, name)
            fn.restype, fn.argtypes = restype, types
            return fn
        self.legacy = legacy
        self.use = gl.bind("glUseProgram", None, u)
        self.location = gl.bind("glGetUniformLocation", i, u, C.c_char_p)
        self.uniform3 = gl.bind("glUniform3f", None, i, f, f, f)
        self.uniform1 = gl.bind("glUniform1f", None, i, f)
        self.matrix = gl.bind("glUniformMatrix4fv", None, i, i, C.c_ubyte, C.POINTER(f))
        gen = legacy("glGenTextures", None, i, C.POINTER(u))
        self.texture = u()
        gen(1, C.byref(self.texture))
        legacy("glBindTexture", None, u, u)(0x0DE1, self.texture)
        legacy("glTexImage2D", None, u, i, i, i, i, i, u, u, p)(0x0DE1, 0, 0x8814, 1, 1, 0, 0x1908, 0x1406, None)
        parameter = legacy("glTexParameteri", None, u, u, i)
        parameter(0x0DE1, 0x2801, 0x2600)
        parameter(0x0DE1, 0x2800, 0x2600)
        self.framebuffer = u()
        gl.bind("glGenFramebuffers", None, i, C.POINTER(u))(1, C.byref(self.framebuffer))
        gl.bind("glBindFramebuffer", None, u, u)(0x8D40, self.framebuffer)
        gl.bind("glFramebufferTexture2D", None, u, u, u, u, i)(0x8D40, 0x8CE0, 0x0DE1, self.texture, 0)
        assert gl.bind("glCheckFramebufferStatus", u, u)(0x8D40) == 0x8CD5, "RGBA32F framebuffer incomplete"
        legacy("glViewport", None, i, i, i, i)(0, 0, 1, 1)
        for cap in (0x0BE2, 0x0B71, 0x0B44, 0x0BD0, 0x8DB9):
            legacy("glDisable", None, u)(cap)
        self.begin = legacy("glBegin", None, u)
        self.end = legacy("glEnd", None)
        self.vertex = legacy("glVertex2f", None, f, f)
        self.read = legacy("glReadPixels", None, i, i, i, i, u, u, p)
        self.error = legacy("glGetError", u)
        clear = gl.bind("glClearBufferfv", None, u, i, C.POINTER(f))
        probe = (-0.25, 0.125, 1.25, 0.5)
        clear(0x1800, 0, (f * 4)(*probe))
        rgba = (f * 4)()
        self.read(0, 0, 1, 1, 0x1908, 0x1406, rgba)
        assert max(abs(a - b) for a, b in zip(probe, rgba)) < 1e-6, "float readback invalid"

    def program(self, tier, dimension):
        key = tier, dimension
        if key in self.programs:
            return self.programs[key]
        defines = (f"#define ZEPH_EFFECTIVE_WATER_TIER {tier}\n"
                   f"#define ZEPH_EFFECTIVE_WATER_QUALITY {int(tier > 0)}\n"
                   "#define ZEPH_EFFECTIVE_WATER_WAVES 0\n")
        if dimension != "Overworld":
            defines += f"#define ZEPH_DIM_{dimension.upper()}\n"
        fragment = ("#version 330 compatibility\n" + defines + self.common + self.water +
                    "\nuniform vec3 fixtureNormal; uniform vec3 fixtureView; uniform vec3 fixtureColour; uniform float fixtureExposure;\n"
                    "void main(){gl_FragData[0]=vec4(zephWaterSurfaceLinear(fixtureColour, fixtureNormal, fixtureView, 0.0, fixtureExposure),0.75);}")
        vertex = "#version 330 compatibility\nvoid main(){gl_Position=gl_Vertex;}"
        stages = []
        for text, stage in ((vertex, "vsh"), (fragment, "fsh")):
            shader, ok, log = self.gl.compile(text.encode(), stage)
            self.shaders.append(shader)
            assert ok, f"{key} {stage}: {log}"
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

    def draw(self, case):
        program = self.program(case["tier"], case["dimension"])
        self.use(program)
        for name, value in (("fixtureNormal", case["normal"]), ("fixtureView", case["view"]),
                            ("sunPosition", case["sun"]), ("moonPosition", case["moon"]), ("skyColor", case.get("sky", (0.0, 0.0, 0.0))),
                            ("fixtureColour", case.get("colour", (0.0, 0.0, 0.0)))):
            self.uniform3(self.location(program, name.encode()), *value)
        self.uniform1(self.location(program, b"rainStrength"), case["rain"])
        self.uniform1(self.location(program, b"fixtureExposure"), case.get("exposure", 1.0))
        identity = (C.c_float * 16)(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        self.matrix(self.location(program, b"gbufferModelView"), 1, 0, identity)
        self.begin(0x0007)
        for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            self.vertex(x, y)
        self.end()
        pixel = (C.c_float * 4)()
        self.read(0, 0, 1, 1, 0x1908, 0x1406, pixel)
        assert self.error() == 0 and all(math.isfinite(x) for x in pixel), "GL error or nonfinite pixel"
        assert abs(pixel[3] - 0.75) < 1e-6, "draw did not preserve alpha sentinel"
        return tuple(pixel[:3])

    def close(self):
        self.use(0)
        for program in self.programs.values():
            self.gl.delete_program(program)
        for shader in self.shaders:
            self.gl.delete_shader(shader)
        self.gl.bind("glDeleteFramebuffers", None, C.c_int, C.POINTER(C.c_uint))(1, C.byref(self.framebuffer))
        self.legacy("glDeleteTextures", None, C.c_int, C.POINTER(C.c_uint))(1, C.byref(self.texture))
        self.gl.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=ROOT / "shaders")
    parser.add_argument("--baseline-water", type=Path, help="Retained pre-fix library; requires native execution")
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--inject-old-incidence", action="store_true", help="Native negative control: must fail")
    parser.add_argument("--inject-no-view-gate", action="store_true", help="Native negative control: must fail")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    water = (args.source_root / "lib/water.glsl").read_text(encoding="utf-8-sig")
    common = (args.source_root / "lib/common.glsl").read_text(encoding="utf-8-sig")
    source_requirements = ("float sunIncidence = max(dot(normal, sunDir), 0.0);",
                           "float moonIncidence = max(dot(normal, moonDir), 0.0);",
                           "sunSpecular *= sunIncidence;", "moonSpecular *= moonIncidence;",
                           "if (sunIncidence > 0.0 && NdotV > 0.0)",
                           "if (moonIncidence > 0.0 && NdotV > 0.0)")
    if not args.baseline_water:
        for marker in source_requirements:
            assert marker in water, f"local-incidence source contract missing: {marker}"
    cases = fixtures()
    baseline_counterexamples = 0
    for case in cases:
        expected = reference(**{k: case[k] for k in ("tier", "dimension", "rain")},
                             n=case["normal"], v=case["view"], sun=case["sun"], moon=case["moon"])
        old = reference(case["normal"], case["view"], case["sun"], case["moon"], case["tier"], case["dimension"], case["rain"], False)
        baseline_counterexamples += max(abs(a - b) for a, b in zip(expected, old)) > 1e-6
    assert baseline_counterexamples > 0, "negative control did not expose missing incidence"
    selected_water = args.baseline_water.read_text(encoding="utf-8-sig") if args.baseline_water else water
    if args.inject_old_incidence or args.inject_no_view_gate:
        if not args.native or args.baseline_water:
            parser.error("injected controls require --native without --baseline-water")
        if args.inject_old_incidence:
            for body in ("sun", "moon"):
                selected_water = selected_water.replace(f"float {body}Incidence = max(dot(normal, {body}Dir), 0.0);", f"float {body}Incidence = 1.0;")
        if args.inject_no_view_gate:
            selected_water = selected_water.replace(" && NdotV > 0.0", "")
    report = dict(evidence_class="SOURCE_CONTRACT_AND_CPU" if not args.native else "NATIVE_SOURCE_LIBRARY_RGBA32F",
                  minecraft_runtime="NOT TESTED", cpu_cases=len(cases), baseline_counterexamples=baseline_counterexamples,
                  source_sha256=hashlib.sha256(selected_water.encode()).hexdigest(), passed=True)
    if args.baseline_water and not args.native:
        parser.error("--baseline-water requires --native")
    if args.native:
        native = NativeFixture(common, selected_water)
        try:
            maximum = 0.0
            corrected_mismatches = 0
            for case in cases:
                pixel = native.draw(case)
                expected = reference(case["normal"], case["view"], case["sun"], case["moon"], case["tier"], case["dimension"], case["rain"], not bool(args.baseline_water), not bool(args.baseline_water))
                maximum = max(maximum, max(abs(a - b) for a, b in zip(pixel, expected)))
                corrected = reference(case["normal"], case["view"], case["sun"], case["moon"], case["tier"], case["dimension"], case["rain"])
                corrected_mismatches += max(abs(a - b) for a, b in zip(pixel, corrected)) > 1e-6
            assert maximum < 2e-5, f"native/reference error: {maximum}"
            assert corrected_mismatches > 0 if args.baseline_water else corrected_mismatches == 0
            report.update(driver=native.driver, native_draws=len(cases), native_programs=len(native.programs),
                          maximum_native_reference_error=maximum, corrected_reference_mismatches=corrected_mismatches,
                          source_kind="PRE_FIX_NEGATIVE_CONTROL" if args.baseline_water else "CURRENT")
        finally:
            native.close()
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        if args.output.exists():
            raise FileExistsError(args.output)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
