# Playable harbor family

Six faction harbor layouts, six smaller outposts, and two route obstacles share
the compact runtime mesh generator in `systems/rendering/low_poly_island.gd`.
The JSON manifest retains the shoreline, pier, flag, lighthouse, and navigation
data; no island GLB is needed by a clean checkout.

The old Blender sources, exports, and textures stay in this local folder and are
ignored by Git. They are not imported or loaded by the game. Harbor entry,
saved port anchors, collision, and faction-specific colors continue to use the
manifest. Existing faction emblems and night lighting are attached at runtime.
