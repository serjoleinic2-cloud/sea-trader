extends Node

## Local reward inventory. Offline items are NOT authoritative marketplace assets.
var _catalog: Dictionary = {}

func _ready() -> void:
	add_to_group("reward_system")
	_catalog = GameData.read("res://data/rewards/reward_catalog.json")

func get_state() -> Dictionary:
	return GameState.economy_state.get("rewards", {}).duplicate(true)

func get_catalog() -> Dictionary:
	return _catalog.duplicate(true)

func describe(reward: Dictionary) -> String:
	var amount: int = int(reward.get("amount", 1))
	match str(reward.get("kind", "")):
		"boost":
			return "%s × %d" % [str(_catalog.get("boosts", {}).get(str(reward.get("id", "")), {}).get("name", "Буст")), amount]
		"premium_days":
			return "Дни премиума: %d (активируете сами)" % amount
		"fragment":
			return "Часть артефакта «%s» × %d" % [str(_catalog.get("artifacts", {}).get(str(reward.get("id", "")), {}).get("name", "")), amount]
	return "Неизвестная награда"

func grant_once(claim_id: String, reward: Dictionary) -> Dictionary:
	# Called inside ChallengeSystem's claim transaction; caller persists both states together.
	var state: Dictionary = get_state()
	var ledger: Dictionary = state.get("claims", {})
	if claim_id == "" or ledger.has(claim_id):
		return {"ok": false, "message": "Эта награда уже получена."}
	var kind: String = str(reward.get("kind", ""))
	var id: String = str(reward.get("id", ""))
	var amount: int = int(reward.get("amount", 0))
	if amount <= 0:
		return {"ok": false, "message": "Некорректная награда."}
	if kind == "premium_days":
		state["premium_days"] = int(state.get("premium_days", 0)) + amount
	elif kind == "boost" and _catalog.get("boosts", {}).has(id):
		var boosts: Dictionary = state.get("boosts", {})
		boosts[id] = int(boosts.get(id, 0)) + amount
		state["boosts"] = boosts
	elif kind == "fragment" and _catalog.get("artifacts", {}).has(id):
		var fragments: Dictionary = state.get("fragments", {})
		fragments[id] = int(fragments.get(id, 0)) + amount
		state["fragments"] = fragments
	else:
		return {"ok": false, "message": "Награда отсутствует в каталоге."}
	ledger[claim_id] = true
	state["claims"] = ledger
	GameState.economy_state["rewards"] = state
	return {"ok": true, "message": "Получено: " + describe(reward)}

func activate_boost(id: String) -> Dictionary:
	var state: Dictionary = get_state()
	var definition: Dictionary = _catalog.get("boosts", {}).get(id, {})
	var inventory: Dictionary = state.get("boosts", {})
	if definition.is_empty() or int(inventory.get(id, 0)) <= 0:
		return {"ok": false, "message": "Бустов этого типа нет."}
	var active: Dictionary = state.get("active_boost", {})
	if float(active.get("seconds_remaining", 0)) > 0.0:
		return {"ok": false, "message": "Дождитесь окончания действующего буста."}
	inventory[id] = int(inventory[id]) - 1
	state["boosts"] = inventory
	state["active_boost"] = {"id": id, "seconds_remaining": float(definition.duration_seconds)}
	return _save_state(state, "Буст активирован. Его время идёт только при запущенной игре.")

func activate_premium(days: int = 1) -> Dictionary:
	var state: Dictionary = get_state()
	if days <= 0 or int(state.get("premium_days", 0)) < days:
		return {"ok": false, "message": "Нет доступных дней премиума."}
	state["premium_days"] = int(state.get("premium_days", 0)) - days
	state["premium_until"] = maxi(int(Time.get_unix_time_from_system()), int(state.get("premium_until", 0))) + days * int(_catalog.get("premium", {}).get("seconds_per_day", 86400))
	return _save_state(state, "Премиум активирован. Срок считается в календарных днях.")

func craft_artifact(id: String) -> Dictionary:
	var state: Dictionary = get_state()
	var definition: Dictionary = _catalog.get("artifacts", {}).get(id, {})
	var fragments: Dictionary = state.get("fragments", {})
	var needed: int = int(definition.get("fragments_required", 0))
	if needed <= 0 or int(fragments.get(id, 0)) < needed:
		return {"ok": false, "message": "Недостаточно частей артефакта."}
	fragments[id] = int(fragments[id]) - needed
	state["fragments"] = fragments
	var serial: int = int(state.get("artifact_serial", 0)) + 1
	state["artifact_serial"] = serial
	var items: Array = state.get("artifacts", [])
	items.append({"instance_id": "local_%s_%d" % [str(GameState.world_state.get("seed", 0)), serial], "definition_id": id, "origin": "challenge_crafting", "authority": "offline_prototype", "tradable": false})
	state["artifacts"] = items
	return _save_state(state, "Артефакт собран. Его можно установить в коллекции.")

func equip_artifact(instance_id: String) -> Dictionary:
	var state: Dictionary = get_state()
	if instance_id != "":
		var found: bool = false
		for item in state.get("artifacts", []):
			if str(item.get("instance_id", "")) == instance_id:
				found = true
		if not found:
			return {"ok": false, "message": "Артефакт не найден."}
	state["equipped_artifact"] = instance_id
	return _save_state(state, "Артефакт установлен." if instance_id != "" else "Артефакт снят.")

func get_bonus_percent(stat: String) -> float:
	var state: Dictionary = get_state()
	var bonus: float = 0.0
	if stat == "sale" and int(state.get("premium_until", 0)) > int(Time.get_unix_time_from_system()):
		bonus += float(_catalog.get("premium", {}).get("sale_bonus_percent", 0))
	var active: Dictionary = state.get("active_boost", {})
	var boost: Dictionary = _catalog.get("boosts", {}).get(str(active.get("id", "")), {})
	if float(active.get("seconds_remaining", 0)) > 0.0 and str(boost.get("stat", "")) == stat:
		bonus += float(boost.get("percent", 0))
	for item in state.get("artifacts", []):
		if str(item.get("instance_id", "")) == str(state.get("equipped_artifact", "")):
			var definition: Dictionary = _catalog.get("artifacts", {}).get(str(item.get("definition_id", "")), {})
			if str(definition.get("stat", "")) == stat:
				bonus += float(definition.get("percent", 0))
	return clampf(bonus, 0.0, float(_catalog.get("limits", {}).get(stat + "_bonus_percent", 0)))

func _process(delta: float) -> void:
	var state: Dictionary = GameState.economy_state.get("rewards", {})
	var active: Dictionary = state.get("active_boost", {})
	if float(active.get("seconds_remaining", 0)) > 0.0:
		active["seconds_remaining"] = maxf(0.0, float(active.seconds_remaining) - delta)
		state["active_boost"] = active
		GameState.economy_state["rewards"] = state

func _save_state(state: Dictionary, message: String) -> Dictionary:
	var before: Dictionary = get_state()
	GameState.economy_state["rewards"] = state
	if not SaveSystem.save_game():
		GameState.economy_state["rewards"] = before
		return {"ok": false, "message": "Не удалось сохранить награду."}
	return {"ok": true, "message": message}
