# Owner reference direction — 2 October 2026

2.jpg and 3.jpg govern environmental silhouettes, layered green cliffs,
terraced footpaths and stylized foliage. Avoid photographic leaf-card forests.
4.jpg and 5.jpg inform fine timber construction, working boats, low piers and
domestic harbor details. greenisland20.webp informs green islands along routes.
The earlier painted harbor images remain the city/bay composition reference.

Editable sources: assets/world/islands/*/source and ports/home_base/source.
Reference revision: tools/art/style_reference_islands.py (idempotent).
Route variants: tools/art/build_route_islands.py. Consolidated runtime exports:
tools/art/consolidate_environment.py. Run the reference revision after older
foliage builders; it supersedes their broadleaf crowns and exposed roots.
Then rebuild tools/art/assemble_harbor_city.py for the maximum-level overview.

Route variants currently replace uninhabited islands only. Port islands retain
their existing bay geometry to preserve the relation to docking/navigation.
