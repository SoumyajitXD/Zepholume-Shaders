# Visual regression protocol

Status: **fixtures defined; screenshots not yet captured**.

At every viewpoint in [`bench/scene-manifest.json`](../bench/scene-manifest.json), capture a lossless screenshot for shaders disabled and every Zepholume profile after the same warm-up. Store the source image and SHA-256 alongside loader version, shader ZIP hash, profile, all option values, seed, position, yaw, pitch, time, weather, FOV, resolution, render distance, resource pack, and mod list.

Review each matched set for: snow texture/highlight retention; distinguishable ice, water, and snow; controlled blue balance; radial rather than rectangular sun glow; cloud direction/underside response; water reflection/transmission readability; natural terrain fog; legible caves; nocturnal but playable night; and clear High/Ultra progression without black terrain, pink surfaces, transparent world, broken hand, or framebuffer defects.

Loader-specific captures must also check shader reload, resource reload, world/dimension transition, rain/thunder, underwater, entities/block entities, particles, translucent blocks, glass, portals, glint, and UI/camera changes. A static validator result is not a screenshot regression result.
