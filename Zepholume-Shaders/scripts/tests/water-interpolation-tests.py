"""Planar-water ray interpolation regression; source/math evidence, not Minecraft."""
import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def normalize(v):
    d = math.sqrt(max(sum(x*x for x in v), 1e-8))
    return tuple(x/d for x in v)


def barycentric(p, a, b, c):
    denominator = (b[1]-c[1])*(a[0]-c[0]) + (c[0]-b[0])*(a[1]-c[1])
    u = ((b[1]-c[1])*(p[0]-c[0]) + (c[0]-b[0])*(p[1]-c[1]))/denominator
    v = ((c[1]-a[1])*(p[0]-c[0]) + (a[0]-c[0])*(p[1]-c[1]))/denominator
    return u, v, 1-u-v


def interpolate(vertices, point, triangles, old, normalize_result=True):
    screen = [(v[0]/-v[2], v[1]/-v[2]) for v in vertices]
    for triangle in triangles:
        weights = barycentric(point, *(screen[i] for i in triangle))
        if min(weights) < -1e-9:
            continue
        perspective = [weight / -vertices[i][2] for i, weight in zip(triangle, weights)]
        rays = [normalize(tuple(-x for x in vertices[i])) if old
                else tuple(-x for x in vertices[i]) for i in triangle]
        result = tuple(sum(w*ray[j] for w, ray in zip(perspective, rays))/sum(perspective)
                       for j in range(3))
        return normalize(result) if normalize_result else result
    raise AssertionError("Point outside both triangles")


def interpolated_distance(vertices, point, triangles):
    screen = [(v[0]/-v[2], v[1]/-v[2]) for v in vertices]
    for triangle in triangles:
        weights = barycentric(point, *(screen[i] for i in triangle))
        if min(weights) < -1e-9:
            continue
        perspective = [weight / -vertices[i][2] for i, weight in zip(triangle, weights)]
        return sum(w*math.sqrt(sum(x*x for x in vertices[i]))
                   for i, w in zip(triangle, perspective))/sum(perspective)
    raise AssertionError("Point outside both triangles")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--inject-old-ray', action='store_true', help='Negative control, must fail')
    parser.add_argument('--inject-old-distance', action='store_true', help='Negative distance control, must fail')
    args = parser.parse_args()
    triangles = (((0, 1, 2), (0, 2, 3)), ((0, 1, 3), (1, 2, 3)))
    maximum_old_error = maximum_new_error = maximum_old_diagonal = maximum_new_diagonal = 0.0
    maximum_old_fresnel = 0.0
    maximum_old_distance_error = maximum_old_distance_diagonal = 0.0
    maximum_new_distance_error = maximum_new_distance_diagonal = 0.0
    cases = 0
    old_counterexamples = 0
    for offset in ((0, 0), (0.75, 0.25), (-1.25, 0.5)):
        for depth in (0.5, 1, 4):
            for slope in ((0, 0), (0.1, -0.15)):
                vertices = [(x+offset[0], y+offset[1], -depth+slope[0]*x+slope[1]*y)
                            for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
                normal = normalize((-slope[0], -slope[1], 1))
                for u in (0.07, 0.21, 0.43, 0.68, 0.91):
                    for v in (0.09, 0.31, 0.55, 0.79, 0.93):
                        coefficients = ((1-u)*(1-v), u*(1-v), u*v, (1-u)*v)
                        physical = tuple(sum(c*p[j] for c, p in zip(coefficients, vertices)) for j in range(3))
                        expected = normalize(tuple(-x for x in physical))
                        screen = physical[0]/-physical[2], physical[1]/-physical[2]
                        old = [interpolate(vertices, screen, t, True) for t in triangles]
                        new = [interpolate(vertices, screen, t, args.inject_old_ray) for t in triangles]
                        old_error = max(abs(a-b) for ray in old for a, b in zip(ray, expected))
                        new_error = max(abs(a-b) for ray in new for a, b in zip(ray, expected))
                        old_diagonal = max(abs(a-b) for a, b in zip(*old))
                        new_diagonal = max(abs(a-b) for a, b in zip(*new))
                        maximum_old_error = max(maximum_old_error, old_error)
                        maximum_new_error = max(maximum_new_error, new_error)
                        maximum_old_diagonal = max(maximum_old_diagonal, old_diagonal)
                        maximum_new_diagonal = max(maximum_new_diagonal, new_diagonal)
                        old_distance = [interpolated_distance(vertices, screen, t) for t in triangles]
                        new_distance = (old_distance if args.inject_old_distance else
                                        [math.sqrt(sum(x*x for x in interpolate(vertices, screen, t, False, False)))
                                         for t in triangles])
                        expected_distance = math.sqrt(sum(x*x for x in physical))
                        maximum_old_distance_error = max(maximum_old_distance_error,
                                                        *(abs(d-expected_distance) for d in old_distance))
                        maximum_old_distance_diagonal = max(maximum_old_distance_diagonal,
                                                           abs(old_distance[0]-old_distance[1]))
                        maximum_new_distance_error = max(maximum_new_distance_error,
                                                        *(abs(d-expected_distance) for d in new_distance))
                        maximum_new_distance_diagonal = max(maximum_new_distance_diagonal,
                                                           abs(new_distance[0]-new_distance[1]))
                        old_counterexamples += old_diagonal > 1e-6
                        for power in (4, 5):
                            fresnel = [(1-max(0, min(1, sum(n*x for n, x in zip(normal, ray)))))**power for ray in old]
                            maximum_old_fresnel = max(maximum_old_fresnel, abs(fresnel[0]-fresnel[1]))
                        cases += 1
    source = (ROOT / 'shaders/lib/vertex.glsl').read_text(encoding='utf-8')
    # Consumers normalize at the evaluation point, not at the mesh vertices.
    water = (ROOT / 'shaders/lib/water.glsl').read_text(encoding='utf-8')
    common = (ROOT / 'shaders/lib/common.glsl').read_text(encoding='utf-8')
    fragment = (ROOT / 'shaders/lib/fragment.glsl').read_text(encoding='utf-8')
    source_ok = ('zephViewDirection = -viewPosition.xyz;' in source
                 and 'zephSafeNormalize(viewDirection)' in water
                 and 'zephSafeNormalize(viewDirection)' in common
                 and 'varying float zephDistance;' not in source + fragment
                 and 'float zephDistance = length(zephViewDirection);' in fragment)
    report = dict(evidence_class='SOURCE_BOUND_CPU_PERSPECTIVE_INTERPOLATION', minecraft_runtime='NOT TESTED',
                  cases=cases, old_triangulation_counterexamples=old_counterexamples,
                  maximum_old_ray_error=maximum_old_error, maximum_new_ray_error=maximum_new_error,
                  maximum_old_diagonal_ray_delta=maximum_old_diagonal,
                  maximum_new_diagonal_ray_delta=maximum_new_diagonal,
                  maximum_old_diagonal_fresnel_delta=maximum_old_fresnel, source_contract=source_ok,
                  maximum_old_distance_error=maximum_old_distance_error,
                  maximum_old_diagonal_distance_delta=maximum_old_distance_diagonal,
                  maximum_new_distance_error=maximum_new_distance_error,
                  maximum_new_diagonal_distance_delta=maximum_new_distance_diagonal,
                  passed=source_ok and maximum_new_error < 1e-12 and maximum_new_diagonal < 1e-12
                         and maximum_new_distance_error < 1e-12 and maximum_new_distance_diagonal < 1e-12
                         and old_counterexamples > 100)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report))
    if not report['passed']:
        raise AssertionError('Water interpolation regression; inspect report/source contract')


if __name__ == '__main__':
    main()
