# Source-level shader cost report

These are source estimates, not measured GPU instruction counts.

| Program family | Fragment samples | Fragment trig / loops | Divisions / normalizations | Dynamic branches / discard | Varyings | Output |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ordinary textured | 1 | 0 / 0 | 1 fog division / 0 | 0 / 0 | 3 | 1 |
| Basic untextured | 0 | 0 / 0 | 1 fog division / 0 | 0 / 0 | 3 | 1 |
| Water | 1 | 0 / 0 | 1 fog division / 0 | 0 / 0 | 3 | 1 |
| Clouds | 1 | 0 / 0 | 1 fog division / 0 | 0 / 0 | 3 | 1 |
| Sky basic/textured | 0 / 1 | 0 / 0 | 0 / 0 | coherent stage chain / 0 | 3 | 1 |

Ultra Lite removes water vertex motion, water tint, and weather-adjusted fog at compile time. Balanced adds only those guarded paths. The hot-path pass removed the untextured basic pair's unused texture-coordinate varying and moved generic declarations out of sky/cloud stages. See `HOT_PATH_OPTIMISATION.md` and the machine-readable expanded-source statistics for the complete before/after audit.
