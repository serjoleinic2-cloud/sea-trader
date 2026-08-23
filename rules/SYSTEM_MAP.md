# SYSTEM MAP

> How systems connect. Read this to understand data flow before touching any system.
> Last Updated: 2026-08-23 | Version: 0.1.0

---

## Ship Control Flow

```
Phone Accelerometer / Keyboard (debug)
        ↓
SensorInput
        ↓
InputAdapter  (normalize to -1..1)
        ↓
ShipControl
        ↓
ShipPhysics  (momentum, tilt, turn)
        ↓
ShipState  (position, velocity)
        ↓
WorldRenderer  (draw ship on map)
NavigationHUD  (compass arrow updates)
```

---

## Trade / Contract Flow

```
WorldGenerator → PortSystem → ResourceSystem
                     ↓
               ContractSystem  (generates contracts per port)
                     ↓
               Player accepts contract
                     ↓
               NavigationHUD  (compass → destination port)
                     ↓
               Player navigates manually (ShipControl flow above)
                     ↓
               Player arrives at destination port
                     ↓
               ContractSystem.complete()
                     ↓
               EconomyEngine  (calculate reward + time bonus)
                     ↓
               PlayerState.money += reward
               ProgressionSystem  (XP + reputation)
```

---

## Damage Flow

```
HazardSystem / Collision event
        ↓
DamageSystem
        ↓
ShipState (hull, engine, steering, cargo_hold reduced)
        ↓
ShipPhysics (applies reduced performance)
        ↓
Player docks at port
        ↓
PortSystem.repair()
        ↓
EconomyEngine (deduct repair cost)
        ↓
ShipState (component restored)
```

---

## Company Flow

```
CompanySystem
├── EmployeeManager
│     ├── hire/fire employees
│     ├── apply role bonuses (EconomyEngine, ContractSystem, etc.)
│     └── calculate salaries → EconomyEngine (daily expense)
│
├── FleetManager
│     ├── assign ship + captain to route
│     ├── auto-route runs (offline or background)
│     └── income → EconomyEngine
│
├── Finances
│     ├── salaries
│     ├── fleet maintenance
│     ├── taxes (TBD)
│     └── port infrastructure costs
│
├── Contracts (large contracts unlocked by Company level)
│
└── Port development (player's home port)
```

---

## Save / Load Flow

```
App launch
    ↓
SaveSystem.load()
    ├── read save_meta.json → check version
    ├── if version mismatch → migrate()
    ├── if corrupt → load save_backup.json
    └── deserialize → GameState
                ↓
        calculate_offline_progress(delta since last_session_timestamp)
            ├── FleetManager.apply_offline_routes()
            ├── CompanySystem.apply_offline_expenses()
            └── ResourceSystem.apply_price_drift()
                ↓
        Game ready

App background / quit
    ↓
SaveSystem.save()
    ├── write last_session_timestamp
    ├── copy save_main → save_backup
    ├── serialize GameState → save_main.json
    └── write checksum to save_meta.json
```

---

## World Generation Flow

```
WorldGenerationConfig (JSON)
        ↓
WorldGenerator.generate(seed)
        ├── SeaNoise → island shapes
        ├── IslandPlacer → island positions by region
        ├── PortGenerator → port per island (not all islands)
        ├── ResourceDistributor → resource types per region
        └── HazardPlacer → pirate zones, storm areas
                ↓
        WorldState (written once on new game)
                ↓
        Deterministic: same seed = same world, always
```

---

## Progression Flow

```
EventBus signals:
    contract_completed
    cargo_delivered
    port_discovered
    ship_upgraded
    company_action
        ↓
ProgressionSystem
    ├── PlayerState.xp += amount
    ├── check level_up thresholds
    ├── PlayerState.reputation += delta
    └── check unlock conditions
            ↓
    EventBus.emit(level_up) / EventBus.emit(unlock_available)
            ↓
    UI notifies player
```

---

## Offline Income Flow (Fleet)

```
SaveSystem reads last_session_timestamp
        ↓
delta_seconds = now - last_session_timestamp
delta_seconds = min(delta_seconds, MAX_OFFLINE_SECONDS)  [cap TBD]
        ↓
FleetManager
    for each fleet ship with active route:
        ├── simulate route completions in delta
        ├── calculate cargo income
        └── EconomyEngine.add_income(amount)
        ↓
CompanySystem
    ├── expenses = daily_rate * (delta / 86400)
    └── EconomyEngine.deduct(expenses)
```
