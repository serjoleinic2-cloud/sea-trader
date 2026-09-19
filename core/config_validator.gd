extends RefCounted

## Pure validation: no GameState writes and no save I/O.
func validate(ships: Dictionary, goods: Dictionary, buildings: Dictionary, production: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var good_ids: Dictionary = _index(goods.get("resources"), "id", "goods_catalog.resources", errors)
	var ship_ids: Dictionary = _index(ships.get("ships"), "id", "ship_catalog.ships", errors)
	var building_ids: Dictionary = _index(buildings.get("buildings"), "building_id", "building_catalog.buildings", errors)
	if not ship_ids.has(str(ships.get("starter_ship_id", ""))):
		errors.append("ship_catalog.starter_ship_id: unknown ship")
	for id in good_ids:
		_positive(good_ids[id], "base_price", "goods." + str(id), errors)
	for id in ship_ids:
		var defaults: Variant = ships.get("defaults", {})
		if not defaults is Dictionary:
			errors.append("ship_catalog.defaults: expected object")
			return errors
		var resolved: Dictionary = defaults.duplicate(true)
		resolved.merge(ship_ids[id], true)
		for field in ["base_speed", "cargo_capacity", "fuel_capacity", "base_maneuverability", "hull_max", "engine_max", "steering_max", "cargo_hold_max", "min_crew", "max_crew", "command_rank_required", "tier", "acceleration", "deceleration", "brake_force", "turn_rate", "roll_smooth_speed"]:
			_positive(resolved, field, "ships." + str(id), errors)
		if int(resolved.get("min_crew", 0)) > int(resolved.get("max_crew", 0)):
			errors.append("ships." + str(id) + ": min_crew exceeds max_crew")
		_materials(resolved.get("build_materials"), good_ids, "ships." + str(id), errors)
	var recipes: Variant = production.get("recipes")
	if not recipes is Array:
		errors.append("production_recipes.recipes: expected array")
	else:
		for recipe in recipes:
			if not recipe is Dictionary:
				errors.append("production_recipes: expected object")
				continue
			if not building_ids.has(str(recipe.get("building_id", ""))) or not good_ids.has(str(recipe.get("resource_id", ""))):
				errors.append("production_recipes: unknown building or resource")
			_positive(recipe, "quantity_per_cycle", "production_recipes", errors)
	return errors

func validate_rewards(challenges: Dictionary, rewards: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var tiers: Dictionary = _index(challenges.get("tiers"), "id", "challenge_rules.tiers", errors)
	for kind in ["boosts", "artifacts", "premium", "limits"]:
		if not rewards.get(kind) is Dictionary:
			errors.append("reward_catalog." + kind + ": expected object")
	if not errors.is_empty():
		return errors
	for kind in ["boosts", "artifacts"]:
		for id in rewards[kind]:
			var definition: Variant = rewards[kind][id]
			if not definition is Dictionary:
				errors.append("reward_catalog." + kind + "." + str(id) + ": expected object")
				continue
			_positive(definition, "duration_seconds" if kind == "boosts" else "fragments_required", "reward_catalog." + str(id), errors)
			_positive(definition, "percent", "reward_catalog." + str(id), errors)
	for id in tiers:
		var tier: Dictionary = tiers[id]
		var durations: Variant = tier.get("duration_hours")
		if not durations is Array or durations.is_empty():
			errors.append("challenge_rules." + str(id) + ": duration_hours must be nonempty array")
		else:
			for hours in durations:
				_positive({"hours": hours}, "hours", "challenge_rules." + str(id), errors)
		for field in ["sales_per_capacity", "voyages", "distance", "renewal_seconds"]:
			_positive(tier, field, "challenge_rules." + str(id), errors)
		var reward: Variant = tier.get("reward")
		if not reward is Dictionary:
			errors.append("challenge_rules." + str(id) + ": reward must be object")
			continue
		_positive(reward, "amount", "challenge_rules." + str(id) + ".reward", errors)
		var kind: String = str(reward.get("kind", ""))
		if kind == "boost" and rewards.boosts.has(str(reward.get("id", ""))):
			continue
		if kind == "fragment" and rewards.artifacts.has(str(reward.get("id", ""))):
			continue
		if kind != "premium_days":
			errors.append("challenge_rules." + str(id) + ": unknown reward")
	return errors

func _index(rows: Variant, id_key: String, path: String, errors: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	if not rows is Array or rows.is_empty():
		errors.append(path + ": expected nonempty array")
		return result
	for row in rows:
		if not row is Dictionary:
			errors.append(path + ": expected object")
			continue
		var id: String = str(row.get(id_key, ""))
		if id == "" or result.has(id):
			errors.append(path + ": empty or duplicate ID '" + id + "'")
		else:
			result[id] = row
	return result

func _positive(record: Dictionary, key: String, path: String, errors: Array[String]) -> void:
	var value: Variant = record.get(key)
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) <= 0.0:
		errors.append(path + "." + key + ": expected positive number")

func check_positive(record: Dictionary, key: String, path: String, errors: Array[String]) -> void:
	_positive(record, key, path, errors)

func validate_building_rules(rules: Dictionary, buildings: Dictionary, goods: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = _index(buildings.get("buildings"), "building_id", "building_catalog", errors)
	var goods_ids: Dictionary = _index(goods.get("resources"), "id", "goods_catalog", errors)
	var bases: Variant = rules.get("base_materials")
	if not bases is Dictionary:
		errors.append("building_rules.base_materials: expected object")
		return errors
	for id in ids:
		_materials(bases.get(id), goods_ids, "building_rules." + str(id), errors)
	for field in ["growth_per_level", "growth_exponent", "duration_base_seconds", "duration_per_level_seconds", "ports_per_level_step"]:
		_positive(rules, field, "building_rules", errors)
	var additions: Variant = rules.get("additional_materials")
	if not additions is Array:
		errors.append("building_rules.additional_materials: expected array")
	else:
		for addition in additions:
			if not addition is Dictionary:
				errors.append("building_rules.additional_materials: expected object")
				continue
			_positive(addition, "from_level", "building_rules", errors)
			_materials(addition.get("materials"), goods_ids, "building_rules.additional_materials", errors)
	var gates: Variant = rules.get("rank_gates")
	if not gates is Array or gates.is_empty():
		errors.append("building_rules.rank_gates: expected nonempty array")
	else:
		var previous: int = 0
		for gate in gates:
			if not gate is Dictionary:
				errors.append("building_rules.rank_gates: expected object")
				continue
			_positive(gate, "rank", "building_rules.rank_gates", errors)
			_positive(gate, "through_level", "building_rules.rank_gates", errors)
			var level: int = int(gate.get("through_level", 0))
			if level <= previous:
				errors.append("building_rules.rank_gates: levels must increase")
			previous = level
	return errors

func _materials(value: Variant, goods: Dictionary, path: String, errors: Array[String]) -> void:
	if not value is Dictionary or value.is_empty():
		errors.append(path + ".build_materials: expected nonempty object")
		return
	for id in value:
		if not goods.has(id):
			errors.append(path + ".build_materials: unknown resource " + str(id))
		_positive(value, str(id), path + ".build_materials", errors)
