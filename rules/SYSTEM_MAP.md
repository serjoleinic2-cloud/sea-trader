# SYSTEM MAP

> How systems connect. Read this to understand data flow before touching any system.
> Last Updated: 2026-09-05 | Version: 0.3.0

---

## Ship Control Flow (Manual Voyage)

```
Phone Accelerometer / Keyboard (debug)
        |
        v
SensorInput
        |
        v
InputAdapter  (normalize to -1..1)
        |
        v
ShipControl
        |
        v
ShipPhysics  (momentum, tilt, turn)
        |
        v
ShipState  (position, velocity, fuel consumption)
        |
        v
WorldRenderer  (draw ship on map)
NavigationHUD  (compass arrow updates)
```

---

## World Load Flow (Permanent Seed)

```
App launch
        |
        v
SaveSystem.load()
        |-- WorldState.seed restored from save
        |
        v
WorldGenerator.generate(WorldState.seed)
        |-- same seed = same islands, ports, hazards
        |-- DOES NOT overwrite PortState or KnownRoutesState
        |
        v
PortSystem.restore_from_save(PortState)
        |-- discovery state, levels, buildings restored
        |
        v
KnownRoutesSystem.restore_from_save(KnownRoutesState)
        |-- known routes restored
        |
        v
World ready — player sees their persistent world + their persistent knowledge
```

> **Key invariant:** WorldGenerator is called with the saved seed. Never with a new random seed.
> A new random seed is generated **only** on new game creation.

---

## New Game Flow

```
Player starts new game
        |
        v
new_seed = timestamp + random()
GameState.world_state.seed = new_seed
GameState.world_state.world_gen_version = CURRENT_VERSION
        |
        v
WorldGenerator.generate(new_seed)
        |
        v
PortState = {} (empty — no ports discovered yet)
KnownRoutesState = {} (empty — no routes known yet)
PlayerState.discovered_port_ids = [] (empty)
        |
        v
SaveSystem.save()
```

---

## Route Discovery Flow

```
Player sails manually from Port A toward Port B
        |
        v
NavigationHUD  (compass arrow, distance)
        |
        v
Manual Voyage  (ShipControl flow above)
        |
        v
Player arrives at Port B
        |
        v
PortSystem.discover_port(port_b_id)    [if not already discovered]
        |-- PortState[port_b_id].discovered = true
        |-- PlayerState.discovered_port_ids.append(port_b_id)
        |
        v
KnownRoutesSystem.add_route(port_a_id, port_b_id)
        |-- route_key = normalize(port_a_id, port_b_id)   [alphabetical]
        |-- KnownRoutesState[route_key] = { ...route data }
        |-- route is now known in BOTH directions
        |
        v
EventBus.emit(route_discovered, port_a_id, port_b_id)
        |
        v
ProgressionSystem  (XP for route discovery)
```

---

## Port Discovery vs Known Route: Distinction

```
Port B exists in world  ←── generated from seed
        |
        ├── Player sails near Port B
        │       |
        │       v
        │   PortSystem.discover_port(B)
        │       |
        │       v
        │   PlayerState.discovered_port_ids ← B added   [PLAYER KNOWLEDGE]
        │   PortState[B].discovered = true               [PLAYER KNOWLEDGE]
        │       |
        │       v
        │   Port B is now VISIBLE to player (on map, selectable as destination)
        │       |
        │       └── Player sets B as destination → NavigationHUD shows arrow
        │
        └── Player completes manual voyage to B (from any port A)
                |
                v
            KnownRoutesSystem.add_route(A, B)            [PLAYER KNOWLEDGE]
                |
                v
            Auto-travel A↔B now available
            Fleet assignment A↔B now available
```

---

## Intermediary Ports / Route Segments

```
Player sails: Home → B → C → D  (each segment manually)

After Home→B:  KnownRoute(Home, B) established
After B→C:     KnownRoute(B, C) established
After C→D:     KnownRoute(C, D) established

Player's known network:
Home ↔ B ↔ C ↔ D

Note:
- KnownRoute(Home, C) does NOT exist automatically
- KnownRoute(Home, D) does NOT exist automatically
- A direct route Home→D requires manual passage Home→D
- Rules for chained automation (Home→B→C→D as one auto-trip) are TBD
```

---

## Known Route Automation Flow

```
Player selects Known Route  (A ↔ B, exists in KnownRoutesState)
        |
        v
KnownRoutesSystem.validate(A, B)  → true
        |
        v
VoyageSystem.start_automated_voyage(A, B)
        |   -- consumes Fuel / Supplies
        |   -- takes time (simulated or real-time background)
        |   -- may have risk (damage, delay, extra cost)
        |
        v
Voyage completes
        |
        v
EconomyEngine  (calculate net result)
        |
        v
PlayerState.money += reward
ShipState.fuel -= consumption
ShipState.hull -= damage (if any)
```

**Fleet auto-routes use the same Known Route system:**
```
FleetManager
        |
        v
For each fleet ship with active route:
        |   -- route MUST exist in KnownRoutesState
        |   -- captain employee required
        |   -- consumes Fuel / Supplies
        |   -- may have risk
        |   -- generates income over time
        |
        v
EconomyEngine.add_income(amount)
```

---

## Manual Voyage Save/Resume Flow

```
Player is on Manual Voyage
        |
        v
App exit / background
        |
        v
SaveSystem.save()
        |   -- ShipState (position, velocity, fuel, hull, cargo)
        |   -- VoyageState (route, leg, elapsed time, contract)
        |   -- WorldState (seed, current position, destination)
        |   -- PortState (Player Knowledge)
        |   -- KnownRoutesState (Player Knowledge)
        |   -- last_session_timestamp
        |
        v
App relaunch
        |
        v
SaveSystem.load()
        |
        v
WorldGenerator.generate(WorldState.seed)   ← same seed, same world
        |
        v
VoyageSystem.resume_voyage()
        |   -- restore ship position
        |   -- restore voyage state
        |   -- player continues from where they left off
        |
        v
No punishment. Ship did not sink. Cargo not lost.
```

---

## Trade / Contract Flow

```
WorldGenerator ← PortSystem ← ResourceSystem
                     |
                     v
               ContractSystem  (generates contracts per port)
                     |
                     v
               Player accepts contract
                     |
                     v
               NavigationHUD  (compass → destination port)
                     |
                     v
               Manual Voyage  (ShipControl flow above)
                     |
                     v
               Player arrives at destination port
                     |
                     v
               ContractSystem.complete()
                     |
                     v
               EconomyEngine  (calculate reward + time bonus)
                     |
                     v
               PlayerState.money += reward
               ProgressionSystem  (XP + reputation)
               KnownRoutesSystem.add_route()  (if new route)
```

---

## Damage Flow

```
HazardSystem / Collision event
        |
        v
DamageSystem
        |
        v
ShipState (hull, engine, steering, cargo_hold reduced)
        |
        v
ShipPhysics (applies reduced performance)
        |
        v
Player docks at port
        |
        v
PortSystem.repair()
        |
        v
EconomyEngine (deduct repair cost)
        |
        v
ShipState (component restored)
```

---

## Save / Load Flow (Full)

```
App launch
    |
    v
SaveSystem.load()
    |-- read save_meta.json → check version
    |-- if version mismatch → migrate()
    |-- if corrupt → load save_backup.json
    |-- deserialize → GameState
                |
                v
        WorldGenerator.generate(WorldState.seed)   ← PERMANENT SEED
                |
                v
        PortSystem.restore_from_save(PortState)    ← PLAYER KNOWLEDGE
        KnownRoutesSystem.restore(KnownRoutesState) ← PLAYER KNOWLEDGE
                |
                v
        calculate_offline_progress(delta since last_session_timestamp)
            |-- FleetManager.apply_offline_routes()  (Known Routes only)
            |-- CompanySystem.apply_offline_expenses()
            |-- ResourceSystem.apply_price_drift()
                |
                v
        if VoyageState.active:
            |-- VoyageSystem.resume_voyage()
                |
                v
        Game ready

App background / quit
    |
    v
SaveSystem.save()
    |-- write last_session_timestamp
    |-- copy save_main → save_backup
    |-- serialize GameState → save_main.json
    |   |-- includes WorldState.seed
    |   |-- includes PortState (Player Knowledge)
    |   |-- includes KnownRoutesState (Player Knowledge)
    |   |-- includes VoyageState if active
    |-- write checksum to save_meta.json
```

---

## World Generation Flow

```
WorldGenerationConfig (JSON)
        |
        v
WorldGenerator.generate(seed)   ← seed from WorldState, never from randi()
        |-- SeaNoise → island shapes
        |-- IslandPlacer → island positions by region
        |-- PortGenerator → port per island (not all islands)
        |-- ResourceDistributor → resource types per region
        |-- HazardPlacer → pirate zones, storm areas
                |
                v
        Returns world_data Dictionary (not written to GameState directly)
                |
                v
        Deterministic: same seed = same world, always

Note: WorldGenerator NEVER writes to PortState or KnownRoutesState.
Those are Player Knowledge and are managed by PortSystem and KnownRoutesSystem.
```

---

## Progression Flow

```
EventBus signals:
    contract_completed
    cargo_delivered
    port_discovered
    route_discovered
    ship_upgraded
    company_action
        |
        v
ProgressionSystem
    |-- PlayerState.xp += amount
    |-- check level_up thresholds
    |-- PlayerState.reputation += delta
    |-- check unlock conditions
            |
            v
    EventBus.emit(level_up) / EventBus.emit(unlock_available)
            |
            v
    UI notifies player
```

---

## Offline Income Flow (Fleet)

```
SaveSystem reads last_session_timestamp
        |
        v
delta_seconds = now - last_session_timestamp
delta_seconds = min(delta_seconds, MAX_OFFLINE_SECONDS)  [cap TBD]
        |
        v
FleetManager
    for each fleet ship with active route:
        |-- route MUST exist in KnownRoutesState
        |-- simulate route completions in delta
        |-- calculate cargo income
        |-- apply route risk (damage, delay)
        |-- EconomyEngine.add_income(amount)
        |
        v
CompanySystem
    |-- expenses = daily_rate * (delta / 86400)
    |-- EconomyEngine.deduct(expenses)
```
