# DATA SCHEMA

> Data models for runtime state and static game data. These are schemas, not implementations.
> Last Updated: 2026-08-23 | Version: 0.1.0

---

## Runtime State (GameState)

All runtime state lives in `GameState` autoload. Sub-states are inner classes or resources.

### PlayerState
```
money: float              # current gold/currency
xp: int                   # total XP earned
level: int                # player level (derived from xp)
reputation: float         # 0.0–100.0
discovered_port_ids: []   # list of port_id strings
achievements: []          # list of achievement_id strings
stats:
  total_deliveries: int
  total_distance: float
  total_earned: float
```

### WorldState
```
seed: int                 # world generation seed
current_position: Vector2
current_region: String    # region_id
explored_region_ids: []
destination_port_id: String | null
last_session_timestamp: int  # Unix timestamp
```

### ShipState
```
ship_id: String           # references ShipData
position: Vector2         # redundant with WorldState? TBD
velocity: Vector2
hull: float               # 0.0–100.0
engine: float             # 0.0–100.0
steering: float           # 0.0–100.0
cargo_hold: float         # 0.0–100.0
cargo: []                 # list of CargoItem { resource_id, quantity }
fuel: float               # TBD if fuel exists
```

### PortState
```
# Dictionary: port_id → PortInstanceState
port_id:
  discovered: bool
  level: int
  buildings: {}           # building_id → { level, damage_hp }
  relationship: float     # TBD
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
balance: float            # separate from PlayerState.money? TBD
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
route: {}                 # { from_port_id, to_port_id, resource_id } | null
condition: {}             # same as ShipState components
```

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

## Static Data (JSON files in /data/)

Static data is read-only at runtime. Never modified by gameplay.

### ShipData (`data/ships/*.json`)
```json
{
  "id": "ship_sloop",
  "version": 1,
  "display_name": "Sloop",
  "base_speed": 120.0,
  "base_maneuverability": 0.85,
  "cargo_capacity": 50,
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

---

*Schema version must be incremented when any field is added, removed, or renamed. SaveSystem handles migration.*
