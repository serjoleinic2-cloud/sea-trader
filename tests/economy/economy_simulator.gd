extends Node

## 180 calendar days, two foreground hours/day; no player saves or GameState writes.
## Uses the SAME market/production/voyage model as gameplay. Navigation is time-stepped.
const DAYS: int = 180
const STEP: int = 120
const START: int = 1800000000
var model = preload("res://systems/economy/economy_model.gd").new()
var failures: int = 0

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS") != "1":
		get_tree().quit(2)
		return
	var results: Array = []
	for seed_id in [42, 137, 991]:
		for setup in [
			["fixed_1", 1, "ship_sloop", false, 1000.0],
			["fixed_3", 3, "ship_sloop", false, 1000.0],
			["fixed_10", 10, "ship_sloop", false, 1000.0],
			["adaptive_1", 1, "ship_sloop", true, 1000.0],
			["adaptive_3", 3, "ship_sloop", true, 1000.0],
			["adaptive_10", 10, "ship_sloop", true, 1000.0],
			["schooner_3", 3, "ship_schooner", true, 1000.0],
			["tanker_1", 1, "ship_tanker", true, 1000.0],
			["poor_1", 1, "ship_sloop", true, 0.0]]:
			var result: Dictionary = simulate(setup, seed_id)
			results.append(result)
			print(JSON.stringify(result))
			await get_tree().process_frame
	var file: FileAccess = FileAccess.open("res://tests/economy/results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"days": DAYS, "hours_per_day": 2, "decision_step_seconds": STEP, "results": results, "invariant_failures": failures}, "  ") + "\n")
	print("ECONOMY scenarios=%d invariant_failures=%d" % [results.size(), failures])
	get_tree().quit(0 if failures == 0 else 1)

func simulate(setup: Array, seed_id: int) -> Dictionary:
	var count: int = int(setup[1])
	var definition: Dictionary = GameData.get_ship(str(setup[2]))
	var adaptive: bool = bool(setup[3])
	var money: float = float(setup[4])
	var initial: float = money
	var home: Dictionary = {"inventory": {}, "buildings": {"fishing_wharf": {"level": 1, "status": "active"}, "timber_yard": {"level": 1, "status": "active"}}}
	var recipes: Array = GameData.read("res://data/ports/production_recipes.json").recipes
	var ports: Dictionary = {}
	var distances: Dictionary = {}
	for index in range(4):
		var id: String = "sim_%d_%d" % [seed_id, index]
		ports[id] = {"market_stock": {"resource_timber": 10, "resource_fish": 10}}
		distances[id] = 800.0 + index * 1200.0
		model.refresh(ports[id], id, START)
	var costs: Dictionary = {}
	var ships: Array = []
	var crew: Array = []
	for index in range(count):
		var ids: Array = []
		for slot in range(int(definition.min_crew)):
			var id: String = "crew_%d_%d" % [index, slot]
			ids.append(id)
			crew.append({"employee_instance_id": id, "employment_type": "permanent", "salary_per_voyage": 36.0 if slot == 0 else 14.0})
		ships.append({"cargo_capacity": int(definition.cargo_capacity), "crew": ids, "state": "idle", "quantity": 0, "ready_at": 0})
	var fixed_port: String = str(ports.keys()[0])
	for id in ports:
		if model.profile(id, "resource_timber", START).accepted:
			fixed_port = str(id)
			break
	var spent: float = 0.0
	var earned: float = 0.0
	var sold: int = 0
	var blocked: int = 0
	var jobs: int = 0
	var job_ready: int = 0
	var checkpoints: Array = []
	for day in range(DAYS):
		for seconds in range(0, 7200, STEP):
			var now: int = START + day * 86400 + seconds
			for id in ports:
				model.refresh(ports[id], id, now)
			# Production runs only while the game is open, exactly twelve 10-second cycles.
			for cycle in range(int(STEP / 10)):
				for recipe in recipes:
					var production: Dictionary = model.production_quote(home, recipe, money)
					if production.ok:
						money -= float(production.cost)
						spent += float(production.cost)
						home.inventory[recipe.resource_id] = int(home.inventory.get(recipe.resource_id, 0)) + int(production.quantity)
						home.buildings[recipe.building_id]["production_units"] = int(home.buildings[recipe.building_id].get("production_units", 0)) + int(production.quantity)
						for resource in production.inputs:
							home.inventory[resource] = int(home.inventory.get(resource, 0)) - int(production.inputs[resource])
			# Poor-player policy takes dock work; no simulated debt, interest or negative balance.
			if money < 400 and job_ready == 0:
				job_ready = now + int(model.rules.recovery.minimum_seconds)
			if job_ready > 0 and now >= job_ready:
				money += float(model.rules.recovery.reward)
				jobs += 1
				job_ready = 0
			for ship in ships:
				if str(ship.state) == "outbound" and now >= int(ship.ready_at):
					var quote: Dictionary = model.sale_quote(ports[ship.port], ship.port, ship.good, ship.quantity, now)
					if not quote.ok:
						blocked += 1
						continue
					ports[ship.port].market_stock[ship.good] = int(ports[ship.port].market_stock.get(ship.good, 0)) + int(ship.quantity)
					money += float(quote.revenue)
					earned += float(quote.revenue)
					sold += int(ship.quantity)
					ship.quantity = 0
					ship.state = "return_wait"
				if str(ship.state) == "return_wait":
					var cost: Dictionary = _cost(costs, ship, definition, crew, float(distances[ship.port]), 0)
					if money < float(cost.cash):
						blocked += 1
						continue
					money -= float(cost.cash)
					spent += float(cost.cash)
					ship.state = "returning"
					ship.ready_at = now + int(ceil(float(cost.duration)))
				if str(ship.state) == "returning" and now >= int(ship.ready_at):
					ship.state = "idle"
				if str(ship.state) != "idle":
					continue
				var best: Dictionary = {}
				var best_profit: float = 0.0
				var candidates: Array = ports.keys() if adaptive else [fixed_port]
				for id in candidates:
					for recipe in recipes:
						var good: String = str(recipe.resource_id)
						if not adaptive and good != "resource_timber":
							continue
						var amount: int = mini(int(ship.cargo_capacity), int(home.inventory.get(good, 0)))
						amount = mini(amount, model.demand(ports[id], id, good, now))
						if amount < 1:
							continue
						var sale: Dictionary = model.sale_quote(ports[id], id, good, amount, now)
						var outward: Dictionary = _cost(costs, ship, definition, crew, float(distances[id]), amount)
						var back: Dictionary = _cost(costs, ship, definition, crew, float(distances[id]), 0)
						var profit: float = float(sale.revenue) - float(outward.economic_cost) - float(back.economic_cost) - amount * float(recipe.cash_per_unit)
						if profit > best_profit and money >= float(outward.cash) + float(back.cash):
							best_profit = profit
							best = {"port": id, "good": good, "quantity": amount, "cost": outward}
					if not best.is_empty() and not adaptive:
						break
				if best.is_empty():
					blocked += 1
					continue
				money -= float(best.cost.cash)
				spent += float(best.cost.cash)
				home.inventory[best.good] -= int(best.quantity)
				ship.merge({"port": best.port, "good": best.good, "quantity": best.quantity, "state": "outbound", "ready_at": now + int(ceil(float(best.cost.duration)))}, true)
			if money < -0.001:
				failures += 1
			for quantity in home.inventory.values():
				if int(quantity) < 0 or int(quantity) > int(model.rules.production.default_stock_cap):
					failures += 1
		if day + 1 in [1, 30, 90, 180]:
			checkpoints.append({"day": day + 1, "money": snappedf(money, 0.01)})
	return {"scenario": setup[0], "seed": seed_id, "ships": count, "ship_type": setup[2], "initial_money": initial,
		"final_money": snappedf(money, 0.01), "trade_revenue": snappedf(earned, 0.01), "production_and_voyages": snappedf(spent, 0.01),
		"sold_units": sold, "blocked_decisions": blocked, "recovery_jobs": jobs, "checkpoints": checkpoints}

func _cost(cache: Dictionary, ship: Dictionary, definition: Dictionary, crew: Array, distance: float, quantity: int) -> Dictionary:
	# All fixture crews of a given scenario have identical salaries and zero skill modifiers.
	var key: String = "%d/%d" % [int(distance), quantity]
	if not cache.has(key):
		cache[key] = model.voyage_quote(ship, definition, crew, distance, quantity)
	return cache[key]
