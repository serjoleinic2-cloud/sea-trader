extends "res://tests/test_base.gd"

var _ship: Node2D
var _ports: Node
var _pilot: Node
var _fleet: Node
var _market: Node
var _career: Node
var _transfers: Node
var _destination: String

func before_each() -> void:
	GameState.reset_to_defaults()
	SaveSystem.delete_save()
	_destination = "remote"
	while posmod(hash(_destination + "resource_timber"), 5) == 0:
		_destination += "x"
	_ship = load("res://scenes/game/ship/ship.tscn").instantiate()
	add_child(_ship)
	_ports = load("res://systems/ports/port_system.gd").new()
	add_child(_ports)
	_ports.initialize(_ship, {
		"home": {"name": "База", "position": Vector2(100, 100)},
		_destination: {"name": "Порт", "position": Vector2(500, 100)}
	})
	_ship.global_position = Vector2(100, 100)
	GameState.ship_state["position"] = _ship.global_position
	GameState.ship_state["docked_port_id"] = "home"
	GameState.ship_state["cargo"] = [{"resource_id": "resource_timber", "quantity": 5}]
	GameState.world_state["home_port_id"] = "home"
	GameState.world_state["last_docked_port_id"] = "home"
	GameState.player_state["money"] = 1000.0
	GameState.player_state["discovered_port_ids"] = ["home", _destination]
	GameState.known_routes_state = {"route": {"port_a_id": "home", "port_b_id": _destination, "distance": 400.0}}
	GameState.port_state = {"home": {"inventory": {"resource_timber": 50}, "buildings": {}},
		_destination: {"market_stock": {"resource_timber": 0}, "market_demand": {"resource_timber": 60}, "buildings": {}}}
	_pilot = load("res://systems/navigation/active_route_autopilot.gd").new()
	add_child(_pilot)
	_pilot.initialize(_ship, _ports)
	_fleet = load("res://systems/fleet/fleet_system.gd").new()
	add_child(_fleet)
	_fleet.initialize(_ports)
	_market = load("res://systems/economy/trade_line_system.gd").new()
	add_child(_market)
	_market.initialize(_ports, _fleet)
	_transfers = load("res://systems/economy/cargo_transfer_system.gd").new()
	add_child(_transfers)
	_transfers.initialize(_market)
	_career = load("res://systems/progression/career_system.gd").new()
	add_child(_career)

func after_each() -> void:
	for node in [_pilot, _transfers, _market, _fleet, _career, _ports, _ship]:
		node.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func _advance() -> void:
	_pilot._physics_process(1.0 / 60.0)
	_ship._physics_process(1.0 / 60.0)

func _add_fleet(with_captain: bool = true) -> void:
	GameState.employee_state = [{"employee_instance_id": "captain", "role_id": "captain", "contract_voyages_remaining": 10}]
	GameState.fleet_state = [{"instance_id": "aux", "ship_type_id": "ship_sloop", "current_port_id": "home",
		"cargo": [], "cargo_capacity": 20, "autopilot": {}, "crew": ["captain"] if with_captain else []}]

func _arrive_fleet() -> void:
	GameState.fleet_state[0]["autopilot"]["started_at"] = Time.get_unix_time_from_system() - 1000.0
	_fleet._process(0.1)

func test_zero_fuel_rejected_without_undocking() -> void:
	GameState.ship_state["fuel"] = 0.0
	var result: Dictionary = _pilot.start(_destination, "resource_timber", 5)
	assert_false(result.ok)
	assert_eq(GameState.ship_state.docked_port_id, "home")
	assert_false(bool(GameState.voyage_state.get("active_autopilot", false)))
	assert_true(str(result.message).contains("топлива"))

func test_missing_cargo_and_unknown_route_are_rejected() -> void:
	assert_false(_pilot.start(_destination, "resource_timber", 6).ok)
	GameState.known_routes_state.clear()
	assert_false(_pilot.start(_destination, "resource_timber", 5).ok)

func test_real_ship_physics_cannot_cancel_autopilot() -> void:
	assert_true(_pilot.start(_destination, "resource_timber", 5).ok)
	for index in range(60):
		_ship._physics.apply_control(-1.0, 1.0)
		_advance()
	assert_gt(GameState.ship_state.position.x, 190.0)
	assert_gt(GameState.ship_state.velocity.length(), 0.0)
	assert_lt(GameState.ship_state.fuel, 100.0)
	assert_eq(_ship.global_position, GameState.ship_state.position)
	assert_eq(GameState.world_state.current_position, GameState.ship_state.position)
	assert_gt(GameState.player_state.stats.total_distance, 90.0)

func test_resume_after_json_save_load_and_exactly_one_sale() -> void:
	assert_true(_pilot.start(_destination, "resource_timber", 5).ok)
	for index in range(20):
		_advance()
	SaveSystem.save_game()
	var position_before: Vector2 = GameState.ship_state.position
	_pilot.free()
	GameState.reset_to_defaults()
	assert_true(SaveSystem.load_game())
	_pilot = load("res://systems/navigation/active_route_autopilot.gd").new()
	add_child(_pilot)
	_pilot.initialize(_ship, _ports)
	_advance()
	assert_gt(GameState.ship_state.position.x, position_before.x)
	for index in range(300):
		_advance()
	assert_eq(GameState.ship_state.docked_port_id, _destination)
	assert_true(GameState.ship_state.cargo.is_empty())
	var money: float = float(GameState.player_state.money)
	assert_gt(money, 1000.0)
	for index in range(10):
		_advance()
	assert_eq(GameState.player_state.money, money)

func test_base_unload_does_not_pay_money() -> void:
	GameState.ship_state.docked_port_id = _destination
	GameState.ship_state.position = Vector2(500, 100)
	_ship.global_position = GameState.ship_state.position
	assert_true(_pilot.start("home", "resource_timber", 5).ok)
	for index in range(300):
		_advance()
	assert_eq(GameState.ship_state.docked_port_id, "home")
	assert_eq(GameState.player_state.money, 1000.0)
	assert_eq(GameState.port_state.home.inventory.resource_timber, 55)

func test_failed_fleet_departure_does_not_charge_or_remove_stock() -> void:
	_add_fleet(false)
	var result: Dictionary = _market.start_single_trip("aux", "home", _destination, "resource_timber", 5)
	assert_false(result.ok)
	assert_eq(GameState.player_state.money, 1000.0)
	assert_eq(GameState.port_state.home.inventory.resource_timber, 50)

func test_fleet_settles_once_at_actual_market_price() -> void:
	_add_fleet()
	var revenue: float = float(_market.quote_sale(_destination, "resource_timber", 5).revenue)
	var cost: float = float(_fleet.quote_leg("aux", "route", 5).cash)
	assert_true(_market.start_single_trip("aux", "home", _destination, "resource_timber", 5).ok)
	assert_eq(GameState.player_state.money, 1000.0 - float(_fleet.quote_leg("aux", "route", 5).cash))
	assert_eq(GameState.port_state.home.inventory.resource_timber, 45)
	assert_false(_market.start_single_trip("aux", "home", _destination, "resource_timber", 5).ok)
	assert_almost_eq(GameState.player_state.money, 1000.0 - float(_fleet.quote_leg("aux", "route", 5).cash), 0.001)
	_arrive_fleet()
	assert_eq(GameState.player_state.money, 1000.0 - cost + revenue)
	assert_eq(GameState.port_state[_destination].market_stock.resource_timber, 5)
	var money: float = GameState.player_state.money
	_fleet._process(1.0)
	assert_eq(GameState.player_state.money, money)
	assert_eq(GameState.employee_state[0].contract_voyages_remaining, 9)

func test_demand_disappeared_keeps_cargo_without_payment() -> void:
	_add_fleet()
	assert_true(_market.start_single_trip("aux", "home", _destination, "resource_timber", 5).ok)
	GameState.port_state[_destination]["market_stock"]["resource_timber"] = 100000
	_arrive_fleet()
	assert_almost_eq(GameState.player_state.money, 1000.0 - float(_fleet.quote_leg("aux", "route", 5).cash), 0.001)
	assert_eq(GameState.fleet_state[0].cargo[0].quantity, 5)
	assert_false(GameState.fleet_state[0].trade_receipt.ok)
	assert_false(_market.try_sell_to_port(_destination, "resource_timber", -1).ok)
	GameState.port_state[_destination]["market_stock"]["resource_timber"] = 0
	assert_true(_fleet.retry_trade("aux").ok)
	var money: float = GameState.player_state.money
	assert_gt(money, 1000.0 - float(_fleet.quote_leg("aux", "route", 5).cash))
	assert_false(_fleet.retry_trade("aux").ok)
	assert_eq(GameState.player_state.money, money)
	assert_eq(GameState.employee_state[0].contract_voyages_remaining, 9)

func test_fleet_contract_expires_on_arrival_and_blocks_next_trip() -> void:
	_add_fleet()
	GameState.employee_state[0]["contract_voyages_remaining"] = 1
	assert_true(_market.start_single_trip("aux", "home", _destination, "resource_timber", 5).ok)
	assert_false(_fleet.assign_employee("captain", "active_ship").ok)
	_arrive_fleet()
	assert_true(GameState.fleet_state[0].crew.is_empty())
	assert_true(GameState.employee_state.is_empty())
	assert_false(_market.start_single_trip("aux", _destination, "home", "resource_timber", 5).ok)

func test_career_transitions_and_maximum() -> void:
	GameState.player_state.stats = {"total_sales": 135}
	assert_eq(_career.get_command_progress().rank, 10)
	assert_eq(_career.get_command_progress().next_activity, 150)
	GameState.player_state.stats.total_sales = 150
	assert_eq(_career.get_command_progress().stage_id, "bosun")
	assert_eq(_career.get_command_progress().stage_level, 1)
	GameState.player_state.stats.total_sales = 100000
	assert_eq(_career.get_command_progress().rank, 50)
	assert_eq(_career.get_command_progress().next_activity, 0)
	assert_eq(_career.get_hiring_rank_limit(), 5)

func test_repeat_dock_undock_does_not_farm_experience() -> void:
	var score: int = _career.get_activity_score()
	for index in range(10):
		_ports.undock()
		_ports.dock("home")
	assert_eq(_career.get_activity_score(), score)

func test_every_career_boundary_has_a_reachable_next_rank() -> void:
	var stages: Array = SaveSystem._read_json("res://data/progression/career_ladder.json").stages
	for stage in stages:
		GameState.player_state.stats = {"total_sales": int(stage.activity_at_first_rank)}
		assert_eq(_career.get_command_progress().rank, int(stage.first_rank))
		assert_eq(_career.get_command_progress().stage_level, 1)
		GameState.player_state.stats.total_sales += 9 * int(stage.activity_per_rank)
		assert_eq(_career.get_command_progress().rank, int(stage.last_rank))
		assert_eq(_career.get_command_progress().stage_level, 10)
		if int(stage.last_rank) < 50:
			assert_gt(_career.get_command_progress().next_activity, _career.get_activity_score())

func test_signed_crew_bonuses_affect_autopilot_speed_and_fuel() -> void:
	GameState.ship_state["crew"] = ["captain"]
	GameState.employee_state = [{"employee_instance_id": "captain", "stats": {"speed": 3, "fuel": 4}}]
	assert_gt(_ship.get_navigation_speed(), 110.0)
	assert_lt(_pilot.fuel_needed(_destination), 1.2)
	GameState.employee_state[0].stats = {"speed": -3, "fuel": -4}
	assert_lt(_ship.get_navigation_speed(), 110.0)
	assert_gt(_pilot.fuel_needed(_destination), 1.2)

func test_shared_cargo_service_rejects_invalid_transfers_without_mutation() -> void:
	var ship: Dictionary = GameState.ship_state.duplicate(true)
	var ports: Dictionary = GameState.port_state.duplicate(true)
	assert_false(_transfers.execute("load", "resource_timber", -5).ok)
	assert_false(_transfers.execute("load", "resource_timber", 1000).ok)
	assert_false(_transfers.execute("load", "unknown", 1).ok)
	assert_false(_transfers.execute("sell", "resource_timber", 1).ok)
	assert_eq(GameState.ship_state, ship)
	assert_eq(GameState.port_state, ports)
	assert_eq(GameState.player_state.money, 1000.0)
	GameState.ship_state.cargo = [{"resource_id": "resource_timber", "quantity": 2}, {"resource_id": "resource_timber", "quantity": 3}]
	assert_true(_transfers.execute("unload", "resource_timber", 5).ok)
	assert_true(GameState.ship_state.cargo.is_empty())
	assert_eq(GameState.port_state.home.inventory.resource_timber, 55)

func test_repeating_line_charges_both_legs_and_stops_without_teleport() -> void:
	_add_fleet()
	assert_true(_market.create_line("aux", "home", _destination, "resource_timber", "", 5, 0.0).ok)
	var revenue: float = float(_market.quote_sale(_destination, "resource_timber", 5).revenue)
	var round_cost: float = float(_fleet.quote_leg("aux", "route", 5).cash) + float(_fleet.quote_leg("aux", "route", 0).cash)
	_arrive_fleet()
	_market._process(0.1)
	assert_almost_eq(GameState.player_state.money, 1000.0 - round_cost + revenue, 0.001)
	assert_eq(_market.get_lines()[0].earned, revenue)
	assert_almost_eq(_market.get_lines()[0].spent, round_cost, 0.001)
	_market.stop_line(_market.get_lines()[0].id)
	assert_eq(GameState.fleet_state[0].current_port_id, _destination)
	assert_false(GameState.fleet_state[0].autopilot.is_empty())
	_arrive_fleet()
	_market._process(0.1)
	assert_eq(GameState.fleet_state[0].current_port_id, "home")
	assert_true(GameState.fleet_state[0].autopilot.is_empty())
	assert_true(_market.resume_line(_market.get_lines()[0].id).ok)
	_market._process(0.1)
	assert_eq(_market.get_lines()[0].cycles, 1)
	assert_false(GameState.fleet_state[0].autopilot.is_empty())
	assert_eq(GameState.employee_state[0].contract_voyages_remaining, 8)

func test_unplanned_autopilot_is_paid_empty_repositioning_without_reward() -> void:
	_add_fleet()
	var cost: float = float(_fleet.quote_leg("aux", "route", 0).cash)
	assert_true(_fleet.start_autopilot("aux", "route").ok)
	assert_true(GameState.fleet_state[0].cargo.is_empty())
	assert_almost_eq(GameState.player_state.money, 1000.0 - cost, 0.001)
	_arrive_fleet()
	assert_almost_eq(GameState.player_state.money, 1000.0 - cost, 0.001)
	assert_true(GameState.fleet_state[0].cargo.is_empty())

func test_auxiliary_voyage_status_has_saved_route_progress_and_cargo() -> void:
	_add_fleet()
	assert_true(_fleet.start_autopilot("aux", "route", {"resource_id": "resource_timber", "quantity": 5}).ok)
	var started_at: float = float(GameState.fleet_state[0].autopilot.started_at)
	var duration: float = float(GameState.fleet_state[0].autopilot.duration_seconds)
	var status: Dictionary = _fleet.get_auxiliary_voyage_status("aux", started_at + duration * 0.5)
	assert_true(status.found)
	assert_true(status.in_transit)
	assert_eq(status.origin_port_id, "home")
	assert_eq(status.destination_port_id, _destination)
	assert_almost_eq(float(status.progress), 0.5, 0.01)
	assert_eq(status.cargo_units, 5)

func test_next_hull_unlocks_after_previous_career_stage() -> void:
	GameState.player_state.stats = {"total_sales": 135}
	assert_false(_fleet.get_ship_access("ship_barque").ok)
	GameState.player_state.stats = {"total_sales": 150}
	assert_true(_fleet.get_ship_access("ship_barque").ok)
	assert_false(_fleet.get_ship_access("ship_schooner").ok)
