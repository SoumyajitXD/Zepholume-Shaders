"""Render deterministic synthetic production shader fixtures on native Intel WGL.

Standalone mechanically expanded GLSL, not Minecraft, loader output or gameplay.
Output hashes are driver-specific, not cross-GPU golden values.
"""
import argparse
import hashlib
import json
import math
import re
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CASES = [
    ('sky-day', 'gbuffers_skybasic', 'Overworld', ['--sun-x','0.2','--sun-y','1']),
    ('sky-day-repeat', 'gbuffers_skybasic', 'Overworld', ['--sun-x','0.2','--sun-y','1']),
    ('sky-sunrise', 'gbuffers_skybasic', 'Overworld', ['--sun-x','1','--sun-y','0.08']),
    ('sky-sunset', 'gbuffers_skybasic', 'Overworld', ['--sun-x','-1','--sun-y','0.08']),
    ('sky-horizon-before', 'gbuffers_skybasic', 'Overworld', ['--sun-x','1','--sun-y','-0.001']),
    ('sky-horizon-after', 'gbuffers_skybasic', 'Overworld', ['--sun-x','1','--sun-y','0.001']),
    ('sky-night', 'gbuffers_skybasic', 'Overworld', ['--sun-x','0.2','--sun-y','-1']),
    ('sky-rain', 'gbuffers_skybasic', 'Overworld', ['--sun-x','0.2','--sun-y','1','--rain','0.6']),
    ('sky-storm', 'gbuffers_skybasic', 'Overworld', ['--sun-x','0.2','--sun-y','1','--rain','1']),
    ('water-day', 'gbuffers_water', 'Overworld', ['--water','--sun-x','0.2','--sun-y','1']),
    ('water-twilight', 'gbuffers_water', 'Overworld', ['--water','--sun-x','1','--sun-y','0.08']),
    ('water-night', 'gbuffers_water', 'Overworld', ['--water','--sun-x','0.2','--sun-y','-1','--light','0.2']),
    ('water-rain', 'gbuffers_water', 'Overworld', ['--water','--rain','1']),
    ('underwater-near', 'gbuffers_terrain', 'Overworld', ['--underwater','--fog-start','0','--fog-end','0.5','--depth','0.1','--quad-extent','0.001']),
    ('underwater-far', 'gbuffers_terrain', 'Overworld', ['--underwater','--fog-start','0','--fog-end','0.5','--depth','0.5','--quad-extent','0.001']),
    ('air-far', 'gbuffers_terrain', 'Overworld', ['--fog-start','0','--fog-end','0.5','--depth','0.5','--quad-extent','0.001']),
    ('lava-far', 'gbuffers_terrain', 'Overworld', ['--eye-medium','2','--fog-start','0','--fog-end','0.5','--depth','0.5','--quad-extent','0.001']),
    ('cloud-day', 'gbuffers_clouds', 'Overworld', ['--sun-x','0.2','--sun-y','1']),
    ('cloud-twilight', 'gbuffers_clouds', 'Overworld', ['--sun-x','1','--sun-y','0.08']),
    ('cloud-horizon-before', 'gbuffers_clouds', 'Overworld', ['--sun-x','1','--sun-y','-0.001']),
    ('cloud-horizon-after', 'gbuffers_clouds', 'Overworld', ['--sun-x','1','--sun-y','0.001']),
    ('cloud-night', 'gbuffers_clouds', 'Overworld', ['--sun-x','0.2','--sun-y','-1']),
    ('cloud-storm', 'gbuffers_clouds', 'Overworld', ['--rain','1']),
    ('nether', 'gbuffers_terrain', 'Nether', ['--fog-start','0','--fog-end','0.5']),
    ('end', 'gbuffers_terrain', 'End', ['--fog-start','0','--fog-end','0.5']),
    ('nether-black-fog', 'gbuffers_terrain', 'Nether', ['--fog-start','0','--fog-end','0.5','--fog-color','0','0','0']),
    ('end-black-fog', 'gbuffers_terrain', 'End', ['--fog-start','0','--fog-end','0.5','--fog-color','0','0','0']),
]

# Constant sampled lightmap isolates celestial response from base illumination.
# Coordinates are transformed UVs, not a geometric sun-visibility measurement.
for phase, sy, sz in [('noon', '1', '1'), ('sunset', '0.08', '1'), ('moon', '-1', '-1')]:
    for exposure, sky in [('open', '0.96875'), ('enclosed', '0.03125')]:
        CASES.append((f'water-{phase}-{exposure}', 'gbuffers_water', 'Overworld',
                      ['--water', '--sun-y', sy, '--sun-z', sz, '--sky-coord', sky]))
CASES += [
    ('water-block-lit', 'gbuffers_water', 'Overworld', ['--water','--sun-y','1','--sun-z','1','--sky-coord','0.03125','--block-coord','0.96875']),
    ('water-low-sky', 'gbuffers_water', 'Overworld', ['--water','--sun-y','1','--sun-z','1','--sky-coord','0.25']),
    ('water-rain-exposure', 'gbuffers_water', 'Overworld', ['--water','--sun-y','1','--sun-z','1','--sky-coord','0.96875','--rain','1']),
    ('water-submerged', 'gbuffers_water', 'Overworld', ['--water','--underwater','--sky-coord','0.03125']),
    ('water-nether', 'gbuffers_water', 'Nether', ['--water','--sun-y','1','--sun-z','1','--sky-coord','0.96875']),
    ('water-end', 'gbuffers_water', 'End', ['--water','--sun-y','1','--sun-z','1','--sky-coord','0.96875']),
    ('glass', 'gbuffers_water', 'Overworld', ['--material-id','10002','--sky-coord','0.96875']),
    ('ice', 'gbuffers_water', 'Overworld', ['--material-id','10003','--sky-coord','0.96875']),
    ('unknown-translucent', 'gbuffers_water', 'Overworld', ['--material-id','0','--sky-coord','0.96875']),
    ('water-potato', 'gbuffers_water', 'Overworld', ['--profile','Potato','--water','--sun-z','1','--sky-coord','0.03125']),
    ('water-low-open', 'gbuffers_water', 'Overworld', ['--profile','Low','--water','--sun-z','1','--sky-coord','0.96875']),
    ('water-low-enclosed', 'gbuffers_water', 'Overworld', ['--profile','Low','--water','--sun-z','1','--sky-coord','0.03125']),
    ('cloud-low', 'gbuffers_clouds', 'Overworld', ['--profile','Low','--sun-x','1','--sun-y','0.08']),
]

def digest(data):
    return hashlib.sha256(data).hexdigest()

def variants(source, out):
    out.mkdir(parents=True)
    files = sorted(p for p in source.rglob('*') if p.is_file() and p.suffix in ('.vsh','.fsh','.glsl','.properties','.lang'))
    (out/'source-manifest.json').write_text(json.dumps({'files':[{'path':p.relative_to(source).as_posix(),'sha256':digest(p.read_bytes())} for p in files]}))
    def expand(path, stack=()):
        if path in stack:
            raise ValueError(f'include cycle: {path}')
        lines=[]
        for line in path.read_text(encoding='utf-8-sig').splitlines():
            match=re.match(r'^\s*#include\s+"/([^"]+)"',line)
            if match:
                lines.append(expand(source / match.group(1), stack+(path,)))
            elif not re.match(r'^\s*#version',line):
                lines.append(line)
        return '\n'.join(lines)
    rows=[]
    def profile(extra):
        return extra[extra.index('--profile')+1] if '--profile' in extra else 'Balanced'
    for program, dimension, tier in sorted({(c[1],c[2],profile(c[3])) for c in CASES}):
        world={'Overworld':'world0','Nether':'world-1','End':'world1'}[dimension]
        for stage in ('vsh','fsh'):
            original=f'{world}/{program}.{stage}'
            expanded=expand(source/original)
            expanded=re.sub(r'(?m)^(#define\s+ZEPH_PROFILE_TIER\s+)\d+', r'\g<1>'+str({'Potato':0,'Low':1,'Balanced':2,'High':3,'Ultra':4}[tier]), expanded)
            shader=('#version 330 compatibility\n#define MC_RENDER_STAGE_STARS 3\n#define MC_RENDER_STAGE_VOID 4\n'+expanded+'\n').encode()
            artifact=f'{tier}-{world}-{program}.{stage}'
            (out/artifact).write_bytes(shader)
            rows.append({'Profile':tier,'Dimension':dimension,'Program':program,'LoaderModel':'Iris render-stage model','GpuIdentity':'Intel','Stage':stage,'Artifact':artifact,'ContentHash':digest(shader),'OriginalSource':original})
    (out/'index.json').write_text(json.dumps(rows))

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source',type=Path,default=ROOT/'shaders')
    ap.add_argument('--baseline-source',type=Path)
    ap.add_argument('--output-dir',type=Path,required=True)
    args=ap.parse_args()
    args.output_dir.mkdir(parents=True,exist_ok=False)
    sources={'candidate':args.source}
    if args.baseline_source: sources['baseline']=args.baseline_source
    all_results={}
    for label,source in sources.items():
        source=source.resolve()
        var=args.output_dir/(label+'-variants')
        variants(source,var)
        results={}
        for name,program,dimension,extra in CASES:
            output=args.output_dir/label/name
            cmd=[sys.executable,str(ROOT/'scripts/tests/native-gl-render.py'),'--variant-root',str(var),'--source-root',str(source),'--output-dir',str(output),'--program',program,'--dimension',dimension,*extra]
            run=subprocess.run(cmd,capture_output=True,text=True)
            if run.returncode: raise RuntimeError(f'{label}/{name}: {run.stdout}\n{run.stderr}')
            info=json.loads((output/'result.json').read_text())
            raw=(output/'pixels.rgba32f').read_bytes()
            pixels=struct.unpack('<4096f',raw)
            rgb=[pixels[i+c] for i in range(0,len(pixels),4) for c in range(3)]
            adjacent=max(abs(pixels[4*(y*32+x)+c]-pixels[4*(y*32+x+1)+c]) for y in range(32) for x in range(31) for c in range(3))
            metrics={'sha256_rgba32f':digest(raw),'sha256_png':digest((output/'render.png').read_bytes()), 'min_rgb':min(rgb),'max_rgb':max(rgb),'mean_rgb':sum(rgb)/len(rgb),'saturated_fraction':sum(v>=0.999 for v in rgb)/len(rgb),'max_horizontal_step':adjacent,'center_rgba':info['center_rgba_float']}
            if not all(math.isfinite(x) for x in pixels) or min(rgb)<-1e-5 or max(rgb)>1.5 or adjacent>0.8 or metrics['saturated_fraction']>0.95:
                raise AssertionError(f'{label}/{name}: invalid synthetic output {metrics}')
            results[name]=metrics
        all_results[label]=results
    c=all_results['candidate']
    if c['sky-day']['sha256_rgba32f'] != c['sky-day-repeat']['sha256_rgba32f']:
        raise AssertionError('repeated fixture produced different float output')
    horizon=max(abs(a-b) for a,b in zip(c['sky-horizon-before']['center_rgba'],c['sky-horizon-after']['center_rgba']))
    if horizon>0.05: raise AssertionError(f'horizon transition discontinuity: {horizon}')
    if c['sky-night']['mean_rgb'] >= c['sky-day']['mean_rgb'] or c['sky-night']['mean_rgb'] > 0.5:
        raise AssertionError('night sky brightness/order failed')
    cloud_horizon=max(abs(a-b) for a,b in zip(c['cloud-horizon-before']['center_rgba'],c['cloud-horizon-after']['center_rgba']))
    if cloud_horizon>0.05: raise AssertionError(f'cloud horizon discontinuity: {cloud_horizon}')
    if c['cloud-night']['mean_rgb'] >= c['cloud-day']['mean_rgb'] or c['cloud-night']['mean_rgb'] > 0.5:
        raise AssertionError('cloud night brightness/order failed')
    if c['sky-storm']['mean_rgb'] > c['sky-day']['mean_rgb'] + 0.02:
        raise AssertionError('storm sky unexpectedly brighter than clear sky')
    def center_delta(a,b):
        return max(abs(x-y) for x,y in zip(c[a]['center_rgba'],c[b]['center_rgba']))
    if center_delta('underwater-far','lava-far')<0.001 or center_delta('underwater-far','air-far')<0.001:
        raise AssertionError('distinct eye media produced indistinguishable outputs')
    if center_delta('underwater-near','underwater-far')<0.001:
        raise AssertionError('underwater distance did not change attenuation')
    # With fixed albedo and sampled lightmap, these aligned fixtures expose a
    # visible solar lobe. Do not generalize brightness ordering to arbitrary
    # geometry: other production lighting terms also depend on sky exposure.
    if c['water-sunset-open']['center_rgba'][0] <= c['water-sunset-enclosed']['center_rgba'][0] + 0.02:
        raise AssertionError('aligned sunset water did not show an exposure-dependent lobe')
    if c['water-low-open']['center_rgba'][0] <= c['water-low-enclosed']['center_rgba'][0] + 0.002:
        raise AssertionError('Low water did not show an exposure-dependent sheen')
    if abs(c['water-block-lit']['center_rgba'][3] - c['water-noon-enclosed']['center_rgba'][3]) > 1e-6:
        raise AssertionError('block coordinate changed water transparency')
    report={'scope':'Synthetic 32x32 standalone production GLSL on Intel WGL; no Minecraft or loader patching. Hashes are driver-specific.', 'cases':all_results,'horizon_center_delta':horizon,'cloud_horizon_center_delta':cloud_horizon}
    if 'baseline' in sources:
        comparisons={}
        sys.dont_write_bytecode=True
        import importlib.util
        spec=importlib.util.spec_from_file_location('native_render',ROOT/'scripts/tests/native-gl-render.py')
        mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
        for name,*_ in CASES:
            a=(args.output_dir/'baseline'/name/'pixels.rgba32f').read_bytes(); b=(args.output_dir/'candidate'/name/'pixels.rgba32f').read_bytes()
            aa=struct.unpack('<4096f',a); bb=struct.unpack('<4096f',b)
            differences=[abs(x-y) for x,y in zip(aa,bb)]
            comparisons[name]={'mean_abs_rgba':sum(differences)/len(differences),'max_abs_rgba':max(differences)}
            # Fourfold amplified absolute difference, clipped for inspection.
            image=bytes(round(min(1,differences[i]*4)*255) if i%4!=3 else 255 for i in range(len(differences)))
            mod.png(args.output_dir/'candidate'/name/'difference-x4.png',32,32,image)
        if comparisons['cloud-low']['max_abs_rgba'] > 1e-4:
            raise AssertionError('Low cloud uniform-work relocation exceeded 1e-4 RGBA tolerance')
        report['baseline_comparisons']=comparisons
    (args.output_dir/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'status':'PASS','cases':len(CASES),'horizon_center_delta':horizon,'report':str(args.output_dir/'report.json')}))

if __name__=='__main__': main()
