extends Node

signal changed

func catalog() -> Array:
	return GameData.read("res://data/social/shop_catalog.json").get("products", [])

func quote(id: String) -> Dictionary:
	var product: Dictionary = {}
	for item in catalog():
		if str(item.get("id", "")) == id: product = item.duplicate(true)
	if product.is_empty(): return {"ok": false, "message": "Товар не найден."}
	product["ok"] = bool(product.get("available", true))
	product["message"] = "" if product.ok else "Утверждённая локальная модель ещё не установлена."
	if str(product.kind) == "port_module":
		var own: Dictionary = preload("res://systems/social/clan_bonuses.gd").own_clan()
		if own.is_empty() or str(own.get("leader_id", "")) != str(GameState.player_state.get("social_id", "")):
			product.ok = false; product.message = "Крылья базы приобретает глава клана."
		elif int(own.get("base", {}).get("wings", 0)) >= int(product.maximum):
			product.ok = false; product.message = "Установлены все четыре крыла."
	if str(product.kind) == "unique_crew":
		if GameData.get_faction(str(GameState.player_state.get("origin_race_id", ""))).is_empty():
			product.ok = false; product.message = "Сначала выберите расу."
		if GameState.company_state.get("shop_owned", {}).has(id):
			product.ok = false; product.message = "Именной специалист уже приобретён."
	product["balance"] = float(GameState.player_state.get("money", 0))
	if float(product.balance) < float(product.price):
		product.ok = false; product.message = "Не хватает монет."
	return product

func purchase(id: String) -> Dictionary:
	var product: Dictionary = quote(id)
	if not bool(product.get("ok", false)): return product
	var before: Dictionary = {"company": GameState.company_state.duplicate(true), "player": GameState.player_state.duplicate(true), "economy": GameState.economy_state.duplicate(true), "employees": GameState.employee_state.duplicate(true)}
	var rewards: Dictionary = GameState.economy_state.get("rewards", {})
	match str(product.kind):
		"boost_pack":
			var inventory: Dictionary = rewards.get("boosts", {})
			for key in product.items: inventory[key] = int(inventory.get(key, 0)) + int(product.items[key])
			rewards["boosts"] = inventory
		"premium":
			var now: int = int(Time.get_unix_time_from_system())
			var end: int = maxi(now, int(rewards.get("premium_until", 0))) + int(product.days) * 86400
			if end - now > 30 * 86400: return {"ok": false, "message": "В запас можно активировать не более 30 дней премиума."}
			rewards["premium_until"] = end
		"port_module":
			var base: Dictionary = preload("res://systems/social/clan_bonuses.gd").own_clan().base
			base["wings"] = int(base.get("wings", 0)) + 1
		"unique_crew":
			var race_id: String = str(GameState.player_state.get("origin_race_id", "humans"))
			GameState.employee_state.append({"employee_instance_id": "shop_master_mechanic", "name": "Мастер гавани", "role_id": "mechanic", "role_name": "Механик", "race_id": race_id, "race_name": str(GameData.get_faction(race_id).get("name", race_id)), "portrait_id": 2, "rank": 1, "stats": {"repair": 3, "fuel": 1}, "base_stats": {"repair": 3, "fuel": 1}, "skill_stats": {}, "skills": [], "active_skill_id": "", "experience": 0, "employment_type": "permanent", "employment_name": "Постоянный", "assigned_to": "", "salary_per_voyage": 12.0, "contract_voyages_remaining": -1, "mastery_percent": 50, "strength_trait": "Мастер корпуса", "flaw_trait": "Обычная мореходная выучка"})
			var owned: Dictionary = GameState.company_state.get("shop_owned", {})
			owned[id] = true
			GameState.company_state["shop_owned"] = owned
		_: return {"ok": false, "message": "Этот товар пока недоступен."}
	GameState.economy_state["rewards"] = rewards
	GameState.player_state["money"] = float(GameState.player_state.money) - float(product.price)
	if not SaveSystem.save_game():
		GameState.company_state = before.company
		GameState.player_state = before.player
		GameState.economy_state = before.economy
		GameState.employee_state = before.employees
		return {"ok": false, "message": "Покупка не сохранена; деньги возвращены."}
	changed.emit()
	return {"ok": true, "message": "Приобретено: %s. Списано %.0f монет. Остаток: %.0f." % [str(product.name), float(product.price), float(GameState.player_state.money)]}
