# DATA SCHEMA

> Data models for runtime state and static game data. These are schemas, not implementations.
> Last Updated: 2026-09-10 | Version: 0.3.3

Implementation note: save format 0.2.0 now persists the existing schema below.
New games start with empty PortState; entries are created on discovery.
Legacy saves keep progression fields but lose generated geometry metadata during
migration. world_gen_version is the string form of the generation config version
(currently "1"); legacy generation was also version 1. Relationship remains TBD;
existing saved values are preserved, but new values are not invented.
Port template JSON now contains discovery_radius=150.0, moved unchanged from
the existing PortSystem constant; this remains provisional tuning, not final balance.

---

## Runtime State (GameState)

All runtime state lives in `GameState` autoload.

### Two-Layer Model: World vs Player Knowledge

**World Data** is regenerated from the permanent seed on every load. It does not need to be stored — it can always be reconstructed.

**Player Knowledge** is irreplaceable runtime state. It must be saved and restored independently of world generation. Loss of Player Knowledge = loss of player progress.

---

### PlayerState
```
money: float              # current gold/currency
xp: int                   # total XP earned
level: int                # player level (derived from xp)
reputation: float         # 0.0–100.0
discovered_port_ids: []   # [PLAYER KNOWLEDGE] list of port_id strings player has found
achievements: []          # list of achievement_id strings
stats:
  total_deliveries: int
  total_distance: float
  total_earned: float
```

### WorldState
```
seed: int                 # [PERMANENT] world generation seed — never overwritten after new game
world_gen_version: String # [NEW] algorithm version used to generate this world (for future migration)
current_position: Vector2
current_region: String    # region_id
explored_region_ids: []   # [PLAYER KNOWLEDGE] regions player has entered
destination_port_id: String | null
home_port_id: String          # player-designated primary port/base
last_session_timestamp: int  # Unix timestamp
```

> **Note:** `seed` in `WorldState` is written once on new game and must never be overwritten on load.
> `world_gen_version` is stored to enable safe migration if generation algorithm changes in the future.

### ShipState
```
ship_id: String           # references ShipData
position: Vector2
velocity: Vector2
hull: float               # 0.0–100.0
engine: float             # 0.0–100.0
steering: float           # 0.0–100.0
cargo_hold: float         # 0.0–100.0
cargo: []                 # list of CargoItem { resource_id, quantity }
fuel: float               # 0.0–100.0 (Fuel / Supplies)
fuel_max: float           # capacity, upgradeable
cargo_capacity: int       # max cargo units
```

### PortState
```
# Dictionary: port_id → PortInstanceState
# [PLAYER KNOWLEDGE] — must be saved and restored independently of world generation
port_id:
  discovered: bool        # true = player has visited this port
  level: int
  buildings: {}           # building_id → { level, damage_hp, status }
  inventory: {}           # resource_id → quantity, stock held at this port
  relationship: float     # TBD
```

> **Important:** `PortState` is Player Knowledge. It must not be overwritten by `WorldGenerator`.
> `WorldGenerator` provides the static world data (position, name, island_id).
> `PortSystem` manages `PortState` (discovery, level, buildings).

### KnownRoutesState
```
# [PLAYER KNOWLEDGE] Dictionary: route_key → KnownRoute
# route_key format: "port_a_id--port_b_id" (alphabetical order, bidirectional)
route_key:
  port_a_id: String       # always alphabetically first
  port_b_id: String       # always alphabetically second
  distance: float
  risk_level: String      # "low" | "medium" | "high"
  discovered_timestamp: int
  times_traveled: int     # total manual passages in either direction
```

> **Bidirectionality:** A single route record covers both A→B and B→A.
> Key is always normalized: alphabetically earlier port_id comes first.
> Example: "port_island_001--port_island_004" covers both directions.

> **Rule:** A route is only added to `KnownRoutesState` after the player arrives at the destination
> on a manual voyage. Automation and fleet assignment are only available for keys in this dictionary.

### VoyageState
```
# Active when player is on a manual voyage
active: bool
route: []                 # list of port_ids in planned order
current_leg: int          # index in route
start_port_id: String
destination_port_id: String
elapsed_time_seconds: float
total_distance: float
cargo: []                 # snapshot of ShipState.cargo at voyage start
fuel_at_start: float
hull_at_start: float
contract_id: String | null
status: String            # "planning" | "sailing" | "intermediary_stop" | "completed" | "failed"
```

### EconomyState
```
market: {}                # port_id → { resource_id → price }
last_market_update: int   # timestamp
active_contracts: []      # list of ContractInstance
completed_contract_ids: []
```

### ContractInstance
```
contract_id: String       # unique instance id
template_id: String       # references ContractData
origin_port_id: String
destination_port_id: String
resource_id: String
quantity: int
reward_base: float
reward_time_bonus: float  # multiplier or flat amount
deadline_timestamp: int
accepted_timestamp: int
status: enum [offered, active, completed, failed, expired]
```

### CompanyState
```
founded: bool
name: String
logo_config: {}           # TBD structure
flag_config: {}           # TBD
level: int
balance: float            # TBD: separate from PlayerState.money?
expenses_per_day: float   # calculated from employees + fleet + port
```

### EmployeeState
```
# List of hired employees
employee_instance_id: String
role_id: String           # references EmployeeData
name: String
salary: float
hired_timestamp: int
assigned_to: String | null  # ship_id or port_id
```

### FleetState
```
# List of fleet ships (not player's main ship)
ship_instance_id: String
ship_id: String           # references ShipData
captain_employee_id: String | null
route: {}                 # { port_a_id, port_b_id } | null — MUST be a KnownRoute
condition: {}             # same as ShipState components
```

> **Rule:** `FleetState[i].route` must reference a key that exists in `KnownRoutesState`.
> FleetManager must validate this before assigning a route.

### ProgressionState
```
player_level: int
player_xp: int
port_levels: {}           # port_id → level
company_level: int
unlocked_ship_ids: []
unlocked_upgrade_ids: []
unlocked_region_ids: []
```

### AchievementState
```
unlocked: []              # list of achievement_id
progress: {}              # achievement_id → current_value
```

### SettingsState
```
music_volume: float
sfx_volume: float
control_sensitivity: float
control_inversion: bool
language: String
```

---

## Save/Load: What Gets Saved vs Regenerated

| Data | Strategy |
|------|----------|
| `WorldState.seed` | Saved. Never regenerated. |
| `WorldState.world_gen_version` | Saved. Used for migration. |
| Island/port world data (positions, names) | **Regenerated** from seed on load. |
| `PortState` (discovered, level, buildings) | Saved. Player Knowledge. |
| `PlayerState.discovered_port_ids` | Saved. Player Knowledge. |
| `KnownRoutesState` | Saved. Player Knowledge. |
| `WorldState.explored_region_ids` | Saved. Player Knowledge. |
| All other GameState | Saved as usual. |

---

## Static Data (JSON files in /data/)

Static data is read-only at runtime. Never modified by gameplay.

### ShipData (`data/ships/*.json`)
```json
{
  "id": "ship_sloop",
  "version": 2,
  "display_name": "Sloop",
  "base_speed": 120.0,
  "base_maneuverability": 0.85,
  "cargo_capacity": 50,
  "fuel_capacity": 100,
  "hull_max": 100,
  "engine_max": 100,
  "steering_max": 100,
  "cargo_hold_max": 100,
  "unlock_level": 1,
  "cost": 500
}
```

### PortData (`data/ports/port_template.json`)
```json
{
  "id": "port_coastal_small",
  "display_name": "Small Coastal Port",
  "buildings": ["dock", "warehouse", "workshop"],
  "available_resources": [],
  "base_contract_count": 3,
  "unlock_level": 1
}
```

### ProductionRecipeData (data/ports/production_recipes.json)
```json
{
  "building_id": "fishing_wharf",
  "resource_id": "resource_fish",
  "quantity_per_cycle": 1,
  "required_building_level": 1
}
```

> Production recipes are static data. Active production buildings add their output to the home-port inventory; loading removes one unit from that inventory and adds it to ShipState.cargo.

### ResourceData (`data/resources/goods_catalog.json`)
```json
{
  "id": "resource_timber",
  "display_name": "Timber",
  "category": "raw_material",
  "base_price": 10,
  "weight_per_unit": 2,
  "regions": ["northern_coast"]
}
```

### ContractData (`data/contracts/contract_templates.json`)
```json
{
  "id": "contract_urgent_delivery",
  "type": "urgent",
  "base_reward_multiplier": 1.5,
  "time_bonus_per_minute_early": 5.0,
  "penalty_per_damage_point": 0.5,
  "min_level": 1
}
```

### EmployeeData (`data/employees/roles_catalog.json`)
```json
{
  "id": "role_captain",
  "display_name": "Captain",
  "base_salary": 50,
  "bonus_type": "fleet_route_efficiency",
  "bonus_value": 0.1,
  "unlock_level": 5
}
```

### UpgradeData (`data/upgrades/upgrades_catalog.json`)
```json
{
  "id": "upgrade_engine_mk2",
  "display_name": "Engine Mk.II",
  "target": "ship",
  "component": "engine",
  "stat": "speed",
  "value": 20.0,
  "cost": 800,
  "unlock_level": 3,
  "requires": []
}
```

### AchievementData (`data/achievements/achievements.json`)
```json
{
  "id": "ach_first_delivery",
  "display_name": "First Delivery",
  "description": "Complete your first contract",
  "trigger_event": "contract_completed",
  "condition": { "total_deliveries": 1 },
  "reward_xp": 50
}
```

### WorldGenerationConfig (`data/world/world_gen_config.json`)
```json
{
  "version": 1,
  "world_size": [4096, 4096],
  "island_density": 0.15,
  "port_per_island_chance": 0.6,
  "regions": [
    {
      "id": "starting_region",
      "bounds": [0, 0, 1024, 1024],
      "resources": ["resource_timber", "resource_fish"],
      "hazard_density": 0.05
    }
  ],
  "noise_scale": 0.003,
  "sea_threshold": 0.45
}
```

> **Note on world size:** The `world_size` field in config does not define the permanent identity of the world.
> World identity is the **seed**. World size/rendering strategy may evolve in future phases.

---

*Schema version must be incremented when any field is added, removed, or renamed. SaveSystem handles migration.*
