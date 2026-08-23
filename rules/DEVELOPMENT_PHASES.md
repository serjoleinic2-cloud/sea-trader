# DEVELOPMENT PHASES

> Sequential build plan. Each phase must be complete before the next begins.
> Last Updated: 2026-08-23 | Version: 0.1.0

---

## Phase 01 — Foundation

**Goal:** Runnable Godot project with core infrastructure. No gameplay.

**Systems created:**
- Godot 4.x project init
- `GameState` autoload (all state classes, empty data)
- `EventBus` autoload (signal definitions)
- `SaveSystem` autoload (save/load/backup/migration skeleton)
- Data folder structure with placeholder JSONs
- `tests/` with GUT framework

**Dependencies:** None

**Done when:**
- Project runs without errors
- `GameState` can be read/written
- `SaveSystem` saves and loads empty state
- Folder structure matches `ARCHITECTURE.md`

---

## Phase 02 — World Generation

**Goal:** Deterministic sea world generated from seed.

**Systems created:**
- `WorldGenerator` (Simplex noise → islands)
- `IslandPlacer`
- `PortGenerator` (port positions, not gameplay)
- `ResourceDistributor`
- `HazardPlacer` (zones defined, not active)
- `WorldGenerationConfig` JSON

**Dependencies:** Phase 01

**Done when:**
- Same seed produces identical world every time
- World stored in `WorldState`
- Unit test: seed X → expected island count/positions

---

## Phase 03 — Ship Physics

**Goal:** Ship moves with physical feel. No sensors yet.

**Systems created:**
- `ShipPhysics` (momentum, inertia, turning radius, visual tilt)
- `ShipControl` (accepts normalized -1..1 commands)
- Keyboard input hardcoded for testing (WASD)
- Ship scene with tilt animation

**Dependencies:** Phase 01

**Done when:**
- Ship has physical momentum (doesn't stop instantly)
- Ship visually tilts on turns
- Movement feels nautical, not instant
- `ShipState` position/velocity updated correctly

---

## Phase 04 — Sensors

**Goal:** Replace keyboard with phone tilt. Debug fallback preserved.

**Systems created:**
- `SensorInput` (reads Android accelerometer)
- `InputAdapter` (normalize + route to ShipControl; keyboard in debug mode)

**Dependencies:** Phase 03

**Done when:**
- Tilt forward = accelerate
- Tilt backward = brake
- Tilt left/right = turn
- Keyboard still works in debug build
- Sensitivity configurable in `SettingsState`

---

## Phase 05 — World Rendering + Ports

**Goal:** Player can see world and discover ports.

**Systems created:**
- `WorldRenderer` (camera, ocean tiles, island sprites)
- `PortSystem` (discovery trigger, dock interaction, `PortState`)

**Dependencies:** Phases 02, 03

**Done when:**
- Ocean and islands visible from ship camera
- Sailing into port range triggers discovery
- Discovered ports appear on map
- `PortState.discovered` updates correctly

---

## Phase 06 — Navigation

**Goal:** Player can set a destination and see compass arrow.

**Systems created:**
- `NavigationHUD` (compass arrow, distance label)
- Port selection UI (basic)

**Dependencies:** Phase 05

**Done when:**
- Player selects discovered port as destination
- Arrow points toward destination with correct heading
- Distance shown and updates as ship moves
- Arrow disappears on arrival

---

## Phase 07 — Save System (full)

**Goal:** Full save/load with backup, migration, offline delta.

**Systems created:**
- `SaveSystem` complete implementation
- `save_main.json`, `save_backup.json`, `save_meta.json` logic
- Offline progress stub (no fleet yet, just timestamp)

**Dependencies:** Phase 01 (extends skeleton)

**Done when:**
- Game saves on quit/background
- Game loads correctly on relaunch
- Backup used if main file corrupt
- Migration runs on version mismatch
- `last_session_timestamp` recorded

---

## Phase 08 — Cargo and Contracts

**Goal:** Player can pick up and deliver cargo for reward.

**Systems created:**
- `ContractSystem` (generate, accept, track, complete)
- `EconomyEngine` (financial transactions)
- Trade screen UI (basic)
- `ContractData` JSON templates

**Dependencies:** Phases 05, 07

**Done when:**
- Contracts visible at port
- Player accepts, cargo appears in `ShipState.cargo`
- Player delivers to destination
- Reward calculated with time bonus
- `PlayerState.money` updated

---

## Phase 09 — Damage and Repair

**Goal:** Ship components take damage. Repair at port costs money.

**Systems created:**
- `DamageSystem` (collision + hazard damage, component health)
- Repair UI at port

**Dependencies:** Phases 03, 08

**Done when:**
- Hull damage reduces max speed
- Engine damage reduces acceleration
- Steering damage reduces turn rate
- Repair available at port for cost
- If hull = 0 → game over / respawn (TBD)

---

## Phase 10 — Progression

**Goal:** Player earns XP, levels up, unlocks upgrades.

**Systems created:**
- `ProgressionSystem` (XP, levels, reputation, unlocks)
- `UpgradeData` JSON
- Upgrade UI at port

**Dependencies:** Phases 08, 09

**Done when:**
- XP earned on contract completion
- Level-up triggers at thresholds
- Upgrades purchasable and applied to `ShipState`
- Reputation affects contract offer quality (basic)

---

## Phase 11 — Port Development

**Goal:** Player develops their home port with buildings.

**Systems created:**
- Port building system (construct, upgrade, damage states)
- Home port designation
- Port level progression

**Dependencies:** Phase 10

**Done when:**
- Player can designate a home port
- Buildings constructable at home port
- Buildings affect gameplay (TBD specifics per building)
- Port level increases with development

---

## Phase 12 — Company

**Goal:** Player can found a trading company.

**Systems created:**
- `CompanySystem` (creation, name, logo, level)
- Company screen UI
- `CompanyState` fully implemented

**Dependencies:** Phase 10

**Done when:**
- Company creation flow works
- Company name and logo saved
- Company expenses tracked
- Company level milestones defined

---

## Phase 13 — Employees

**Goal:** Player can hire employees with roles and salaries.

**Systems created:**
- `EmployeeManager` (hire, fire, bonuses, salaries)
- Employee listing UI
- `EmployeeData` JSON (all roles)

**Dependencies:** Phase 12

**Done when:**
- All employee roles hireable
- Salaries deducted daily from company balance
- Role bonuses applied to relevant systems
- Employee screen functional

---

## Phase 14 — Fleet

**Goal:** Player can buy additional ships and assign captains to routes.

**Systems created:**
- `FleetManager` (purchase ships, assign routes, auto-income)
- Fleet screen UI
- Offline fleet income in `SaveSystem`

**Dependencies:** Phases 13, 07

**Done when:**
- Ship purchasable from port (if criteria met)
- Captain assigned to ship + route
- Fleet generates income automatically
- Offline income calculated on load

---

## Phase 15 — Pirates and Protection

**Goal:** Pirate zones are active hazards. Protection possible.

**Systems created:**
- `HazardSystem` complete (pirate encounters, storm effects)
- Protection mechanic (TBD: defense ships? hired guards?)
- Pirate zone visual indicators

**Dependencies:** Phases 09, 14

**Done when:**
- Entering pirate zone triggers encounter
- Encounter affects ship (damage / cargo loss)
- Protection mechanic provides mitigation
- Storm zones affect ship handling

---

## Phase 16 — Monetization

**Goal:** Monetization implemented. Free gameplay unaffected.

**Systems created:**
- Ad integration (no ads during active sailing)
- Premium / No Ads purchase
- Starter Pack
- Ship skin system
- Custom company logo (TBD mechanic)

**Dependencies:** All prior phases

**Done when:**
- Ads shown only at appropriate moments
- Premium removes ads
- Skins apply correctly
- Free player can complete all content

---

## Phase 17 — Polish

**Goal:** Game is releasable.

**Work:**
- Audio (sfx + music, AudioManager complete)
- Achievements (all triggers implemented)
- UI polish and animations
- Performance optimization for low-end Android
- Full QA on save/load
- Accessibility: settings (volume, sensitivity, inversion)

**Dependencies:** All prior phases

**Done when:**
- Release build passes QA checklist
- No known crashes
- Save/load reliable on target devices
