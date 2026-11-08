"""Exercise the actual water GLSL lobe on native GL, including a mutation.

The slightly over-length normal stresses floating-point overshoot; normal
vectors in production are normalized before use. No game execution is implied.
"""
import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('water_spec', Path(__file__).with_name('v107-water-specular.py'))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
common = (root / 'shaders/lib/common.glsl').read_text(encoding='utf-8-sig')
water = (root / 'shaders/lib/water.glsl').read_text(encoding='utf-8-sig')
clamp = '    nDotH = clamp(nDotH, 0.0, 1.0);'
assert water.count(clamp) == 1
case = dict(tier=2, dimension='Overworld', normal=(0.0, 1.00001, 0.0),
            view=(0.0, 1.0, 0.0), sun=(0.0, 1.0, 0.0),
            moon=(0.0, -1.0, 0.0), rain=0.0)
pixels = []
for source in (water, water.replace(clamp, '')):
    fixture = mod.NativeFixture(common, source)
    try:
        pixels.append(fixture.draw(case))
        driver = fixture.driver
    finally:
        fixture.close()
# Incidence is also perturbed; the bound is 1.15 * 0.60 * incidence.
bound = 1.15 * 0.60 * case['normal'][1]
assert pixels[0][0] <= bound + 2e-6, (pixels, bound)
assert pixels[1][0] > bound + 0.0001, (pixels, bound)
print(json.dumps(dict(driver=driver, bounded_red=pixels[0][0],
                      mutated_red=pixels[1][0], upper_bound=bound,
                      native_draws=2, mutation_rejected=True)))
