extends "res://tests/test_base.gd"

var model = preload("res://systems/economy/economy_model.gd").new()
const AT: int = 1800000000
var market: Node

class Ports extends Node:
	func get_port_name(id: String) -> String: return id
	func get_port_position(_id: String) -> Vector2: return Vector2.ZERO

func before_each() -> void:
	GameState.reset_to_defaults()
	SaveSystem.delete_save()
	market = load("res://systems/economy/trade_line_system.gd").new()
	add_child(market)
	market.initialize(null, null)

func after_each() -> void:
	market.free()
	GameState.reset_to_defaults()
	SaveSystem.delete_save()

func test_same_port_arbitrage_is_negative_even_with_maximum_bonus() -> void:
	for id in model.prices:
		for port_id in ["p0", "p1", "p2", "p3", "p4"]:
			var port: Dictionary = {"market_stock": {id: 40}}
			var buy: Dictionary = model.purchase_quote(port, port_id, id, 20, AT)
			port.market_stock[id] -= 20
			var sale: Dictionary = model.sale_quote(port, port_id, id, 20, AT, 100.0)
			if sale.ok:
				assert_lt(sale.revenue, buy.cost, "Same-port resale " + id)

func test_batch_splitting_does_not_increase_revenue() -> void:
	var id: String = "resource_timber"
	var port_id: String = "p0"
	while not model.profile(port_id, id, AT).accepted:
		port_id += "x"
	var port: Dictionary = {"market_stock": {id: 0}}
	var batch: Dictionary = model.sale_quote(port, port_id, id, 30, AT)
	var split: float = 0.0
	for index in range(30):
		split += float(model.sale_quote(port, port_id, id, 1, AT).revenue)
		port.market_stock[id] += 1
	assert_almost_eq(batch.revenue, split, 0.001)
	assert_gt(model.unit_bid(port_id, id, 0, AT), model.unit_bid(port_id, id, 50, AT))

func test_saturation_does_not_reset_on_save_or_read() -> void:
	var id: String = "resource_timber"
	GameState.port_state["p0"] = {"market_stock": {id: 10000}}
	for index in range(10):
		assert_eq(market.get_market_info("p0", id).demand, 0)
	SaveSystem.save_game()
	GameState.reset_to_defaults()
	assert_true(SaveSystem.load_game())
	assert_eq(market.get_market_info("p0", id).demand, 0)
	assert_eq(GameState.port_state.p0.market_stock[id], 10000)

func test_elapsed_time_consumes_real_stock_once() -> void:
	var port: Dictionary = {"market_stock": {"resource_timber": 10000}}
	model.refresh(port, "p0", AT)
	var before: Dictionary = port.duplicate(true)
	model.refresh(port, "p0", AT + 120)
	assert_lt(port.market_stock.resource_timber, before.market_stock.resource_timber)
	var after: Dictionary = port.duplicate(true)
	model.refresh(port, "p0", AT + 120)
	assert_eq(after, port)
	model.refresh(port, "p0", AT - 120)
	assert_eq(after, port)

func test_large_distant_fleet_pays_more_and_contract_is_not_charged_twice() -> void:
	var employee: Dictionary = {"employee_instance_id": "c", "employment_type": "permanent", "salary_per_voyage": 36, "stats": {"fuel": -10}}
	var ship: Dictionary = {"crew": ["c"], "cargo_capacity": 50}
	var small: Dictionary = model.voyage_quote(ship, GameData.get_ship("ship_sloop"), [employee], 1000, 50)
	ship.cargo_capacity = 900
	var large: Dictionary = model.voyage_quote(ship, GameData.get_ship("ship_tanker"), [employee], 1000, 50)
	assert_gt(large.cash, small.cash)
	assert_gt(model.voyage_quote(ship, {}, [employee], 5000, 50).cash, large.cash)
	employee.employment_type = "contract"
	var prepaid: Dictionary = model.voyage_quote(ship, {}, [employee], 1000, 50)
	assert_almost_eq(large.cash - prepaid.cash, 36.0, 0.001)
	assert_almost_eq(large.economic_cost, prepaid.economic_cost, 0.001)

func test_production_cannot_drain_reserve_or_overfill_cap() -> void:
	var recipe: Dictionary = GameData.read("res://data/ports/production_recipes.json").recipes[0]
	var port: Dictionary = {"inventory": {"resource_fish": 99}, "buildings": {"fishing_wharf": {"level": 2, "status": "active"}}}
	assert_false(model.production_quote(port, recipe, 100.0).ok)
	var quote: Dictionary = model.production_quote(port, recipe, 200.0)
	assert_true(quote.ok)
	assert_eq(quote.quantity, 1)
	assert_eq(quote.cost, 2.0)
	port.buildings.fishing_wharf.level = 3
	port.buildings.fishing_wharf.production_units = 19
	assert_false(model.production_quote(port, recipe, 200.0).ok)
	port.inventory.resource_oil = 1
	assert_true(model.production_quote(port, recipe, 200.0).ok)
	var economy: Dictionary = {"merchant": {"sell_orders": [{"resource_id": "resource_oil", "quantity_available": 1}]}}
	assert_false(model.production_quote(port, recipe, 200.0, economy).ok)

func test_zero_money_single_port_has_work_and_debt_recovery() -> void:
	var ports: Node = Ports.new()
	add_child(ports)
	var work: Node = load("res://systems/contracts/work_hire_system.gd").new()
	add_child(work)
	work.initialize(ports)
	GameState.ship_state.docked_port_id = "home"
	GameState.player_state.discovered_port_ids = ["home"]
	GameState.economy_state.debt = 90.0
	assert_true(work.offer().local)
	assert_true(work.accept().ok)
	work._process(1.0)
	assert_eq(GameState.economy_state.debt, 90.0)
	GameState.economy_state.work_hire_contract.ready_at = 1
	work._process(1.0)
	assert_eq(GameState.economy_state.debt, 30.0)
	assert_true(work.accept().ok)
	GameState.economy_state.work_hire_contract.ready_at = 1
	work._process(1.0)
	assert_eq(GameState.economy_state.debt, 0.0)
	assert_eq(GameState.player_state.money, 12.0)
	work._process(1.0)
	assert_eq(GameState.player_state.money, 12.0)
	work.free()
	ports.free()

func test_aggregate_market_update_matches_individual_ticks() -> void:
	for id in ["p0", "p1", "p2", "p3"]:
		for amount in [0, 35, 5000]:
			var once: Dictionary = {"market_stock": {"resource_timber": amount, "resource_fish": amount}}
			model.refresh(once, id, AT)
			var stepped: Dictionary = once.duplicate(true)
			model.refresh(once, id, AT + 43200)
			for second in range(120, 43201, 120):
				model.refresh(stepped, id, AT + second)
			assert_eq(once, stepped)
