"""Render source-checked standalone Zepholume variants on the active WGL GPU.

Fixtures are synthetic loader inputs, not Minecraft or Iris/Oculus output.
"""

import argparse
import ctypes as C
import importlib.util
import json
import math
import struct
import sys
import statistics
import zlib
from pathlib import Path


def png(path, width, height, rgba):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    scan = b"".join(b"\0" + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height - 1, -1, -1))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">2I5B", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(scan)) + chunk(b"IEND", b""))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant-root", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--profile", default="Balanced")
    parser.add_argument("--dimension", default="Overworld")
    parser.add_argument("--program", default="gbuffers_terrain")
    parser.add_argument("--albedo", type=float, default=0.65)
    parser.add_argument("--light", type=float, default=1.0)
    parser.add_argument("--alpha", type=float, default=0.75)
    parser.add_argument("--fog-start", type=float, default=100.0)
    parser.add_argument("--fog-end", type=float, default=200.0)
    parser.add_argument("--fog-color", type=float, nargs=3, default=(0.2, 0.3, 0.4))
    parser.add_argument("--underwater", action="store_true")
    parser.add_argument("--eye-medium", type=int, choices=(0, 1, 2, 3), help="Synthetic isEyeInWater value")
    parser.add_argument("--rain", type=float, default=0.0)
    parser.add_argument("--night-vision", type=float, default=0.0)
    parser.add_argument("--water", action="store_true")
    parser.add_argument("--sun-y", type=float, default=1.0)
    parser.add_argument("--camera-pitch", type=float, default=0.0, help="Synthetic camera basis rotation, degrees")
    parser.add_argument("--camera-yaw", type=float, default=0.0, help="Synthetic camera basis rotation, degrees")
    parser.add_argument("--quad-extent", type=float, default=1.0, help="View-space X/Y half-extent")
    parser.add_argument("--quad-offset-x", type=float, default=0.0, help="View-space fixture center X")
    parser.add_argument("--quad-offset-y", type=float, default=0.0, help="View-space fixture center Y")
    parser.add_argument("--triangulation", choices=("quads", "forward", "reverse"), default="quads")
    parser.add_argument("--perspective", action="store_true", help="Perspective projection at fixture depth")
    parser.add_argument("--depth", type=float, default=0.5, help="Positive view-space depth")
    parser.add_argument("--skip-draw", action="store_true", help="Negative self-test: require clear-color detection")
    parser.add_argument("--skip-png", action="store_true", help="Keep float pixels and JSON without a normalized preview")
    parser.add_argument("--timing-draws", type=int, default=0, help="GPU timer-query workload per repetition")
    args = parser.parse_args()
    if not all(math.isfinite(v) for v in (args.camera_pitch, args.camera_yaw, args.quad_offset_x, args.quad_offset_y)):
        parser.error("camera rotations and quad offsets must be finite")
    pitch, yaw = map(math.radians, (args.camera_pitch, args.camera_yaw))
    cp, sp, cy, sy = math.cos(pitch), math.sin(pitch), math.cos(yaw), math.sin(yaw)
    rotation = ((cy, 0.0, sy), (sp * sy, cp, -sp * cy), (-cp * sy, sp, cp * cy))
    def rotate(vector):
        return tuple(sum(row[j] * vector[j] for j in range(3)) for row in rotation)
    camera_matrix = [rotation[row][col] if row < 3 and col < 3 else float(row == col)
                     for col in range(4) for row in range(4)]
    inverse_matrix = [rotation[col][row] if row < 3 and col < 3 else float(row == col)
                      for col in range(4) for row in range(4)]
    if not all(0 <= v <= 1 for v in (args.albedo, args.light, args.alpha)):
        parser.error("albedo, light, and alpha must be within [0, 1]")
    if not (0 < args.quad_extent <= 1 and 0 < args.depth <= 1):
        parser.error("quad-extent and depth must be within (0, 1]")
    if not all(math.isfinite(v) for v in (args.fog_start, args.fog_end, *args.fog_color)):
        parser.error("fog inputs must be finite")
    module_path = Path(__file__).with_name("native-gl-compile.py")
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("zeph_native_compile", module_path)
    native = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(native)
    index, files = native.load_variants(args.variant_root, args.source_root)
    selected = {}
    for row in index:
        if (row["Profile"], row["Dimension"], row["Program"], row["LoaderModel"], row["GpuIdentity"]) == (args.profile, args.dimension, args.program, "Iris render-stage model", "Intel"):
            selected[row["Stage"]] = row
    if set(selected) != {"vsh", "fsh"}:
        raise RuntimeError("No complete selected source-derived variant pair")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    gl = native.WGL()
    resources = []
    try:
        driver = gl.strings()
        if "Intel" not in driver["vendor"] or not driver["profile_mask"] & 2:
            raise RuntimeError(f"Intel compatibility context required: {driver}")
        u, i, f, p = C.c_uint, C.c_int, C.c_float, C.c_void_p
        bind = gl.bind
        gen_framebuffers = bind("glGenFramebuffers", None, i, C.POINTER(u))
        bind_framebuffer = bind("glBindFramebuffer", None, u, u)
        framebuffer_texture = bind("glFramebufferTexture2D", None, u, u, u, u, i)
        check_framebuffer = bind("glCheckFramebufferStatus", u, u)
        delete_framebuffers = bind("glDeleteFramebuffers", None, i, C.POINTER(u))
        active_texture = bind("glActiveTexture", None, u)
        use_program = bind("glUseProgram", None, u)
        uniform_location = bind("glGetUniformLocation", i, u, C.c_char_p)
        uniform_1i = bind("glUniform1i", None, i, i)
        uniform_1f = bind("glUniform1f", None, i, f)
        uniform_3f = bind("glUniform3f", None, i, f, f, f)
        uniform_matrix_4fv = bind("glUniformMatrix4fv", None, i, i, C.c_ubyte, C.POINTER(f))
        attrib_location = bind("glGetAttribLocation", i, u, C.c_char_p)
        vertex_attrib_1f = bind("glVertexAttrib1f", None, u, f)
        get_error = gl.gl.glGetError
        get_error.restype = u
        def legacy(name, restype, *types):
            fn = getattr(gl.gl, name)
            fn.restype, fn.argtypes = restype, types
            return fn
        gen_textures = legacy("glGenTextures", None, i, C.POINTER(u))
        bind_texture = legacy("glBindTexture", None, u, u)
        tex_image = legacy("glTexImage2D", None, u, i, i, i, i, i, u, u, p)
        tex_parameter = legacy("glTexParameteri", None, u, u, i)
        delete_textures = legacy("glDeleteTextures", None, i, C.POINTER(u))
        viewport = legacy("glViewport", None, i, i, i, i)
        disable = legacy("glDisable", None, u)
        clear_color = legacy("glClearColor", None, f, f, f, f)
        clear = legacy("glClear", None, u)
        read_pixels = legacy("glReadPixels", None, i, i, i, i, u, u, p)
        clear_buffer = bind("glClearBufferfv", None, u, i, C.POINTER(f))
        matrix_mode = legacy("glMatrixMode", None, u)
        load_identity = legacy("glLoadIdentity", None)
        mult_matrix = legacy("glMultMatrixf", None, C.POINTER(f))
        scale = legacy("glScalef", None, f, f, f)
        translate = legacy("glTranslatef", None, f, f, f)
        frustum = legacy("glFrustum", None, *([C.c_double] * 6))
        begin = legacy("glBegin", None, u)
        end = legacy("glEnd", None)
        vertex = legacy("glVertex3f", None, f, f, f)
        normal = legacy("glNormal3f", None, f, f, f)
        color = legacy("glColor4f", None, f, f, f, f)
        multi_tex = bind("glMultiTexCoord2f", None, u, f, f)
        flush = legacy("glFinish", None)
        stages = []
        for stage in ("vsh", "fsh"):
            row = selected[stage]
            shader, passed, log = gl.compile(files[row["ContentHash"].lower()][0].read_bytes(), stage)
            resources.append(("shader", shader))
            if not passed:
                raise RuntimeError(f"{stage} compilation failed: {log}")
            stages.append(shader)
        program = gl.create_program()
        resources.append(("program", program))
        for shader in stages:
            gl.attach_shader(program, shader)
        gl.link_program(program)
        ok = i()
        gl.get_program_iv(program, 0x8B82, C.byref(ok))
        if not ok.value:
            raise RuntimeError("Program link failed: " + gl.log(program, False))
        width = height = 32
        textures = (u * 3)()
        gen_textures(3, textures)
        resources.append(("textures", textures))
        # GL_RGBA32F output and GL_RGBA8 1x1 fixtures. Nearest sampling and clamp are fixed.
        active_texture(0x84C0)
        bind_texture(0x0DE1, textures[0])
        tex_image(0x0DE1, 0, 0x8814, width, height, 0, 0x1908, 0x1406, None)
        tex_parameter(0x0DE1, 0x2801, 0x2600)
        tex_parameter(0x0DE1, 0x2800, 0x2600)
        for unit, value in ((0, args.albedo), (1, args.light)):
            active_texture(0x84C0 + unit)
            bind_texture(0x0DE1, textures[unit + 1])
            byte = round(value * 255)
            pixel = (C.c_ubyte * 4)(byte, byte, byte, round(args.alpha * 255) if unit == 0 else 255)
            tex_image(0x0DE1, 0, 0x8058, 1, 1, 0, 0x1908, 0x1401, C.cast(pixel, p))
            for parameter, setting in ((0x2801, 0x2600), (0x2800, 0x2600), (0x2802, 0x812F), (0x2803, 0x812F)):
                tex_parameter(0x0DE1, parameter, setting)
        framebuffer = u()
        gen_framebuffers(1, C.byref(framebuffer))
        resources.append(("framebuffer", framebuffer))
        bind_framebuffer(0x8D40, framebuffer)
        framebuffer_texture(0x8D40, 0x8CE0, 0x0DE1, textures[0], 0)
        status = check_framebuffer(0x8D40)
        if status != 0x8CD5:
            raise RuntimeError(f"Framebuffer incomplete: 0x{status:04x}")
        viewport(0, 0, width, height)
        for capability in (0x0BE2, 0x0B71, 0x0B44, 0x0BD0, 0x8DB9):
            disable(capability)  # blend, depth, cull, dither, framebuffer sRGB
        # RGBA32F must retain values beyond normalized RGBA8. Probe readback
        # before the shader draw, then restore the fixture's distinct clear color.
        probe_value = (-0.25, 0.125, 1.25, 0.5)
        clear_buffer(0x1800, 0, (f * 4)(*probe_value))  # GL_COLOR
        probe = (f * 4)()
        read_pixels(16, 16, 1, 1, 0x1908, 0x1406, C.cast(probe, p))
        readback_probe = list(probe)
        if get_error() or any(abs(a - b) > 1e-6 for a, b in zip(readback_probe, probe_value)):
            raise RuntimeError(f"RGBA32F readback failed: expected {probe_value}, got {readback_probe}")
        clear_color(0.03125, 0.0625, 0.125, 0.25)
        clear(0x00004000)
        matrix_mode(0x1701)  # projection
        load_identity()
        if args.perspective:
            # The off-center face fills the same raster for either diagonal.
            # Its corners have different camera distances, unlike the default
            # symmetric quad which masks normalized-varying interpolation bugs.
            frustum(args.quad_offset_x - args.quad_extent, args.quad_offset_x + args.quad_extent,
                    args.quad_offset_y - args.quad_extent, args.quad_offset_y + args.quad_extent,
                    args.depth, args.depth * 4)
        else:
            scale(1 / args.quad_extent, 1 / args.quad_extent, 1)
            translate(-args.quad_offset_x, -args.quad_offset_y, 0)
        # Counter-rotate projection to preserve identical raster geometry while
        # rotating all view-space quantities; this tests coordinate invariance.
        mult_matrix((f * 16)(*inverse_matrix))
        matrix_mode(0x1700)  # modelview
        load_identity()
        mult_matrix((f * 16)(*camera_matrix))
        use_program(program)
        camera_location = uniform_location(program, b"gbufferModelView")
        if camera_location >= 0:
            uniform_matrix_4fv(camera_location, 1, 0, (f * 16)(*camera_matrix))
        def set_uniform(name, values):
            location = uniform_location(program, name.encode())
            if location < 0:
                return
            if isinstance(values, tuple):
                uniform_3f(location, *values)
            elif isinstance(values, int):
                uniform_1i(location, values)
            else:
                uniform_1f(location, values)
        uniforms = {"texture": 0, "lightmap": 1, "fogColor": tuple(args.fog_color), "fogStart": args.fog_start,
                    "fogEnd": args.fog_end, "skyColor": (0.4, 0.5, 0.7), "sunPosition": rotate((0.0, args.sun_y, 0.0)),
                    "moonPosition": rotate((0.0, -args.sun_y, 0.0)), "rainStrength": args.rain, "nightVision": args.night_vision,
                    "isEyeInWater": args.eye_medium if args.eye_medium is not None else int(args.underwater), "frameTimeCounter": 0.0}
        for name, values in uniforms.items():
            set_uniform(name, values)
        normal(0, 0, 1)
        color(1, 1, 1, 1)
        material_attribute = attrib_location(program, b"mc_Entity")
        if material_attribute >= 0:
            vertex_attrib_1f(material_attribute, 10001.0 if args.water else 0.0)
        def draw():
            corners = ((-1, -1, 0, 0), (1, -1, 1, 0), (1, 1, 1, 1), (-1, 1, 0, 1))
            indices = {"quads": (0, 1, 2, 3), "forward": (0, 1, 2, 0, 2, 3),
                       "reverse": (0, 1, 3, 1, 2, 3)}[args.triangulation]
            begin(0x0007 if args.triangulation == "quads" else 0x0004)
            for index in indices:
                x, y, s, t = corners[index]
                multi_tex(0x84C0, s, t)
                multi_tex(0x84C1, 0.5, 0.5)
                vertex(x * args.quad_extent + args.quad_offset_x,
                       y * args.quad_extent + args.quad_offset_y, -args.depth)
            end()
        if not args.skip_draw:
            draw()
        flush()
        pixels = (f * (width * height * 4))()
        read_pixels(0, 0, width, height, 0x1908, 0x1406, C.cast(pixels, p))
        error = get_error()
        center = list(pixels[4 * (16 * width + 16):4 * (16 * width + 16) + 4])
        finite = all(math.isfinite(v) for v in pixels)
        changed = any(abs(center[j] - [0.03125, 0.0625, 0.125, 0.25][j]) > 0.01 for j in range(4))
        if error or not finite or not changed:
            raise RuntimeError(f"Draw/readback failed: GL error 0x{error:04x}, finite={finite}, changed={changed}, center={center}")
        timing = {"status": "NOT MEASURED"}
        if args.timing_draws:
            if args.timing_draws < 1:
                raise ValueError("timing-draws must be positive")
            gen_queries = bind("glGenQueries", None, i, C.POINTER(u))
            begin_query = bind("glBeginQuery", None, u, u)
            end_query = bind("glEndQuery", None, u)
            query_result = bind("glGetQueryObjectui64v", None, u, u, C.POINTER(C.c_uint64))
            delete_queries = bind("glDeleteQueries", None, i, C.POINTER(u))
            query = u()
            gen_queries(1, C.byref(query))
            samples = []
            try:
                for rep in range(8):
                    begin_query(0x88BF, query)  # GL_TIME_ELAPSED
                    for _ in range(args.timing_draws):
                        draw()
                    end_query(0x88BF)
                    nanos = C.c_uint64()
                    query_result(query, 0x8866, C.byref(nanos))  # GL_QUERY_RESULT
                    if get_error():
                        raise RuntimeError("GPU timer query failed")
                    if rep >= 2:
                        samples.append(nanos.value / 1e6)
                timing = {"status": "SYNTHETIC GPU TIMER MEASURED", "draws_per_sample": args.timing_draws,
                          "warmup_samples": 2, "measured_samples": samples,
                          "median_ms": statistics.median(samples), "min_ms": min(samples), "max_ms": max(samples)}
            finally:
                delete_queries(1, C.byref(query))
        out_of_normalized_range = sum(v < 0 or v > 1 for v in pixels)
        png_path = None
        if not args.skip_png:
            rgba = bytes(round(max(0, min(1, v)) * 255) for v in pixels)
            png_path = args.output_dir / "render.png"
            png(png_path, width, height, rgba)
        (args.output_dir / "pixels.rgba32f").write_bytes(bytes(pixels))
        result = {"status": "NATIVE GPU RENDER VERIFIED", "synthetic": True, "driver": driver,
                  "variant": {stage: {"source": selected[stage]["OriginalSource"], "hash": selected[stage]["ContentHash"]} for stage in selected},
                  "profile": args.profile, "dimension": args.dimension, "program": args.program,
                  "fixture": {"albedo": args.albedo, "light": args.light, "alpha": args.alpha, "water_material": args.water, "uniforms": uniforms,
                              "gbufferModelView": camera_matrix,
                              "geometry": {"full_screen_quad_extent": args.quad_extent, "view_depth": args.depth,
                                           "offset": [args.quad_offset_x, args.quad_offset_y],
                                           "triangulation": args.triangulation, "perspective": args.perspective,
                                           "normal": "+Z", "camera_pitch": args.camera_pitch, "camera_yaw": args.camera_yaw, "projection_counter_rotated": True},
                              "textures": "1x1 RGBA8 nearest clamp"},
                  "framebuffer": "32x32 RGBA32F float, sRGB conversion disabled; PNG is clipped normalized RGBA8 preview; blending/depth/cull/dither disabled",
                  "readback_probe_rgba32f": readback_probe, "out_of_normalized_range_channels": out_of_normalized_range,
                  "center_rgba_float": center, "range": [min(pixels), max(pixels)], "finite": finite,
                  "draw_changed_clear": changed, "gl_error": error, "timing": timing, "png": str(png_path) if png_path else None}
        (args.output_dir / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"status": result["status"], "center": center, "png": str(png_path)}))
    finally:
        for kind, object_ in reversed(resources):
            if kind == "framebuffer":
                delete_framebuffers(1, C.byref(object_))
            elif kind == "textures":
                delete_textures(3, object_)
            elif kind == "program":
                gl.delete_program(object_)
            else:
                gl.delete_shader(object_)
        gl.close()


if __name__ == "__main__":
    main()
