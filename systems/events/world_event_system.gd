extends Node

## Lightweight world events. Events are warnings now and feed future damage/insurance systems.

const EVENT_DURATION: int = 180
const EVENT_DELAY: int = 300

func _ready() -> void:
	add_to_group("world_event_system")

func _process(_delta: float) -> void:
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

func get_active_event() -> Dictionary:
	var raw_event: Variant = GameState.economy_state.get("world_event", {})
	return raw_event if raw_event is Dictionary else {}
