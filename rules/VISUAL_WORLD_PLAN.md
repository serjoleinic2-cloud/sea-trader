# VISUAL WORLD PLAN

## Owner-approved art direction — 2026-09-27

Sea Trader is a cinematic fantasy maritime world: a working trade-and-exploration game with the scale and wonder of a fantasy film. The sea is beautiful, immense, and occasionally strange; warfare is not the world's defining identity.

Mood references are broad only: the bioluminescent wonder, floating heights, and dramatic natural scale of *Avatar* and *Avatar: The Way of Water*; mythic Atlantean city imagery; and the monumental architecture and landscapes of *The Lord of the Rings*. Do not reproduce those franchises' characters, locations, symbols, or signature designs. Build an original visual language for Sea Trader.

Use stylized realism: readable ship silhouettes, believable coastlines and scale, expressive lighting, and imaginative color. Art must remain legible on a phone and perform on mobile hardware.

## Current implementation and source of truth

Trade, navigation, routes, contracts, crews, ports, and economy remain driven by the saved deterministic world and game systems. The shared 3D renderer presents that same world; visual effects and imported models must not alter game state.

Detailed art can be added in stages after each gameplay slice is stable. Procedural placeholders remain useful during mechanics development.

## Camera and readability

The final world has three presentation modes:

- **Strategic / Map** — routes, known ports, navigation, and world orientation.
- **Dynamic / Auto** — a smooth camera arc between overview and sailing views.
- **Sailing / Close** — the ship, horizon, nearby coastline, and water motion remain readable at sea.

The player can select an explicit overview or close view. In close view, desktop right-mouse drag orbits around the ship; mobile uses a dedicated touch gesture. Zoom controls distance and does not unexpectedly remove all horizon and motion cues while sailing in open water. Near a coast, the camera can lower smoothly to show the ship against the land.

Keep ship heading, speed, wake, and a clear navigation reference available without covering the scene. Camera movement must not imply that the ship has stopped.

## World geography and landmarks

The world should feel broader than a field of small, evenly spaced islands. Generate deterministic regions containing a mix of:

- broad continental shorelines and very large islands that take time to sail around;
- open-water crossings, island chains, deep bays, fjords, narrow straits, and navigable passages between cliffs;
- smaller islands and reefs that make coastlines varied without filling every sea lane;
- a small number of fantastical floating islands suspended in cloud, used as rare distant landmarks and special regional set pieces;
- discoverable hazards and unusual waters, used to create route choices rather than constant combat.

Procedural generation should use a seeded regional layout and coastline templates so continents, straits, and archipelagos have a coherent shape and remain stable after saving. Ports belong at plausible sheltered coves or inlets, not at every coastline point.

## Ports and monumental structures

Most ports should be useful, distinct working harbors. A few rare hubs may be monumental: vast sea gates, terraced quays, ancient coastal cities, or citadel-like harbor walls. Port scale and architecture should signal a region's history and importance.

A signature exploration moment is sailing from open water into a hidden, sheltered bay: the coastline opens gradually to reveal towering cliffs, lush slopes, waterfalls, reefs, cloud-wrapped heights, and an ancient harbor. Some island approaches can pass between giant carved statues into an inner bay or city. The statues and approach should be navigable landmarks, not decoration that blocks the route. Atlantean-inspired cities should feel ancient and maritime while retaining an original Sea Trader design.

The home port should read clearly as the player's base. Rare grand ports should feel exceptional because ordinary harbors leave room for contrast.

## Day, night, stars, and luminous water

Daylight is the default for readable sailing. Night is brief and intentional: a quiet visual interval to look up at the sky without making routine navigation frustrating.

The night sky should use a consistent, recognizable real-star reference rather than random decorative dots. Constellations and the star field should move coherently across the sky. Exact latitude/date behavior can be defined when the world calendar and geography are finalized.

At night, add restrained bioluminescent or fluorescent-looking light around the hull and in the wake. It should reveal the ship and nearby water without turning the whole sea into glowing neon. Ship lamps, moonlight, stars, and coast silhouettes should preserve enough contrast to steer safely.

## Mobile performance and asset workflow

Stream and level-of-detail the world: distant coastlines can use simplified silhouettes; nearby islands and ports receive detailed meshes and props. Keep water shader cost, transparent effects, lights, and floating-island geometry within a measured mobile budget. Provide scalable effect quality where needed.

The world uses reusable, modular 3D scenes so new islands, ports, statues, and sea objects can be added to the asset catalog without changing trading or save logic. The player can model ships and large props in SketchUp. Preferred import format for Godot is **GLB**. First-pass ship models should be centered, share an agreed forward axis, and use consistent scale.

Ship tiers need distinct silhouettes: small boat, barque, schooner, freighter, and tanker. All visual assets remain a presentation layer over the same game systems.

## Implemented visual foundation — 2026-09-27

The shared 3D renderer now supports the first sailing-view slice:

- Shore proximity and close zoom blend the overhead view into the same 3D sea; desktop right-drag and mobile two-finger gestures orbit, while the pinch gesture also controls zoom.
- The close view updates over open water, so it does not depend on a nearby island.
- The renderer has a short night interval, lower moonlit ambience, constellation-shaped star silhouettes, and a restrained glowing ship wake.
- Procedural island surfaces use seed-stable irregular coastlines with a visual opening at a harbor. Rare large islands receive a floating landmark; the home harbor receives a pair of gate statues.
- These meshes are visual only. Navigation, collisions, world seed, and save data continue to use the existing generated-world data.

The star silhouettes are a visual prototype. Once the world calendar and latitude are defined, replace them with an accurately oriented star field. Region-scale continental generation, bespoke coast/port meshes, cloud and waterfall effects, and mobile graphics presets remain future implementation slices.
