"""Compile real include-expanded programs with the underwater option disabled.

Requires the local Kali WSL glslangValidator. This is standalone GLSL, not Iris.
"""
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'shaders'


def expand(path):
    source = path.read_text(encoding='utf-8-sig')
    return re.sub(r'^\s*#include\s+"/([^"\n]+)"\s*$',
                  lambda m: expand(ROOT / m.group(1)), source, flags=re.M)


def wsl_path(path):
    return '/mnt/' + path.drive[0].lower() + path.as_posix()[2:]


def main():
    count = 0
    with tempfile.TemporaryDirectory(prefix='zeph-underwater-disabled-') as temporary:
        output = Path(temporary) / 'stage.frag'
        for dimension in ('world0', 'world-1', 'world1'):
            for program in ('gbuffers_terrain', 'gbuffers_water', 'gbuffers_hand', 'gbuffers_entities'):
                source = expand(ROOT / dimension / (program + '.fsh'))
                source, replacements = re.subn(r'(#define\s+ZEPH_UNDERWATER_QUALITY\s+)1\b', r'\g<1>0', source)
                assert replacements == 1, (dimension, program, replacements)
                output.write_text(source, encoding='utf-8')
                command = ['wsl.exe', '-d', 'kali-linux', '--', 'glslangValidator']
                pre = subprocess.run(command + ['-E', '-S', 'frag', wsl_path(output)], capture_output=True, text=True, check=True).stdout
                assert 'zephUnderwater' not in pre, (dimension, program)
                subprocess.run(command + ['-S', 'frag', wsl_path(output)], capture_output=True, text=True, check=True)
                count += 1
    print(f'{count} feature-disabled fragment stages preprocessed and compiled; underwater helper absent.')


if __name__ == '__main__':
    main()
