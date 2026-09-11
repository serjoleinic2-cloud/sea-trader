# VISUAL WORLD PLAN

## Current phase

Gameplay remains top-down 2D while trade, navigation, routes, contracts, crews, ports, and economy are made reliable.
Placeholder visuals are acceptable. Detailed graphics and final design come after the mechanics are stable.

## Target camera

The final world uses three camera modes:

- **Top-Down / Map** — strategic travel, routes, ports, navigation and economy.
- **Dynamic / Auto** — smooth transition while zooming toward the ship.
- **Third-Person / Close** — close sailing view, ports, islands and ship scale.

Auto mode moves the camera along a smooth arc from a top-down position to a third-person position behind the ship. It is not an abrupt mode switch.
The player can keep an explicit Top-Down or Third-Person mode. The future mobile controls are pinch-to-zoom and drag-to-rotate in the 3D close view.

## World

World identity remains the saved deterministic seed. Islands, ports and their positions must regenerate from that seed; player progress must stay separate.

The final visual islands are 3D scenes with combinations of:

- harbours, docks and warehouses;
- cliffs, beaches and vegetation;
- lighthouse, castle or port administration;
- local buildings, small boats and merchant traffic.

The current 2D islands/ports remain the gameplay layout source until the 3D renderer is introduced.

## Models and import

The player can model ships and large props in SketchUp. Preferred import format for Godot is **GLB**.
Ship models should be a single object for the first import pass, centered at the origin, with forward direction agreed before export and a consistent scale.
Ship tiers will receive distinct 3D silhouettes: small boat, barque, schooner, freighter and tanker.

3D assets must not change trade, save, route, economy or progression state. They are render-layer replacements over the same systems.
