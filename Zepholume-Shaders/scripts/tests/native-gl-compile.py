"""Compile fresh Zepholume standalone variants on the active Windows OpenGL driver.

This does not run an Iris/Oculus preprocessor or render Minecraft. No extra
Python package, downloaded binary, or installed OpenGL SDK is required.
"""

import argparse
import ctypes as C
import hashlib
import json
import re
import sys
from pathlib import Path


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def load_variants(root, source_root):
    manifest = json.loads((root / "source-manifest.json").read_text(encoding="utf-8-sig"))
    index = json.loads((root / "index.json").read_text(encoding="utf-8-sig"))
    expected = set()
    for item in manifest["files"]:
        relative = item["path"].replace("\\", "/")
        expected.add(relative)
        path = source_root / relative
        if not path.is_file() or sha256(path.read_bytes()) != item["sha256"].lower():
            raise ValueError(f"Stale or missing source: {relative}; regenerate variants")
    actual = {
        p.relative_to(source_root).as_posix()
        for p in source_root.rglob("*")
        if p.is_file() and p.suffix in {".vsh", ".fsh", ".glsl", ".properties", ".lang"}
    }
    if actual != expected:
        raise ValueError("Variant source inventory is stale; regenerate variants")
    if not index:
        raise ValueError("Empty variant index")
    files = {}
    for row in index:
        path = root / row["Artifact"].replace("\\", "/")
        digest = row["ContentHash"].lower()
        if not path.is_file() or sha256(path.read_bytes()) != digest:
            raise ValueError(f"Missing or corrupt preprocessed variant: {path}")
        if row["Stage"] not in ("vsh", "fsh"):
            raise ValueError(f"Unexpected shader stage: {row['Stage']}")
        files[digest] = (path, row["Stage"])
    return index, files


class WGL:
    def __init__(self):
        if sys.platform != "win32":
            raise RuntimeError("WGL harness requires Windows")
        self.user = C.WinDLL("user32", use_last_error=True)
        self.gdi = C.WinDLL("gdi32", use_last_error=True)
        self.gl = C.WinDLL("opengl32", use_last_error=True)
        self.user.CreateWindowExW.argtypes = [C.c_ulong, C.c_wchar_p, C.c_wchar_p, C.c_ulong,
            C.c_int, C.c_int, C.c_int, C.c_int, C.c_void_p, C.c_void_p, C.c_void_p, C.c_void_p]
        self.user.CreateWindowExW.restype = C.c_void_p
        self.user.GetDC.argtypes = [C.c_void_p]
        self.user.GetDC.restype = C.c_void_p
        self.user.ReleaseDC.argtypes = [C.c_void_p, C.c_void_p]
        self.user.DestroyWindow.argtypes = [C.c_void_p]
        self.gdi.ChoosePixelFormat.argtypes = [C.c_void_p, C.c_void_p]
        self.gdi.ChoosePixelFormat.restype = C.c_int
        self.gdi.SetPixelFormat.argtypes = [C.c_void_p, C.c_int, C.c_void_p]
        self.gdi.SetPixelFormat.restype = C.c_int
        self.gl.wglCreateContext.argtypes = [C.c_void_p]
        self.gl.wglCreateContext.restype = C.c_void_p
        self.gl.wglMakeCurrent.argtypes = [C.c_void_p, C.c_void_p]
        self.gl.wglDeleteContext.argtypes = [C.c_void_p]
        self.gl.wglGetProcAddress.argtypes = [C.c_char_p]
        self.gl.wglGetProcAddress.restype = C.c_void_p
        self.gl.glGetString.argtypes = [C.c_uint]
        self.gl.glGetString.restype = C.c_char_p
        self.gl.glGetIntegerv.argtypes = [C.c_uint, C.POINTER(C.c_int)]
        self.hwnd = self.user.CreateWindowExW(0, "STATIC", "Zepholume offline GLSL validation", 0,
            0, 0, 8, 8, None, None, None, None)
        if not self.hwnd:
            raise OSError(C.get_last_error(), "CreateWindowExW failed")
        self.hdc = self.user.GetDC(self.hwnd)
        if not self.hdc:
            raise OSError(C.get_last_error(), "GetDC failed")

        class PFD(C.Structure):
            _fields_ = [("nSize", C.c_ushort), ("nVersion", C.c_ushort), ("dwFlags", C.c_ulong),
                ("iPixelType", C.c_ubyte), ("cColorBits", C.c_ubyte), ("cRedBits", C.c_ubyte),
                ("cRedShift", C.c_ubyte), ("cGreenBits", C.c_ubyte), ("cGreenShift", C.c_ubyte),
                ("cBlueBits", C.c_ubyte), ("cBlueShift", C.c_ubyte), ("cAlphaBits", C.c_ubyte),
                ("cAlphaShift", C.c_ubyte), ("cAccumBits", C.c_ubyte), ("cAccumRedBits", C.c_ubyte),
                ("cAccumGreenBits", C.c_ubyte), ("cAccumBlueBits", C.c_ubyte), ("cAccumAlphaBits", C.c_ubyte),
                ("cDepthBits", C.c_ubyte), ("cStencilBits", C.c_ubyte), ("cAuxBuffers", C.c_ubyte),
                ("iLayerType", C.c_ubyte), ("bReserved", C.c_ubyte), ("dwLayerMask", C.c_ulong),
                ("dwVisibleMask", C.c_ulong), ("dwDamageMask", C.c_ulong)]

        pfd = PFD()
        pfd.nSize = C.sizeof(PFD)
        pfd.nVersion = 1
        pfd.dwFlags = 0x00000004 | 0x00000020  # DRAW_TO_WINDOW | SUPPORT_OPENGL
        pfd.iPixelType = 0  # RGBA
        pfd.cColorBits = 24
        pfd.cDepthBits = 24
        pfd.iLayerType = 0
        pixel_format = self.gdi.ChoosePixelFormat(self.hdc, C.byref(pfd))
        if not pixel_format or not self.gdi.SetPixelFormat(self.hdc, pixel_format, C.byref(pfd)):
            raise OSError(C.get_last_error(), "Could not set an OpenGL pixel format")
        self.context = self.gl.wglCreateContext(self.hdc)
        if not self.context or not self.gl.wglMakeCurrent(self.hdc, self.context):
            raise OSError(C.get_last_error(), "Could not activate WGL context")
        self._bind_functions()

    def bind(self, name, restype, *argtypes):
        address = self.gl.wglGetProcAddress(name.encode("ascii"))
        if not address or address in (1, 2, 3, -1):
            raise RuntimeError(f"OpenGL entry point missing: {name}")
        return C.WINFUNCTYPE(restype, *argtypes)(address)

    def _bind_functions(self):
        u = C.c_uint
        i = C.c_int
        p = C.c_void_p
        self.create_shader = self.bind("glCreateShader", u, u)
        self.shader_source = self.bind("glShaderSource", None, u, i, C.POINTER(C.c_char_p), C.POINTER(i))
        self.compile_shader = self.bind("glCompileShader", None, u)
        self.get_shader_iv = self.bind("glGetShaderiv", None, u, u, C.POINTER(i))
        self.get_shader_log = self.bind("glGetShaderInfoLog", None, u, i, C.POINTER(i), p)
        self.delete_shader = self.bind("glDeleteShader", None, u)
        self.create_program = self.bind("glCreateProgram", u)
        self.attach_shader = self.bind("glAttachShader", None, u, u)
        self.link_program = self.bind("glLinkProgram", None, u)
        self.get_program_iv = self.bind("glGetProgramiv", None, u, u, C.POINTER(i))
        self.get_program_log = self.bind("glGetProgramInfoLog", None, u, i, C.POINTER(i), p)
        self.delete_program = self.bind("glDeleteProgram", None, u)

    def strings(self):
        values = {}
        for name, enum in (("vendor", 0x1F00), ("renderer", 0x1F01),
                           ("opengl", 0x1F02), ("glsl", 0x8B8C)):
            raw = self.gl.glGetString(enum)
            values[name] = raw.decode("utf-8", "replace") if raw else ""
        mask = C.c_int()
        self.gl.glGetIntegerv(0x9126, C.byref(mask))  # GL_CONTEXT_PROFILE_MASK
        values["profile_mask"] = mask.value
        return values

    def log(self, obj, shader):
        query = self.get_shader_iv if shader else self.get_program_iv
        fetch = self.get_shader_log if shader else self.get_program_log
        length = C.c_int()
        query(obj, 0x8B84, C.byref(length))  # INFO_LOG_LENGTH
        if length.value <= 1:
            return ""
        buffer = C.create_string_buffer(length.value)
        written = C.c_int()
        fetch(obj, length.value, C.byref(written), buffer)
        return buffer.raw[:written.value].decode("utf-8", "replace")

    def compile(self, data, stage):
        shader = self.create_shader(0x8B31 if stage == "vsh" else 0x8B30)
        if not shader:
            raise RuntimeError("glCreateShader failed")
        src = C.c_char_p(data)
        size = C.c_int(len(data))
        self.shader_source(shader, 1, C.byref(src), C.byref(size))
        self.compile_shader(shader)
        status = C.c_int()
        self.get_shader_iv(shader, 0x8B81, C.byref(status))  # COMPILE_STATUS
        return shader, bool(status.value), self.log(shader, True)

    def link(self, vertex, fragment):
        program = self.create_program()
        if not program:
            raise RuntimeError("glCreateProgram failed")
        self.attach_shader(program, vertex)
        self.attach_shader(program, fragment)
        self.link_program(program)
        status = C.c_int()
        self.get_program_iv(program, 0x8B82, C.byref(status))  # LINK_STATUS
        result = bool(status.value), self.log(program, False)
        self.delete_program(program)
        return result

    def close(self):
        if getattr(self, "context", None):
            self.gl.wglMakeCurrent(None, None)
            self.gl.wglDeleteContext(self.context)
        if getattr(self, "hdc", None):
            self.user.ReleaseDC(self.hwnd, self.hdc)
        if getattr(self, "hwnd", None):
            self.user.DestroyWindow(self.hwnd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant-root", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--require-vendor", default="Intel")
    args = parser.parse_args()
    index, files = load_variants(args.variant_root, args.source_root)
    context = WGL()
    try:
        driver = context.strings()
        print(json.dumps(driver, indent=2))
        if args.require_vendor.lower() not in driver["vendor"].lower():
            raise RuntimeError(f"Expected {args.require_vendor} driver; found {driver['vendor']}")
        gl_version = re.match(r"(\d+)\.(\d+)", driver["opengl"])
        glsl_version = re.match(r"(\d+)\.(\d+)", driver["glsl"])
        if not gl_version or tuple(map(int, gl_version.groups())) < (3, 3):
            raise RuntimeError("OpenGL 3.3 or newer required")
        if not glsl_version or tuple(map(int, glsl_version.groups())) < (3, 30):
            raise RuntimeError("GLSL 3.30 or newer required")
        if not driver["profile_mask"] & 0x2:
            raise RuntimeError("OpenGL compatibility profile required")
        stages = []
        shader_ids = {}
        for digest, (path, stage) in sorted(files.items()):
            shader, passed, log = context.compile(path.read_bytes(), stage)
            stages.append({"hash": digest, "stage": stage, "passed": passed, "driver_log": log})
            if passed:
                shader_ids[digest] = shader
            else:
                context.delete_shader(shader)
        groups = {}
        for row in index:
            key = (row["Profile"], row["Dimension"], row["LoaderModel"], row["Program"])
            groups.setdefault(key, {})[row["Stage"]] = row["ContentHash"].lower()
        links = []
        for key, pair in sorted(groups.items()):
            vertex, fragment = pair.get("vsh"), pair.get("fsh")
            if not vertex or not fragment:
                raise ValueError(f"Incomplete program pair: {key}")
            if vertex in shader_ids and fragment in shader_ids:
                passed, log = context.link(shader_ids[vertex], shader_ids[fragment])
            else:
                passed, log = False, "Stage compilation failed; link skipped"
            links.append({"profile": key[0], "dimension": key[1], "macro_model": key[2],
                          "program": key[3], "vertex_hash": vertex, "fragment_hash": fragment,
                          "passed": passed, "driver_log": log})
        for shader in shader_ids.values():
            context.delete_shader(shader)
        report = {"scope": "Native Windows OpenGL driver on Zepholume-preprocessed source; not Iris/Oculus-patched or Minecraft runtime",
                  "driver": driver, "source_manifest_sha256": sha256((args.variant_root / "source-manifest.json").read_bytes()),
                  "stages": stages, "links": links}
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        stage_pass = sum(row["passed"] for row in stages)
        link_pass = sum(row["passed"] for row in links)
        print(f"Native driver: {stage_pass}/{len(stages)} stages, {link_pass}/{len(links)} links; {args.report}")
        if stage_pass != len(stages) or link_pass != len(links):
            for row in stages + links:
                if not row["passed"]:
                    print(json.dumps(row), file=sys.stderr)
            return 1
        return 0
    finally:
        context.close()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"Native driver validation failed: {exc}", file=sys.stderr)
        sys.exit(2)
