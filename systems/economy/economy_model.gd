extends RefCounted

## Shared deterministic calculations used by live systems and long-horizon simulation.
## No wall clock, GameState, random draws or save I/O here. Time is an argument.
var rules: Dictionary
var prices: Dictionary = {}

func _init() -> void:
	rules = GameData.read("res://data/economy/balance_rules.json")
	for good in GameData.read("res://data/resources/goods_catalog.json").get("resources", []):
		prices[str(good.id)] = float(good.base_price)

func profile(port_id: String, resource_id: String, now: int) -> Dictionary:
	var config: Dictionary = rules.market
	var key: int = posmod(hash(port_id + resource_id), 10000)
	var phase: int = int(now / int(config.phase_seconds))
	var season: float = [0.65, 1.0, 1.35, 0.85][posmod(phase + key, 4)]
	var scale: int = int(config.hub_scale) if posmod(hash(port_id), 5) == 0 else 1
	return {"accepted": posmod(key, 5) != 0, "producer": posmod(key, 3) == 0,
		"target": maxi(1, int(float(config.target_stock) * scale * season)),
		"consumption": maxi(1, int(float(config.consumption_per_tick) * scale * season)),
		"output": int(config.producer_output_per_tick) * scale,
		"phase_seconds": int(config.phase_seconds) - posmod(now, int(config.phase_seconds))}

func refresh(port: Dictionary, port_id: String, now: int) -> void:
	var tick: int = int(rules.market.tick_seconds)
	var current: int = int(now / tick)
	var last: int = int(port.get("economy_tick", current))
	# Backward clock changes never credit consumption or production twice.
	if current < last:
		return
	var stock: Dictionary = port.get("market_stock", {})
	var index: int = maxi(last + 1, current - int(rules.market.catchup_ticks) + 1)
	while index <= current:
		var phase_ticks: int = maxi(1, int(int(rules.market.phase_seconds) / tick))
		var count: int = mini(current - index + 1, phase_ticks - posmod(index, phase_ticks))
		for id in prices:
			var p: Dictionary = profile(port_id, id, index * tick)
			var amount: int = int(stock.get(id, 0))
			var consumption: int = int(p.consumption)
			var remaining: int = count
			if not bool(p.producer):
				amount = maxi(0, amount - consumption * count)
			else:
				# Exact aggregate of repeated max(0, stock-consumption), then refill.
				var excess_ticks: int = mini(remaining, maxi(0, int((amount - int(p.target)) / consumption)))
				amount -= excess_ticks * consumption
				remaining -= excess_ticks
				if remaining > 0:
					amount = maxi(0, amount - consumption)
					if amount < int(p.target):
						amount = mini(int(p.target), amount + int(p.output))
					amount = clampi(amount + (int(p.output) - consumption) * (remaining - 1), mini(int(p.output), int(p.target)), maxi(amount, int(p.target)))
			stock[id] = amount
		index += count
	port["market_stock"] = stock
	port["economy_tick"] = current

func demand(port: Dictionary, port_id: String, resource_id: String, now: int) -> int:
	var p: Dictionary = profile(port_id, resource_id, now)
	return maxi(0, int(p.target) - int(port.get("market_stock", {}).get(resource_id, 0))) if p.accepted else 0

func unit_bid(port_id: String, resource_id: String, stock: int, now: int, bonus: float = 0.0) -> float:
	var p: Dictionary = profile(port_id, resource_id, now)
	if not p.accepted:
		return 0.0
	return _bid_at(resource_id, stock, int(p.target), bonus)

func _bid_at(resource_id: String, stock: int, target: int, bonus: float) -> float:
	var scarcity: float = clampf(1.0 - float(stock) / float(target), 0.0, 1.0)
	var factor: float = lerpf(float(rules.market.bid_floor), float(rules.market.bid_peak), scarcity)
	return snappedf(float(prices.get(resource_id, 0.0)) * factor * (1.0 + clampf(bonus, 0.0, float(rules.market.max_bonus))), 0.01)

func sale_quote(port: Dictionary, port_id: String, resource_id: String, quantity: int, now: int, bonus: float = 0.0) -> Dictionary:
	if not prices.has(resource_id) or quantity < 1 or quantity > demand(port, port_id, resource_id, now):
		return {"ok": false, "message": "Недостаточно спроса: %d ед. Товар остаётся у вас." % demand(port, port_id, resource_id, now), "revenue": 0.0}
	var stock: int = int(port.get("market_stock", {}).get(resource_id, 0))
	var revenue: float = 0.0
	var target: int = int(profile(port_id, resource_id, now).target)
	# Quote every marginal unit: splitting a batch cannot improve total proceeds.
	for index in range(quantity):
		revenue += _bid_at(resource_id, stock + index, target, bonus)
	return {"ok": true, "revenue": snappedf(revenue, 0.01), "unit_price": revenue / quantity}

func purchase_quote(port: Dictionary, port_id: String, resource_id: String, quantity: int, now: int) -> Dictionary:
	var stock: int = int(port.get("market_stock", {}).get(resource_id, 0))
	if not prices.has(resource_id) or quantity < 1 or quantity > stock:
		return {"ok": false, "message": "У поставщика недостаточно товара.", "cost": 0.0}
	var cost: float = 0.0
	var base: float = float(prices[resource_id])
	var p: Dictionary = profile(port_id, resource_id, now)
	for index in range(quantity):
		# Ask exceeds the maximum boosted resale bid at the resulting stock level.
		cost += maxf(base * 0.65, (_bid_at(resource_id, stock - index - 1, int(p.target), float(rules.market.max_bonus)) if p.accepted else 0.0)) + base * float(rules.market.spread)
	return {"ok": true, "cost": snappedf(cost, 0.01), "unit_price": cost / quantity}

func voyage_quote(ship: Dictionary, definition: Dictionary, employees: Array, distance: float, quantity: int) -> Dictionary:
	var config: Dictionary = rules.fleet
	var capacity: int = maxi(1, int(ship.get("cargo_capacity", definition.get("cargo_capacity", 50))))
	var crew: Array = ship.get("crew", [])
	var wages: float = 0.0
	var contract_cost: float = 0.0
	var fuel_bonus: float = 0.0
	var speed_bonus: float = 0.0
	var repair_bonus: float = 0.0
	for employee in employees:
		if not crew.has(str(employee.get("employee_instance_id", ""))):
			continue
		var salary: float = maxf(0.0, float(employee.get("salary_per_voyage", 0.0)))
		if str(employee.get("employment_type", "contract")) == "permanent":
			wages += salary
		else:
			contract_cost += salary # Already paid at hire; included only in profitability.
		for key in ["stats", "skill_stats"]:
			fuel_bonus += float(employee.get(key, {}).get("fuel", 0.0))
			speed_bonus += float(employee.get(key, {}).get("speed", 0.0))
			repair_bonus += float(employee.get(key, {}).get("repair", 0.0))
	var size_factor: float = 1.0 + float(capacity) / float(config.capacity_scale)
	var load_factor: float = 1.0 + float(config.load_factor) * clampf(float(quantity) / capacity, 0.0, 1.0)
	var fuel: float = maxf(0.0, distance) * float(config.fuel_per_distance) * size_factor * load_factor * clampf(1.0 - fuel_bonus / 100.0, 0.5, 1.5)
	var repair: float = maxf(0.0, distance) * float(config.wear_per_distance) * size_factor * float(config.repair_price) * clampf(1.0 - repair_bonus / 100.0, 0.5, 1.5)
	var food: float = crew.size() * float(config.food_per_person)
	var cash: float = snappedf(fuel * float(config.fuel_price) + repair + food + wages + float(config.port_fee), 0.01)
	var speed: float = float(definition.get("base_speed", 120)) * clampf(1.0 + speed_bonus / 100.0, 0.5, 1.5)
	return {"cash": cash, "economic_cost": cash + contract_cost, "fuel": fuel * float(config.fuel_price),
		"repair": repair, "food": food, "wages": wages, "prepaid_wages": contract_cost, "port_fee": float(config.port_fee),
		"duration": maxf(float(config.minimum_leg_seconds), distance / maxf(1.0, speed))}

func reserved(economy: Dictionary, resource_id: String) -> int:
	var amount: int = 0
	for order in economy.get("merchant", {}).get("sell_orders", []):
		if str(order.get("status", "active")) == "active" and str(order.get("resource_id", "")) == resource_id:
			amount += int(order.get("quantity_available", 0))
	return amount

func production_quote(port: Dictionary, recipe: Dictionary, money: float, economy: Dictionary = {}) -> Dictionary:
	var building: Dictionary = port.get("buildings", {}).get(str(recipe.get("building_id", "")), {})
	var level: int = int(building.get("level", 0))
	if level < int(recipe.get("required_building_level", 1)) or str(building.get("status", "")) != "active" or str(building.get("production_mode", "auto")) == "paused":
		return {"ok": false, "message": "Производство остановлено."}
	var cap: int = int(rules.production.default_stock_cap) + int(port.get("buildings", {}).get("warehouse", {}).get("level", 0)) * int(rules.production.warehouse_cap_per_level)
	if str(building.get("production_mode", "auto")) == "capped":
		cap = mini(cap, int(building.get("production_cap", cap)))
	var stock: Dictionary = port.get("inventory", {})
	var quantity: int = mini(int(recipe.quantity_per_cycle) * level, cap - int(stock.get(str(recipe.resource_id), 0)))
	if quantity <= 0:
		return {"ok": false, "message": "Лимит запаса достигнут: %d." % cap}
	var cost: float = float(recipe.get("cash_per_unit", 0.0)) * quantity
	if money - cost < float(rules.production.cash_reserve):
		return {"ok": false, "message": "Пауза: сохраняем резерв %.0f на выход в море." % float(rules.production.cash_reserve)}
	var inputs: Dictionary = {}
	var units: int = int(building.get("production_units", 0))
	if level >= int(recipe.get("inputs_from_level", 3)):
		var batch: int = maxi(1, int(recipe.get("input_batch_units", 20)))
		var batches: int = int((units + quantity) / batch) - int(units / batch)
		for id in recipe.get("inputs", {}):
			var required: int = int(recipe.inputs[id]) * batches
			if int(stock.get(id, 0)) - reserved(economy, id) < required:
				return {"ok": false, "message": "Пауза: нет расходных материалов для производства."}
			inputs[id] = required
	return {"ok": true, "quantity": quantity, "cost": cost, "inputs": inputs, "cap": cap}
