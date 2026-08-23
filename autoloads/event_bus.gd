extends Node

## Global signal bus for decoupled communication.
## See SYSTEM_MAP.md for event flows.
## Systems emit here; other systems and UI listen.

# ============================================================================
# Ship events
# ============================================================================
signal ship_moved(position: Vector2, velocity: Vector2)
signal ship_damaged(component: String, amount: float)
signal ship_repaired(component: String, amount: float)

# ============================================================================
# World events
# ============================================================================
signal port_discovered(port_id: String)
signal region_entered(region_id: String)

# ============================================================================
# Economy events
# ============================================================================
signal contract_accepted(contract_id: String)
signal contract_completed(contract_id: String, reward: float)
signal contract_failed(contract_id: String)
signal cargo_loaded(resource_id: String, quantity: int)
signal cargo_delivered(resource_id: String, quantity: int)

# ============================================================================
# Progression events
# ============================================================================
signal xp_gained(amount: int)
signal level_up(new_level: int)
signal reputation_changed(new_value: float)
signal achievement_unlocked(achievement_id: String)
signal unlock_available(unlock_id: String)

# ============================================================================
# Company events
# ============================================================================
signal company_founded(company_name: String)
signal employee_hired(employee_id: String, role_id: String)
signal employee_fired(employee_id: String)
signal fleet_ship_added(ship_instance_id: String)

# ============================================================================
# Save / Load / Offline
# ============================================================================
signal game_saved()
signal game_loaded()
signal offline_progress_applied(delta_seconds: int)

# ============================================================================
# Navigation (UI listens; systems do not emit directly to UI methods)
# ============================================================================
signal navigation_destination_set(port_id: String)
signal navigation_destination_cleared()
