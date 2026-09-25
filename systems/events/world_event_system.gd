extends Node

## Timed world alerts plus deterministic encounters when the player enters a hazard.

const EVENT_DURATION: int = 180
const EVENT_DELAY: int = 300
const HAZARD_RULES_PATH: String = "res://data/world/hazard_rules.json"

var _ship: Node2D
var _hazard_zones: Array = []
var _inside_zones: Dictionary = {}
var _hazard_rules: Dictionary = {}
var _previous_ship_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("world_event_system")


func initialize(ship: Node2D, world_data: Dictionary) -> void:
	_ship = ship
	_hazard_zones = world_data.get("hazard_zones", [])
	_hazard_rules = GameData.read(HAZARD_RULES_PATH)
	_previous_ship_position = Vector2(GameState.ship_state.get("position", Vector2.ZERO))


func _process(_delta: float) -> void:
	_tick_hazard_encounters()
	_tick_random_event()


func _tick_random_event() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var raw_event: Variant = GameState.economy_state.get("world_event", {})
	var active: Dictionary = raw_event if raw_event is Dictionary else {}
	if not active.is_empty() and now >= int(active.get("expires_at", 0)):
		GameState.economy_state["world_event"] = {}
		GameState.economy_state["next_world_event_at"] = now + EVENT_DELAY
		SaveSystem.save_game()
		return
	if not active.is_empty():
		return
	var next_at: int = int(GameState.economy_state.get("next_world_event_at", now + EVENT_DELAY))
	if now < next_at:
		return
	var event_ids: Array[String] = ["local_fire", "storm_warning", "pirate_rumor", "supply_disruption"]
	var messages: Array[String] = [
		"Пожарная тревога: проверьте мастерскую и запас запчастей.",
		"Штормовое предупреждение: дальние рейсы будут рискованнее.",
		"Слухи о пиратах: ценный груз лучше не держать без защиты.",
		"Сбой поставок: некоторые товары временно ценнее обычного."
	]
	var index: int = randi_range(0, event_ids.size() - 1)
	GameState.economy_state["world_event"] = {
		"id": event_ids[index],
		"message": messages[index],
		"expires_at": now + EVENT_DURATION
	}
	SaveSystem.save_game()


func _tick_hazard_encounters() -> void:
	if _ship == null or _hazard_zones.is_empty():
		return
	var current_position: Vector2 = Vector2(GameState.ship_state.get("position", _ship.global_position))
	for raw_zone in _hazard_zones:
		var zone: Dictionary = raw_zone
		if not bool(zone.get("active", false)):
			continue
		var zone_id: String = str(zone.get("id", ""))
		if zone_id == "":
			continue
		var center: Vector2 = Vector2(zone.get("position", Vector2.ZERO))
		var radius: float = maxf(0.0, float(zone.get("radius", 0.0)))
		var touches_zone: bool = _segment_touches_circle(_previous_ship_position, current_position, center, radius)
		var inside_now: bool = current_position.distance_to(center) <= radius
		var already_inside: bool = bool(_inside_zones.get(zone_id, false))
		if touches_zone and not already_inside:
			_inside_zones[zone_id] = true
			_resolve_hazard_entry(zone)
		elif inside_now:
			_inside_zones[zone_id] = true
		elif already_inside:
			_inside_zones.erase(zone_id)
	_previous_ship_position = current_position


func _segment_touches_circle(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> bool:
	var segment: Vector2 = finish - start
	var denominator: float = segment.length_squared()
	var factor: float = 0.0
	if denominator > 0.0001:
		factor = clampf((center - start).dot(segment) / denominator, 0.0, 1.0)
	return start.lerp(finish, factor).distance_to(center) <= radius


func _resolve_hazard_entry(zone: Dictionary) -> void:
	var zone_type: String = str(zone.get("type", "storm"))
	var types: Dictionary = _hazard_rules.get("types", {})
	var effect: Dictionary = types.get(zone_type, types.get("storm", {}))
	var zone_name: String = str(effect.get("name", "Опасная зона"))
	var now: int = int(Time.get_unix_time_from_system())
	var cooldowns: Dictionary = GameState.economy_state.get("hazard_cooldowns", {})
	var cooldown_seconds: int = int(_hazard_rules.get("reentry_cooldown_seconds", 300))
	var previous_hit: int = int(cooldowns.get(str(zone.get("id", "")), 0))
	if now - previous_hit < cooldown_seconds:
		_show_hazard_notice("Вы вошли в %s. Обплывайте отмеченную зону." % zone_name, now)
		return

	var consequences: Array[String] = []
	var hull_loss: float = _apply_component_damage("hull", float(effect.get("hull_damage", 0.0)))
	var engine_loss: float = _apply_component_damage("engine", float(effect.get("engine_damage", 0.0)))
	var steering_loss: float = _apply_component_damage("steering", float(effect.get("steering_damage", 0.0)))
	if hull_loss > 0.0:
		consequences.append("корпус −%.0f" % hull_loss)
	if engine_loss > 0.0:
		consequences.append("двигатель −%.0f" % engine_loss)
	if steering_loss > 0.0:
		consequences.append("руль −%.0f" % steering_loss)
	if bool(effect.get("steal_one_cargo", false)) and _steal_unsealed_cargo():
		consequences.append("потерян 1 груз")
	if consequences.is_empty():
		consequences.append("потерь нет, обплывайте её дальше")

	cooldowns[str(zone.get("id", ""))] = now
	GameState.economy_state["hazard_cooldowns"] = cooldowns
	var message: String = "%s: %s. Обплывайте опасные зоны." % [zone_name, ", ".join(consequences)]
	GameState.world_state["autopilot_notice"] = message
	_show_hazard_notice(message, now)
	SaveSystem.save_game()


func _apply_component_damage(component: String, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var current: float = float(GameState.ship_state.get(component, 100.0))
	# Weather and encounters must not strand the player below emergency-service range.
	var next_value: float = maxf(10.0, current - amount)
	var actual_loss: float = maxf(0.0, current - next_value)
	if actual_loss > 0.0:
		GameState.ship_state[component] = next_value
		EventBus.ship_damaged.emit(component, actual_loss)
	return actual_loss


func _steal_unsealed_cargo() -> bool:
	var cargo: Array = GameState.ship_state.get("cargo", [])
	for index in range(cargo.size() - 1, -1, -1):
		var item: Dictionary = cargo[index]
		if str(item.get("contract_id", "")) != "":
			continue
		var quantity: int = int(item.get("quantity", 0))
		if quantity <= 0:
			continue
		quantity -= 1
		if quantity == 0:
			cargo.remove_at(index)
		else:
			item["quantity"] = quantity
			cargo[index] = item
		GameState.ship_state["cargo"] = cargo
		return true
	return false


func _show_hazard_notice(message: String, now: int) -> void:
	GameState.economy_state["hazard_notice"] = {
		"id": "hazard_encounter",
		"message": message,
		"expires_at": now + int(_hazard_rules.get("notice_seconds", 15))
	}


func get_active_event() -> Dictionary:
	var now: int = int(Time.get_unix_time_from_system())
	var hazard: Variant = GameState.economy_state.get("hazard_notice", {})
	if hazard is Dictionary and not hazard.is_empty() and now < int(hazard.get("expires_at", 0)):
		return hazard
	var raw_event: Variant = GameState.economy_state.get("world_event", {})
	return raw_event if raw_event is Dictionary else {}
