extends Node

## Single source of truth for all runtime data.
## See DATA_SCHEMA.md for full schema definitions.
## Do not hold game logic here — only state.

# ============================================================================
# Player State
# ============================================================================
var player_state: Dictionary = {
	"money": 0.0,
	"xp": 0,
	"level": 1,
	"reputation": 50.0,
	"discovered_port_ids": [],
	"achievements": [],
	"stats": {
		"total_deliveries": 0,
		"total_distance": 0.0,
		"total_earned": 0.0
	}
}

# ============================================================================
# World State
# ============================================================================
var world_state: Dictionary = {
	"seed": 0,
	"current_position": Vector2.ZERO,
	"current_region": "",
	"explored_region_ids": [],
	"destination_port_id": null,
	"last_session_timestamp": 0
}

# ============================================================================
# Ship State — Phase 03: added fuel_max, cargo_capacity
# ============================================================================
var ship_state: Dictionary = {
	"ship_id": "",
	"position": Vector2.ZERO,
	"velocity": Vector2.ZERO,
	"hull": 100.0,
	"engine": 100.0,
	"steering": 100.0,
	"cargo_hold": 100.0,
	"cargo": [],
	"fuel": 100.0,
	"fuel_max": 100.0,
	"cargo_capacity": 50
}

# ============================================================================
# Port State — Dictionary: port_id -> PortInstanceState
# ============================================================================
var port_state: Dictionary = {}

# ============================================================================
# Economy State
# ============================================================================
var economy_state: Dictionary = {
	"market": {},
	"last_market_update": 0,
	"active_contracts": [],
	"completed_contract_ids": []
}

# ============================================================================
# Company State
# ============================================================================
var company_state: Dictionary = {
	"founded": false,
	"name": "",
	"logo_config": {},
	"flag_config": {},
	"level": 0,
	"balance": 0.0,
	"expenses_per_day": 0.0
}

# ============================================================================
# Employee State — Array of hired employees
# ============================================================================
var employee_state: Array = []

# ============================================================================
# Fleet State — Array of fleet ships
# ============================================================================
var fleet_state: Array = []

# ============================================================================
# Progression State
# ============================================================================
var progression_state: Dictionary = {
	"player_level": 1,
	"player_xp": 0,
	"port_levels": {},
	"company_level": 0,
	"unlocked_ship_ids": [],
	"unlocked_upgrade_ids": [],
	"unlocked_region_ids": []
}

# ============================================================================
# Achievement State
# ============================================================================
var achievement_state: Dictionary = {
	"unlocked": [],
	"progress": {}
}

# ============================================================================
# Settings State
# ============================================================================
var settings_state: Dictionary = {
	"music_volume": 0.8,
	"sfx_volume": 0.8,
	"control_sensitivity": 1.0,
	"control_inversion": false,
	"language": "en"
}

# ============================================================================
# Monetization State
# ============================================================================
var monetization_state: Dictionary = {
	"no_ads_purchased": false,
	"premium_expiry": 0,
	"starter_pack_purchased": false
}

# ============================================================================
# Reset
# ============================================================================
func reset_to_defaults() -> void:
	player_state = {
		"money": 0.0,
		"xp": 0,
		"level": 1,
		"reputation": 50.0,
		"discovered_port_ids": [],
		"achievements": [],
		"stats": {
			"total_deliveries": 0,
			"total_distance": 0.0,
			"total_earned": 0.0
		}
	}
	world_state = {
		"seed": 0,
		"current_position": Vector2.ZERO,
		"current_region": "",
		"explored_region_ids": [],
		"destination_port_id": null,
		"last_session_timestamp": 0
	}
	ship_state = {
		"ship_id": "",
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"hull": 100.0,
		"engine": 100.0,
		"steering": 100.0,
		"cargo_hold": 100.0,
		"cargo": [],
		"fuel": 100.0,
		"fuel_max": 100.0,
		"cargo_capacity": 50
	}
	port_state = {}
	economy_state = {
		"market": {},
		"last_market_update": 0,
		"active_contracts": [],
		"completed_contract_ids": []
	}
	company_state = {
		"founded": false,
		"name": "",
		"logo_config": {},
		"flag_config": {},
		"level": 0,
		"balance": 0.0,
		"expenses_per_day": 0.0
	}
	employee_state = []
	fleet_state = []
	progression_state = {
		"player_level": 1,
		"player_xp": 0,
		"port_levels": {},
		"company_level": 0,
		"unlocked_ship_ids": [],
		"unlocked_upgrade_ids": [],
		"unlocked_region_ids": []
	}
	achievement_state = {
		"unlocked": [],
		"progress": {}
	}
	settings_state = {
		"music_volume": 0.8,
		"sfx_volume": 0.8,
		"control_sensitivity": 1.0,
		"control_inversion": false,
		"language": "en"
	}
	monetization_state = {
		"no_ads_purchased": false,
		"premium_expiry": 0,
		"starter_pack_purchased": false
	}
