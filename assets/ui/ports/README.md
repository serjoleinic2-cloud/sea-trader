# Layered town screens

Built with the built-in image_gen tool. Exact prompts and original generated
file paths are retained in `generation_manifest.json`. All production images
are copied into this project; runtime needs no external service.

`buildable_landscape.png` is the empty town terrain. Each faction folder holds:

- `panorama.png`: the complete developed city, used for foreign-port visits.
- `buildings_atlas.png`: source 4x3 transparent sprite sheet.
- Eight named building PNGs matching `data/ports/building_catalog.json`.
- `annex.png`, `tower.png`, `scaffold.png`, `wall.png`: independent details.

Sprites are sliced by `tools/art/slice_harbor_buildings.py`. Real alpha is
preserved, including transparent click masks; the sprites are not rectangular
buttons. The same camera and lighting were requested for every atlas.

`systems/ui/harbor_town_view.gd` reads actual saved building levels. Empty lots
appear in construction mode. Completed buildings appear automatically. Levels
1–10 use the main sprite; 11–20 add a wing; 21–30 add a tower. Exact levels appear
on hover and in the existing building card. This is three modular appearance
stages, not thirty individually painted levels. Scaffolding reflects a started
building project. No decorative preview changes the player's economy.

Docking opens the town automatically. Click a building to use its existing
service, or click in construction mode to open its upgrade project. Undocking
returns to 3D sailing. Complete foreign panoramas use trade and encounter actions.
