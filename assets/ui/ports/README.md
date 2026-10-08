# Layered town screens

Built with the built-in image_gen tool. Exact prompts and original generated
file paths are retained in `generation_manifest.json`. All production images
are copied into this project; runtime needs no external service.

`buildable_landscape.png` is the empty town terrain. Each faction folder holds:

- `panorama.png`: the complete developed city, used for foreign-port visits.
- `buildings_atlas.png`: source 4x3 transparent sprite sheet.
- Race-specific named building PNGs matching `data/ports/building_catalog.json`, including the Captain's House.
- `annex.png`, `tower.png`, `scaffold.png`, `wall.png`: independent details.

Sprites are sliced by `tools/art/slice_harbor_buildings.py`. Real alpha is
preserved, including transparent click masks; the sprites are not rectangular
buttons. The same camera and lighting were requested for every atlas.

`systems/ui/harbor_town_view.gd` reads actual saved building levels. Empty lots
appear in construction mode. Completed buildings use the player's race art. The
Captain's House is a normal, material-funded 30-level project; once built, it
opens personnel hiring. Its six race-specific images are standalone facade art,
not captain portraits. Barracks is also a 30-level construction project with six
race-specific facades; its garrison window remains directly accessible.

Levels 1–30 visibly progress: a faction-colored inlay gains one additional
light per level; the matching race annex art fades in across levels 2–11, and
the matching tower art grows in across levels 11–21. Thus every level has a
distinct composed appearance, using the source building art and existing modular
race overlays instead of hundreds of nearly duplicate image files. The same
levels remain individually modeled in the local 3D showcase where a GLB exists.
Scaffolding reflects a started project. Decorative previews never change the
player's economy.

Docking opens the town automatically. Click a building to use its existing
service, or click in construction mode to open its upgrade project. Undocking
returns to 3D sailing. Complete foreign panoramas use trade and encounter actions.
