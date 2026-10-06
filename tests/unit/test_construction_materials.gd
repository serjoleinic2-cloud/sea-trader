extends "res://tests/test_base.gd"

var materials = preload("res://systems/buildings/construction_materials.gd").new()
var buildings: Node
var fleet: Node
var shipyard: Node

func before_each() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	GameState.world_state.home_port_id = "home"
	GameState.ship_state.docked_port_id = "home"
	GameState.player_state.discovered_port_ids = ["home"]
	GameState.port_state["home"] = {"inventory":{"wood":20,"nails":8},"buildings":{"shipyard":{"level":1,"status":"active"}}}
	buildings = preload("res://systems/buildings/building_project_system.gd").new()
	add_child(buildings)
	buildings.set_process(false)
	fleet = preload("res://systems/fleet/fleet_system.gd").new()
	add_child(fleet)
	fleet.set_process(false)
	# Minimal ship definition keeps these transaction tests independent of balance.
	fleet._ship_types = {"test_ship":{"id":"test_ship","name":"Test ship","command_rank_required":1,"cargo_capacity":10}}
	shipyard = preload("res://systems/shipyard/shipyard_system.gd").new()
	add_child(shipyard)
	shipyard._fleet_system = fleet

func after_each() -> void:
	shipyard.free()
	fleet.free()
	buildings.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func _building_project() -> Dictionary:
	return {"building_id":"warehouse","target_level":2,"required_materials":{"wood":10,"nails":4},"materials":{},"required_rank":1,"required_ports":1,"started_at_unix":0,"duration_sec":60}

func test_shortage_never_partially_deducts_materials() -> void:
	var project: Dictionary = _building_project()
	var inventory := {"wood":20,"nails":3}
	var result: Dictionary = materials.reserve(project, inventory, {})
	assert_false(result.ok)
	assert_eq(inventory, {"wood":20,"nails":3})
	assert_eq(project.materials, {})

func test_old_reservations_only_charge_the_remaining_amount() -> void:
	var project: Dictionary = _building_project()
	project.materials = {"wood":6,"nails":4}
	var result: Dictionary = materials.reserve(project, {"wood":4,"nails":0}, {})
	assert_true(result.ok)
	assert_eq(result.inventory, {"wood":0,"nails":0})
	assert_eq(result.project.materials, {"wood":10,"nails":4})
	assert_eq(project.materials, {"wood":6,"nails":4}, "quoting and reserving do not mutate the old project")

func test_merchant_reservations_cannot_fund_construction() -> void:
	var economy := {"merchant":{"sell_orders":[{"resource_id":"wood","quantity_available":11,"status":"active"}]}}
	var status: Dictionary = materials.quote(_building_project(), {"wood":20,"nails":4}, economy)
	assert_false(status.ready)
	assert_eq(status.rows.wood.missing, 1)

func test_building_upgrade_starts_without_manual_transfer_and_charges_once() -> void:
	GameState.company_state.building_projects = [_building_project()]
	assert_true(buildings.get_start_status("warehouse").ok)
	assert_true(buildings.start_project("warehouse").ok)
	assert_eq(GameState.port_state.home.inventory, {"wood":10,"nails":4})
	assert_false(buildings.start_project("warehouse").ok)
	assert_eq(GameState.port_state.home.inventory, {"wood":10,"nails":4})
	assert_true(SaveSystem.load_game())
	assert_true(buildings.is_project_started(buildings.get_project("warehouse")))
	assert_eq(GameState.port_state.home.inventory, {"wood":10,"nails":4})

func test_ship_launch_saves_resources_project_and_fleet_together() -> void:
	GameState.company_state.shipyard_project = {"ship_type_id":"test_ship","name":"Test","required_materials":{"wood":10,"nails":4},"materials":{"wood":6}}
	assert_true(shipyard.get_build_status().ok)
	assert_true(shipyard.finish_project().ok)
	assert_eq(GameState.port_state.home.inventory, {"wood":16,"nails":4})
	assert_eq(GameState.fleet_state.size(), 1)
	assert_false(GameState.fleet_state[0].escort_enabled, "new ships wait for the player's manual escort choice")
	assert_true(shipyard.get_project().is_empty())
	assert_false(shipyard.finish_project().ok)
	assert_true(SaveSystem.load_game())
	assert_eq(GameState.fleet_state.size(), 1)
	assert_eq(GameState.port_state.home.inventory, {"wood":16,"nails":4})
	assert_true(shipyard.get_project().is_empty())
