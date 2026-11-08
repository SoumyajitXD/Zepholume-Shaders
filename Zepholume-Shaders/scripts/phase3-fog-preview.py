"""Draw source-derived fog math previews; these are not Minecraft screenshots."""

import argparse
import csv
import html
import subprocess
import zipfile
from pathlib import Path


def clamp(value):
    return max(0.0, min(1.0, value))


def old_range(distance, start, end):
    lower = max(start, 1.0)
    upper = max(end, lower + 1.0)
    return clamp((distance - lower) / (upper - lower))


def current_range(distance, start, end):
    width = end - start
    return (1.0 if distance >= start else 0.0) if width <= 0.0 else clamp((distance - start) / width)


def phase2_immersed(distance, start, end):
    return clamp((distance - start) / max(end - start, 0.0001))


def atmosphere(linear):
    # Balanced, clear sky, horizontal view: atmosphere.glsl's Hermite and 0.84 factor.
    return clamp(linear * linear * (3.0 - 2.0 * linear) * 0.84)


def source_guards(root, baseline):
    expected = {
        "shaders/lib/atmosphere.glsl": "float start = max(fogStart, 1.0);",
        "shaders/lib/cloud_fragment.glsl": "float start = max(fogStart, 1.0);",
        "shaders/lib/fog.glsl": "float mediumStart = max(fogStart, 1.0);",
    }
    with zipfile.ZipFile(baseline) as archive:
        for path, needle in expected.items():
            if needle not in archive.read(path).decode("utf-8"):
                raise ValueError(f"Frozen V1.0.5 equation changed: {path}")
    git_root = root.parent
    for path, needle in expected.items():
        phase2 = subprocess.check_output(
            ["git", "show", f"22dfaea:Zepholume-Shaders/{path}"], cwd=git_root, text=True
        )
        if path.endswith("fog.glsl"):
            needle = "float mediumRange = max(fogEnd - fogStart, 0.0001);"
        if needle not in phase2:
            raise ValueError(f"Checkpoint Phase 2 equation changed: {path}")
    for path in expected:
        current = (root / path).read_text(encoding="utf-8")
        if "fogEnd - fogStart" not in current or "<= 0.0" not in current:
            raise ValueError(f"Current Phase 3 equation changed: {path}")


def make_svg(rows, output):
    width, height = 930, 650
    colors = {"V1.0.5": "#a56a75", "Phase 2": "#c48b29", "Phase 3": "#117c82"}
    labels = ["Immersed water, Balanced", "Open air, Balanced", "Clouds, Balanced"]
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
             '<rect width="100%" height="100%" fill="#f8faf9"/>',
             '<text x="35" y="36" font-family="Arial" font-size="22" fill="#173139">Fog distance factor: valid 0 to 0.5 loader range</text>',
             '<text x="35" y="59" font-family="Arial" font-size="13" fill="#465b60">Source-derived mathematical preview · clear weather · horizontal view · not a Minecraft screenshot</text>']
    for panel, label in enumerate(labels):
        y0 = 100 + panel * 172
        x0, plot_w, plot_h = 68, 805, 113
        parts.append(f'<text x="{x0}" y="{y0 - 12}" font-family="Arial" font-size="16" fill="#173139">{html.escape(label)}</text>')
        parts.append(f'<rect x="{x0}" y="{y0}" width="{plot_w}" height="{plot_h}" fill="white" stroke="#d4dede"/>')
        for tick in (0.0, 0.5, 1.0):
            y = y0 + plot_h * (1 - tick)
            parts.append(f'<line x1="{x0}" y1="{y:.1f}" x2="{x0 + plot_w}" y2="{y:.1f}" stroke="#e9eeee"/>')
            parts.append(f'<text x="{x0 - 10}" y="{y + 4:.1f}" text-anchor="end" font-family="Arial" font-size="10" fill="#52666a">{tick:g}</text>')
        for name, color in colors.items():
            points = " ".join(f"{x0 + plot_w * (row['distance'] / 0.65):.1f},{y0 + plot_h * (1 - row[f'{label}|{name}']):.1f}" for row in rows)
            parts.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="2.5"/>')
        parts.append(f'<text x="{x0}" y="{y0 + plot_h + 17}" font-family="Arial" font-size="11" fill="#52666a">0</text>')
        parts.append(f'<text x="{x0 + plot_w * 0.5 / 0.65:.1f}" y="{y0 + plot_h + 17}" font-family="Arial" font-size="11" fill="#52666a">fogEnd = 0.5</text>')
    for j, (name, color) in enumerate(colors.items()):
        x = 220 + j * 190
        parts.append(f'<line x1="{x}" y1="626" x2="{x + 28}" y2="626" stroke="{color}" stroke-width="3"/>')
        parts.append(f'<text x="{x + 35}" y="630" font-family="Arial" font-size="13" fill="#173139">{name}</text>')
    parts.append('</svg>')
    output.write_text("\n".join(parts) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    source_guards(root, args.baseline)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for i in range(131):
        d = i * 0.005
        old = old_range(d, 0.0, 0.5)
        new = current_range(d, 0.0, 0.5)
        phase2_water = clamp(phase2_immersed(d, 0.0, 0.5) * 1.06)
        row = {"distance": d,
               "Immersed water, Balanced|V1.0.5": clamp(atmosphere(old) * 1.06),
               "Immersed water, Balanced|Phase 2": phase2_water,
               "Immersed water, Balanced|Phase 3": clamp(new * 1.06),
               "Open air, Balanced|V1.0.5": atmosphere(old),
               "Open air, Balanced|Phase 2": atmosphere(old),
               "Open air, Balanced|Phase 3": atmosphere(new),
               "Clouds, Balanced|V1.0.5": old * 0.76,
               "Clouds, Balanced|Phase 2": old * 0.76,
               "Clouds, Balanced|Phase 3": new * 0.76}
        rows.append(row)
    with (args.output_dir / "phase3-fog-curves.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    make_svg(rows, args.output_dir / "phase3-fog-curves.svg")
    print("Wrote source-checked fog math CSV and SVG; these are not rendered Minecraft evidence.")


if __name__ == "__main__":
    main()
