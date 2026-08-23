# ARCHITECTURE

> Approved system architecture. Do not restructure without owner decision.
> Last Updated: 2026-08-23 | Version: 0.1.0

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Engine | Godot 4.x |
| Language | GDScript (C# only if performance critical) |
| Platform | Android primary, iOS secondary |
| Persistence | Local filesystem (FileAccess + JSON) |
| Backend | None. Offline-first. |

---

## Architectural Principle

```
Static Data (JSON files)
        ↓
Runtime State (GameState autoload)
        ↓
Game Systems (process state, emit events)
        ↓
Presentation / UI (read state, show to player)
```

**Communication:**
- Systems read from and write to `GameState` directly when the dependency is obvious and local.
- Systems emit signals on `EventBus` when they need to notify other systems without creating a direct dependency.
- Direct references between systems are allowed when architecturally justified (e.g. `ShipControl` directly calls `ShipPhysics`).
- UI always reads from `GameState`, never holds game logic.

---

## Systems

### Core / Infrastructure

#### GameState
- **Responsibility:** Single source of truth for all runtime data.
- **Knows:** All state sub-objects (PlayerState, WorldState, ShipState, etc.)
- **Does not know:** Game rules, physics, rendering, UI
- **Dependencies:** None (autoload)

#### SaveSystem
- **Responsibility:** Serialize/deserialize GameState to disk. Handle versioning, backup, migration, offline progress.
- **Knows:** GameState structure, file paths, save format version
- **Does not know:** Game rules, UI, physics
- **Dependencies:** GameState

#### EventBus
- **Responsibility:** Global signal bus for decoupled communication.
- **Knows:** Signal definitions only
- **Does not know:** Any game logic
- **Dependencies:** None (autoload)

---

### Input / Sensors

#### SensorInput
- **Responsibility:** Read Android accelerometer. Emit normalized pitch/roll values.
- **Knows:** Android Input API
- **Does not know:** Ship physics, game rules
- **Dependencies:** Godot `Input`

#### InputAdapter
- **Responsibility:** Convert SensorInput values to ship control commands. In debug: read keyboard.
- **Knows:** SensorInput, ShipControl interface
- **Does not know:** Physics implementation, game state
- **Dependencies:** SensorInput → ShipControl

---

### Ship

#### ShipControl
- **Responsibility:** Translate normalized input (-1..1) into physics commands.
- **Knows:** ShipPhysics interface
- **Does not know:** Android API, input source, game economy
- **Dependencies:** InputAdapter (receives commands), ShipPhysics (sends commands)

#### ShipPhysics
- **Responsibility:** Apply movement, inertia, turning, visual tilt. Update position.
- **Knows:** Physics parameters from ShipData + ShipState
- **Does not know:** Input source, economy, UI
- **Dependencies:** GameState.ShipState (reads/writes position, velocity)

#### DamageSystem
- **Responsibility:** Calculate and apply damage to ship components. Check destruction conditions.
- **Knows:** ShipState, collision events, hazard data
- **Does not know:** Economy, contracts, UI
- **Dependencies:** GameState.ShipState, EventBus (emits damage events)

---

### World

#### WorldGenerator
- **Responsibility:** Generate deterministic world from seed. Islands, ports, resources, hazards.
- **Knows:** WorldGenerationConfig, noise algorithms, seed
- **Does not know:** Ship, economy, UI
- **Dependencies:** `data/world/world_gen_config.json`, GameState.WorldState (writes on first run)

#### PortSystem
- **Responsibility:** Manage port discovery, port state, port development, dock interactions.
- **Knows:** PortState, PortData (static), WorldState
- **Does not know:** Ship physics, economy formulas
- **Dependencies:** GameState.PortState, GameState.WorldState

#### ResourceSystem
- **Responsibility:** Manage resource availability, supply/demand, price fluctuation per port.
- **Knows:** ResourceData, PortState, EconomyState
- **Does not know:** Contracts, company, ship
- **Dependencies:** GameState.EconomyState, PortSystem

#### HazardSystem
- **Responsibility:** Manage pirate zones, storm areas. Trigger hazard events.
- **Knows:** WorldState (hazard zones), ShipState (position)
- **Does not know:** Economy, UI
- **Dependencies:** GameState.WorldState, GameState.ShipState, EventBus

---

### Economy

#### EconomyEngine
- **Responsibility:** Process all financial transactions. Buy/sell goods. Calculate costs.
- **Knows:** EconomyState, ResourceSystem prices, ContractSystem rewards
- **Does not know:** Physics, UI layout
- **Dependencies:** GameState.EconomyState, ResourceSystem, ContractSystem

#### ContractSystem
- **Responsibility:** Generate contracts, track active contracts, calculate rewards on delivery.
- **Knows:** ContractData templates, EconomyState, PortState, time/timestamp
- **Does not know:** Ship physics, UI
- **Dependencies:** GameState.EconomyState, PortSystem, EconomyEngine

#### ProgressionSystem
- **Responsibility:** Track XP, levels, reputation, unlock triggers.
- **Knows:** ProgressionState, unlock rules from data
- **Does not know:** Physics, UI
- **Dependencies:** GameState.ProgressionState, EventBus (listens for delivery/contract events)

---

### Company

#### CompanySystem
- **Responsibility:** Manage company creation, expenses calculation, finances.
- **Knows:** CompanyState, EmployeeState, FleetState
- **Does not know:** Ship physics, world generation
- **Dependencies:** GameState.CompanyState, EmployeeManager, FleetManager

#### EmployeeManager
- **Responsibility:** Hire/fire employees, apply role bonuses, calculate salaries.
- **Knows:** EmployeeData (static), EmployeeState
- **Does not know:** Ship physics, contracts
- **Dependencies:** GameState.CompanyState, EconomyEngine

#### FleetManager
- **Responsibility:** Manage additional ships, assign captains, run auto-routes, calculate offline income.
- **Knows:** FleetState, RouteData, EmployeeState
- **Does not know:** Player ship physics, active contracts
- **Dependencies:** GameState.FleetState, CompanySystem, SaveSystem (offline progress)

---

### Navigation

#### NavigationHUD
- **Responsibility:** Display compass arrow pointing to selected destination. Show distance.
- **Knows:** GameState.WorldState (ship position, destination)
- **Does not know:** Economy, contracts, port internals
- **Dependencies:** GameState.WorldState, GameState.ShipState

---

### Presentation

#### UI (screens)
- **Responsibility:** Display game state to player. Send player actions to systems.
- **Knows:** GameState (read-only for display)
- **Does not know:** Game logic, physics calculations
- **Rule:** No game logic in UI files.

#### AudioManager
- **Responsibility:** Play sfx and music. Works fully offline.
- **Knows:** Audio file paths, game events
- **Does not know:** Game logic, state
- **Dependencies:** EventBus (listens for events to trigger audio)

---

## Folder Structure

```
sea_trader/
├── autoloads/
│   ├── game_state.gd
│   ├── save_system.gd
│   └── event_bus.gd
├── data/
│   ├── ships/
│   ├── ports/
│   ├── resources/
│   ├── upgrades/
│   ├── employees/
│   ├── achievements/
│   └── world/
├── systems/
│   ├── input/
│   ├── ship/
│   ├── world/
│   ├── economy/
│   └── company/
├── scenes/
│   ├── game/
│   └── ui/
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
└── tests/
```
