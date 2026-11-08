"""Compare production sky stages on native Intel using synthetic planar quads."""
import argparse
import hashlib
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def digest(b):
    return hashlib.sha256(b).hexdigest()

def variants(source, out):
    out.mkdir(parents=True, exist_ok=False)
    files = [p for p in source.rglob('*') if p.is_file() and p.suffix in ('.vsh','.fsh','.glsl','.properties','.lang')]
    (out/'source-manifest.json').write_text(json.dumps({'files':[{'path':p.relative_to(source).as_posix(),'sha256':digest(p.read_bytes())} for p in files]}))
    def expand(path, stack=()):
        if path in stack:
            raise ValueError('include cycle')
        lines = []
        for line in path.read_text(encoding='utf-8-sig').splitlines():
            m = re.match(r'^\s*#include\s+"/([^"]+)"',line)
            if m:
                lines.append(expand(source / m.group(1),stack+(path,)))
            elif not re.match(r'^\s*#version',line):
                lines.append(line)
        return '\n'.join(lines)
    rows = []
    for stage in ('vsh','fsh'):
        shader = ('#version 330 compatibility\n#define MC_RENDER_STAGE_STARS 3\n#define MC_RENDER_STAGE_VOID 4\n' + expand(source / 'world0' / ('gbuffers_skybasic.'+stage))+'\n').encode()
        (out/stage).write_bytes(shader)
        rows.append({'Profile':'Balanced','Dimension':'Overworld','Program':'gbuffers_skybasic',
                     'LoaderModel':'Iris render-stage model','GpuIdentity':'Intel','Stage':stage,
                     'Artifact':stage,'ContentHash':digest(shader),'OriginalSource':'world0/gbuffers_skybasic.'+stage})
    (out/'index.json').write_text(json.dumps(rows))

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--baseline-source',type=Path,required=True)
    ap.add_argument('--source',type=Path,default=ROOT/'shaders')
    ap.add_argument('--output-dir',type=Path,required=True)
    args = ap.parse_args()
    args.output_dir.mkdir(parents=True,exist_ok=False)
    for name,source in (('baseline',args.baseline_source),('treatment',args.source)):
        variants(source,args.output_dir/(name+'-variants'))
    checks=[]
    driver=None
    for label,extra in [('unequal',['--quad-offset-x','0.35','--quad-offset-y','0.2']),
                        ('rotated',['--quad-offset-x','0.35','--quad-offset-y','0.2','--camera-pitch','25','--camera-yaw','-35']),
                        ('equal-radius',[]),('near-horizon',['--quad-offset-x','0.35','--quad-offset-y','0.001'])]:
        images={}
        for version,source in (('baseline',args.baseline_source),('treatment',args.source)):
            for diagonal in ('forward','reverse'):
                output=args.output_dir/label/version/diagonal
                cmd=[sys.executable,str(ROOT/'scripts/tests/native-gl-render.py'),'--source-root',str(source),
                     '--variant-root',str(args.output_dir/(version+'-variants')),'--output-dir',str(output),
                     '--program','gbuffers_skybasic','--triangulation',diagonal,'--perspective','--skip-png',*extra]
                result=subprocess.run(cmd,capture_output=True,text=True)
                if result.returncode:
                    raise RuntimeError(result.stdout+'\n'+result.stderr)
                report=json.loads((output/'result.json').read_text())
                assert report['finite'] and not report['gl_error']
                driver=report['driver']
                data=(output/'pixels.rgba32f').read_bytes()
                images[version,diagonal]=struct.unpack('<'+'f'*(len(data)//4),data)
        def delta(version):
            a,b=images[version,'forward'],images[version,'reverse']
            # Rotated fixture edges can differ in raster coverage at the clip
            # boundary. Compare only the interior and mutually covered pixels.
            pixels=[4*(y*32+x) for y in range(1,31) for x in range(1,31)
                    if a[4*(y*32+x)+3] > 0.9 and b[4*(y*32+x)+3] > 0.9]
            assert len(pixels) > 400, (label,len(pixels))
            return max(abs(a[i+c]-b[i+c]) for i in pixels for c in range(4))
        old,new=delta('baseline'),delta('treatment')
        assert new < 2e-5,(label,new)
        if label in ('unequal','rotated','near-horizon'):
            assert old > 1e-4,(label,old)
        checks.append({'case':label,'baseline_max_rgba_delta':old,'treatment_max_rgba_delta':new})
    report={'status':'PASS','driver':driver,'checks':checks,'draws':len(checks)*4,
            'scope':'Synthetic planar sky quads; standalone includes; no Minecraft or loader preprocessing'}
    (args.output_dir/'report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))

if __name__ == '__main__':
    main()
