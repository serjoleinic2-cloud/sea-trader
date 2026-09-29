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

Daylight is the default for readable sailing and must last substantially longer than night. Use a configurable 3:1 day-to-night ratio as the first tuning target; keep twilight transitions short enough to preserve the brief night-sky moment without making routine navigation difficult.

Sunrise and sunset must read as gradual lighting events, not instant palette swaps. As the Sun approaches and crosses the horizon, change the sky gradient, ambient light, cloud color, coast silhouettes, and reflected color on the sea together. Use a bright horizon glow with warm gold, orange, and rose tones, then fade toward the cooler upper sky. Atmospheric scattering is strongest visually at low Sun angles; keep the transition smooth and restrained rather than adding constant lens flare.

The night sky should be a clean, recognizable real-star field based on astronomical star positions, not a static pattern or random decorative dots. Orient stars to the observer's defined world location and in-game date/time so they move coherently and constellations rise and set naturally. The reference direction is the western hemisphere. Before accurate implementation, define the home region's reference latitude, longitude, calendar date, and time scale; “western hemisphere” alone does not specify one exact sky.

Show the zodiac constellations through subtle star connections or small labels only when they are actually visible in the night sky. They lie along the ecliptic and appear in different seasons; do not display all zodiac figures at once or as bright fantasy overlays. Fill the clear sky with many small, dim stars and reserve stronger points for the brightest recognizable stars. Keep clouds sparse during the dedicated star-viewing interval so the sky feels clear and expansive.

At night, add restrained bioluminescent or fluorescent-looking light around the hull and in the wake. It should reveal the ship and nearby water without turning the whole sea into glowing neon. Ship lamps, moonlight, stars, and coast silhouettes should preserve enough contrast to steer safely.

## Owner direction — astronomical sky and long daylight — 2026-09-29

The desired night sky is a clear, calm star field with the real western-hemisphere sky as its reference. A few major zodiac constellations should be recognizable; many small stars should provide depth without clutter. Keep star positions astronomically coherent with the ship's location and the game clock. Because the current world has no finalized geographic latitude/longitude or calendar, these inputs must be defined before claiming an exact sky reproduction.

The sunrise and sunset should visibly carry the transition: changing atmospheric color and light, a luminous horizon, and matching reflections on the sea. Day should be much longer than night. Begin playtesting with a 3:1 ratio, then tune the cycle while preserving a short, memorable interval for stargazing.

## Mobile performance and asset workflow

Stream and level-of-detail the world: distant coastlines can use simplified silhouettes; nearby islands and ports receive detailed meshes and props. Keep water shader cost, transparent effects, lights, and floating-island geometry within a measured mobile budget. Provide scalable effect quality where needed.

The world uses reusable, modular 3D scenes so new islands, ports, statues, and sea objects can be added to the asset catalog without changing trading or save logic. The player can model ships and large props in SketchUp. Preferred import format for Godot is **GLB**. First-pass ship models should be centered, share an agreed forward axis, and use consistent scale.

Ship tiers need distinct silhouettes: small boat, barque, schooner, freighter, and tanker. All visual assets remain a presentation layer over the same game systems.

## Implemented visual foundation — 2026-09-27

The shared 3D renderer now supports the first sailing-view slice:

- Shore proximity and close zoom blend the overhead view into the same 3D sea; desktop right-drag and mobile two-finger gestures orbit, while the pinch gesture also controls zoom.
- The close view updates over open water, so it does not depend on a nearby island.
- The first day/night pass uses a five-minute cycle with a target 3:1 daylight-to-night ratio. A procedural gradient sky, animated solar elevation, warm sunrise/sunset lighting, coordinated ambient light, and a restrained warm tint on the water establish dawn and dusk.
- The night sky uses about 6,300 seed-stable procedural star points scattered across the whole dome, plus the existing zodiac and constellation marks. The Milky Way band was removed after visual review because its edge made the sky dome's rendering limit noticeable. This is a stable visual imitation, not a real astronomical catalog; exact sky positions remain a later task after the world coordinates and calendar are defined.
- Procedural island surfaces use seed-stable irregular coastlines with a visual opening at a harbor. Rare large islands receive a floating landmark; the home harbor receives a pair of gate statues.
- These meshes are visual only. Navigation, collisions, world seed, and save data continue to use the existing generated-world data.

The star silhouettes are a visual prototype. Once the world calendar and latitude are defined, replace them with an accurately oriented star field. Region-scale continental generation, bespoke coast/port meshes, cloud and waterfall effects, and mobile graphics presets remain future implementation slices.
