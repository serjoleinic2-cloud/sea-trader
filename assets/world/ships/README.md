# Ships

All regular and premium ship definitions have independent editable Blender hulls, GLB exports and transparent PNG portraits. The player hulls include deck seams, handrails, portholes, anchors and helms; the combat cutter and ghost frigate carry visible deck guns. Faction painting and animated flags are applied at runtime.

- `starter_sloop.glb` and `source/starter_sloop.blend`: original editable starter model.
- `ship_combat_cutter/ship_combat_cutter.glb` and `ship_combat_cutter/source/ship_combat_cutter.blend`: captain-led raid vessel with six deck guns.
- `factions/<race>/<ship_id>.glb` and matching `source/*.blend`: six race-specific fleet silhouettes, including the raid cutter.
- `<ship_id>/<ship_id>.glb` and `<ship_id>/source/<ship_id>.blend`: other editable hulls.
- `assets/ui/ships/<ship_id>.png`: rendered shipyard and fleet portraits.
- `data/world/ship_visuals.json`: physical source length, display scale, lamp and flag anchors.
- `scenes/showcase/ship_showcase.tscn`: read-only viewer for every hull, faction and night lighting.

Rebuild with Blender in background: `--python tools/art/build_ship_fleet.py -- --icons`. Prepare the starter's optimized export and portrait with `--python tools/art/prepare_starter_sloop.py`. Blender sources preserve individual editable pieces; runtime GLBs join them into one mesh with multiple materials. Source folders are excluded from Godot imports with `.gdignore`.

These are the first stylized game models. Sculpted ornaments, finer sail painting and final art polish remain future work. Mobile device performance has not been measured.
