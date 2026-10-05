# Playable harbor family

Six faction variants of the approved connected mountain ridge, plus six smaller
outposts and two portless route obstacles. Each folder contains its own `island.glb`.

- Editable master: `../karst_cove/source/karst_cove_city.blend`.
- Rebuild: `tools/art/export_faction_harbors.py` in Blender. `-- --only-mini` rebuilds outposts only.
- Runtime layout and collision source: `data/world/faction_harbors.json`.
- Blender -Y / Godot +Z is the entrance. Units in the exported files are metres.
- Terrain uses the ridge LOD1 (43k triangles); outposts reduce it again. Forest
  uses 250-triangle trees merged into spatial batches, not thousands of nodes.
- Godot import generates mesh LODs. Harbor forests disappear beyond 280 world
  metres. The 3D viewport stops rendering while the 2D town is open.
- Reference sizes, geometry counts, shoreline vertices, piers, flag placements
  and lighthouse lights are recorded in the manifest. Counts are not FPS claims.
- Collision transformation and render transformation share the manifest. Saved
  port positions and world seed are never changed by the presentation overlay.
- Existing tightly packed or multiport legacy islands retain their original
  shoreline and receive the older port district with solid lateral piers.

Faction distinctions: coral arches (Nerids), basalt/copper (Surr), merchant
cupolas (Meridians), sail roofs and distant sky harbor (Aery), crystal masonry
(Crystari), plaster/timber/brass (Humans). Existing heraldic emblems are attached
at runtime; warm lanterns and lighthouse beams follow the day/night cycle.
