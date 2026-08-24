# SYSTEM MAP

> How systems connect. Read this to understand data flow before touching any system.
> Last Updated: 2026-08-24 | Version: 0.2.0

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

## Route Discovery Flow

```
Player selects destination port (discovered or undiscovered)
        |
        v
NavigationHUD  (compass arrow, distance)
        |
        v
Manual Voyage  (ShipControl flow above)
        |
        v
Player arrives at destination port
        |
        v
PortSystem.discover_port()  (if new)
        |
        v
KnownRoutesSystem.add_route(origin, destination)
        |   -- route becomes Known in BOTH directions
        |
        v
EventBus.emit(route_discovered)
        |
        v
ProgressionSystem  (XP for discovery)
```

---

## Known Route Automation Flow

```
Player selects Known Route  (A <--[known]--> B)
        |
        v
KnownRoutesSystem.validate(route)  (must be known)
        |
        v
VoyageSystem.start_automated_voyage(route)
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
        |   -- route MUST be Known Route
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
        |   -- WorldState (current position, destination)
        |   -- last_session_timestamp
        |
        v
App relaunch
        |
        v
SaveSystem.load()
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
WorldGenerator -- PortSystem -- ResourceSystem
                     |
                     v
               ContractSystem  (generates contracts per port)
                     |
                     v
               Player accepts contract
                     |
                     v
               NavigationHUD  (compass -- destination port)
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

## Company Flow

```
CompanySystem
|-- EmployeeManager
|     |-- hire/fire employees
|     |-- apply role bonuses (EconomyEngine, ContractSystem, etc.)
|     |-- calculate salaries -- EconomyEngine (daily expense)
|
|-- FleetManager
|     |-- assign ship + captain to route
|     |-- route MUST be Known Route
|     |-- auto-route runs (offline or background)
|     |-- income -- EconomyEngine
|
|-- Finances
|     |-- salaries
|     |-- fleet maintenance
|     |-- taxes (TBD)
|     |-- port infrastructure costs
|
|-- Contracts (large contracts unlocked by Company level)
|
|-- Port development (player's home port)
```

---

## Save / Load Flow

```
App launch
    |
    v
SaveSystem.load()
    |-- read save_meta.json -- check version
    |-- if version mismatch -- migrate()
    |-- if corrupt -- load save_backup.json
    |-- deserialize -- GameState
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
    |-- copy save_main -- save_backup
    |-- serialize GameState -- save_main.json
    |   |-- includes VoyageState if active
    |-- write checksum to save_meta.json
```

---

## World Generation Flow

```
WorldGenerationConfig (JSON)
        |
        v
WorldGenerator.generate(seed)
        |-- SeaNoise -- island shapes
        |-- IslandPlacer -- island positions by region
        |-- PortGenerator -- port per island (not all islands)
        |-- ResourceDistributor -- resource types per region
        |-- HazardPlacer -- pirate zones, storm areas
                |
                v
        WorldState (written once on new game)
                |
                v
        Deterministic: same seed = same world, always
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
        |-- route MUST be Known Route
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
