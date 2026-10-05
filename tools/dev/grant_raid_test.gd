extends Node

## Repeatable developer loadout requested by the owner. SaveSystem is the writer.
func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--grant-raid-test"):
		push_error("Explicit --grant-raid-test required")
		get_tree().quit(2)
		return
	if not SaveSystem.load_game(): get_tree().quit(3); return
	var before: Dictionary = SaveSystem._serialize_game_state()
	var id: String = "fleet_test_escort"
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_id == "" or not GameState.port_state.has(home_id):
		push_error("Home port is missing; test loadout was not granted")
		get_tree().quit(4)
		return
	var test_ship: Dictionary = {}
	for ship in GameState.fleet_state:
		if str(ship.get("instance_id", "")) == id:
			test_ship = ship
			break
	if test_ship.is_empty():
		test_ship = {"instance_id": id, "ship_type_id": "ship_combat_cutter", "name": "Тестовый боевой транспорт"}
		GameState.fleet_state.append(test_ship)
	test_ship.merge({
		"current_port_id": home_id,
		"status": "Сопровождает",
		"crew": [],
		"cargo": [],
		"cargo_capacity": 0,
		"autopilot": {},
		"hull": 145.0,
		"embarked_units": {
			"coast_guard": {"count": 30, "level": 1, "experience": 0},
			"crystal_mortar": {"count": 3, "level": 1, "experience": 0}
		},
		"escort_enabled": true,
		"escort_state": {}
	}, true)
	var inventory: Dictionary = GameState.port_state[home_id].get("inventory", {})
	for resource_id in ["resource_timber", "resource_fish", "resource_parts", "resource_oil", "resource_nails", "resource_fabric", "resource_rope", "resource_paint", "resource_varnish", "resource_glass"]:
		inventory[resource_id] = 1000
	GameState.port_state[home_id]["inventory"] = inventory
	GameState.player_state["money"] = maxf(float(GameState.player_state.get("money", 0.0)), 250000.0)
	GameState.ship_state["fuel"] = float(GameState.ship_state.get("fuel_max",100))
	GameState.company_state["raid_test_loadout_v1"] = {"transport_id":id,"soldiers":30,"guns":3,"refreshed_at":int(Time.get_unix_time_from_system())}
	if not SaveSystem.save_game():
		SaveSystem._deserialize_game_state(before)
		push_error("Could not save requested test loadout")
		get_tree().quit(5)
		return
	assert(SaveSystem.load_game())
	assert(GameState.company_state.raid_test_loadout_v1.transport_id == id)
	assert(GameState.fleet_state.filter(func(ship: Dictionary): return str(ship.get("instance_id", "")) == id).size() == 1)
	print("RAID_TEST_READY transport=Тестовый боевой транспорт soldiers=30 guns=3 money=", GameState.player_state.money, " home_resources=1000 fuel=",GameState.ship_state.fuel)
	get_tree().quit()
