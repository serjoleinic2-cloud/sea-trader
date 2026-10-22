extends Node

signal changed

func progression() -> Node:
	return get_tree().get_first_node_in_group("company_progression")

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
		product["preview"] = "harbor"
		product["preview_base"] = own.get("base", {}).duplicate(true)
		product.preview_base["wings"] = mini(4, int(product.preview_base.get("wings", 0)) + 1)
	if str(product.kind) == "unique_crew":
		if GameData.get_faction(str(GameState.player_state.get("origin_race_id", ""))).is_empty():
			product.ok = false; product.message = "Сначала выберите расу."
		if GameState.company_state.get("shop_owned", {}).has(id):
			product.ok = false; product.message = "Именной специалист уже приобретён."
	if str(product.kind) == "premium":
		var now: int = int(Time.get_unix_time_from_system())
		var rewards: Dictionary = GameState.economy_state.get("rewards", {})
		var active_seconds: int = maxi(0, int(rewards.get("premium_until", 0)) - now)
		var stored_seconds: int = int(rewards.get("premium_days", 0)) * 86400
		if active_seconds + stored_seconds + int(product.days) * 86400 > 30 * 86400:
			product.ok = false; product.message = "В запасе и активным сроком может быть не более 30 дней премиума."
	if str(product.kind) == "boost_pack":
		var boost_catalog: Dictionary = GameData.read("res://data/rewards/reward_catalog.json").get("boosts", {})
		product["contents"] = []
		var contents_valid: bool = not product.get("items", {}).is_empty()
		for boost_id in product.get("items", {}):
			var amount: int = int(product.items[boost_id])
			var definition: Dictionary = boost_catalog.get(str(boost_id), {})
			if definition.is_empty() or amount <= 0: contents_valid = false
			product.contents.append("%s × %d" % [str(definition.get("name", boost_id)), amount])
		if not contents_valid:
			product.ok = false; product.message = "Состав свитков в этом наборе настроен неверно."
	if str(product.kind) in ["training_scroll", "training_scroll_pack"]:
		var scroll_catalog: Dictionary = GameData.read("res://data/employees/training_scrolls.json").get("types", {})
		var scroll_items: Dictionary = {str(product.get("scroll_id", "")): 1} if str(product.kind) == "training_scroll" else product.get("items", {})
		product["contents"] = []
		for scroll_id in scroll_items:
			var amount: int = int(scroll_items[scroll_id])
			var definition: Dictionary = scroll_catalog.get(str(scroll_id), {})
			if definition.is_empty() or amount <= 0:
				product.ok = false; product.message = "Состав учебных брошюр настроен неверно."
			product.contents.append("%s × %d" % [str(definition.get("name", scroll_id)), amount])
		if scroll_items.is_empty(): product.ok = false
	if str(product.kind) == "resource_pack":
		var goods: Dictionary = {}
		for raw_good in GameData.read("res://data/resources/goods_catalog.json").get("resources", []):
			goods[str(raw_good.get("id", ""))] = raw_good
		product["contents"] = []
		var resources: Dictionary = product.get("items", {})
		for resource_id in resources:
			var amount: int = int(resources[resource_id])
			var definition: Dictionary = goods.get(str(resource_id), {})
			if definition.is_empty() or amount <= 0:
				product.ok = false; product.message = "Состав ресурсного ящика настроен неверно."
			product.contents.append("%s × %d" % [str(definition.get("display_name", resource_id)), amount])
		if resources.is_empty(): product.ok = false
	if str(product.kind) in ["cosmetic", "cosmetic_bundle", "season_cosmetics"]:
		var meta: Node = progression()
		if meta == null:
			product.ok = false; product.message = "Коллекция пока недоступна."
		else:
			var personal: Dictionary = meta.personal()
			if str(product.kind) == "season_cosmetics":
				if bool(personal.season_premium): product.ok = false; product.message = "Дополнительная дорожка уже открыта."
			else:
				var missing: int = 0
				for id_style in product.styles:
					if not personal.owned_styles.has(str(id_style)): missing += 1
				product["owned"] = missing == 0
				product["missing_styles"] = missing
				product.price = ceilf(float(product.price) * missing / maxi(1, product.styles.size()))
				if missing == 0: product.ok = false; product.message = "Уже в коллекции. Можно установить без оплаты."
			product["contents"] = []
			for style_id in product.get("styles", []):
				var style: Dictionary = meta.rules.styles.get(str(style_id), {})
				product.contents.append(str(style.get("name", style_id)))
				if str(product.kind) != "season_cosmetics" and str(style.get("slot", "")) == "harbor":
					var own_clan: Dictionary = preload("res://systems/social/clan_bonuses.gd").own_clan()
					if own_clan.is_empty() or str(own_clan.get("leader_id", "")) != str(GameState.player_state.get("social_id", "")):
						product.ok = false; product.message = "Оформление клановой гавани приобретает и устанавливает глава клана."
	product["balance"] = float(GameState.player_state.get("money", 0))
	if float(product.balance) < float(product.price):
		product.ok = false; product.message = "Не хватает монет."
	return product

func purchase(id: String) -> Dictionary:
	var product: Dictionary = quote(id)
	if not bool(product.get("ok", false)): return product
	var before: Dictionary = {"company": GameState.company_state.duplicate(true), "player": GameState.player_state.duplicate(true), "economy": GameState.economy_state.duplicate(true), "employees": GameState.employee_state.duplicate(true), "progression": GameState.progression_state.duplicate(true), "ports": GameState.port_state.duplicate(true)}
	var rewards: Dictionary = GameState.economy_state.get("rewards", {})
	match str(product.kind):
		"boost_pack":
			var inventory: Dictionary = rewards.get("boosts", {})
			for key in product.items: inventory[key] = int(inventory.get(key, 0)) + int(product.items[key])
			rewards["boosts"] = inventory
		"training_scroll", "training_scroll_pack":
			var inventory: Dictionary = GameState.progression_state.get("training_scroll_inventory", {}).duplicate(true)
			var items: Dictionary = {str(product.get("scroll_id", "")): 1} if str(product.kind) == "training_scroll" else product.get("items", {})
			for key in items: inventory[str(key)] = int(inventory.get(str(key), 0)) + int(items[key])
			GameState.progression_state["training_scroll_inventory"] = inventory
		"repair_kit":
			rewards["repair_kits"] = int(rewards.get("repair_kits", 0)) + int(product.get("amount", 1))
		"resource_pack":
			var home_id: String = str(GameState.world_state.get("home_port_id", ""))
			if home_id == "" or not GameState.port_state.has(home_id): return {"ok": false, "message": "Домашний склад недоступен."}
			var port: Dictionary = GameState.port_state[home_id]
			var inventory: Dictionary = port.get("inventory", {})
			for key in product.items: inventory[str(key)] = int(inventory.get(str(key), 0)) + int(product.items[key])
			port["inventory"] = inventory
			GameState.port_state[home_id] = port
		"premium":
			rewards["premium_days"] = int(rewards.get("premium_days", 0)) + int(product.days)
			GameState.economy_state["rewards"] = rewards
		"port_module":
			var base: Dictionary = preload("res://systems/social/clan_bonuses.gd").own_clan().base
			base["wings"] = int(base.get("wings", 0)) + 1
		"unique_crew":
			var race_id: String = str(GameState.player_state.get("origin_race_id", "humans"))
			GameState.employee_state.append({"employee_instance_id": "shop_master_mechanic", "name": "Мастер гавани", "role_id": "mechanic", "role_name": "Механик", "race_id": race_id, "race_name": str(GameData.get_faction(race_id).get("name", race_id)), "portrait_id": 2, "rank": 1, "stats": {"repair": 3, "fuel": 1}, "base_stats": {"repair": 3, "fuel": 1}, "skill_stats": {}, "skills": [], "active_skill_id": "", "experience": 0, "employment_type": "permanent", "employment_name": "Постоянный", "assigned_to": "", "salary_per_voyage": 12.0, "contract_voyages_remaining": -1, "mastery_percent": 50, "strength_trait": "Мастер корпуса", "flaw_trait": "Обычная мореходная выучка"})
			var owned: Dictionary = GameState.company_state.get("shop_owned", {})
			owned[id] = true
			GameState.company_state["shop_owned"] = owned
		"cosmetic", "cosmetic_bundle":
			for style_id in product.styles: progression().grant_style(str(style_id), "shop:" + id)
		"season_cosmetics":
			progression().personal()["season_premium"] = true
		_: return {"ok": false, "message": "Этот товар пока недоступен."}
	GameState.economy_state["rewards"] = rewards
	GameState.player_state["money"] = float(GameState.player_state.money) - float(product.price)
	var receipts: Array = GameState.company_state.get("purchase_receipts", [])
	receipts.append({"id": Crypto.new().generate_random_bytes(12).hex_encode(), "product": id, "currency": "money", "amount": float(product.price), "balance": float(GameState.player_state.money), "contents": product.get("contents", product.get("items", {})), "at": int(Time.get_unix_time_from_system()), "authority": "offline_coins"})
	while receipts.size() > 200: receipts.pop_front()
	GameState.company_state["purchase_receipts"] = receipts
	if not SaveSystem.save_game():
		GameState.company_state = before.company
		GameState.player_state = before.player
		GameState.economy_state = before.economy
		GameState.employee_state = before.employees
		GameState.progression_state = before.progression
		GameState.port_state = before.ports
		return {"ok": false, "message": "Покупка не сохранена; деньги возвращены."}
	changed.emit()
	return {"ok": true, "message": "Приобретено: %s. Списано %.0f монет. Остаток: %.0f." % [str(product.name), float(product.price), float(GameState.player_state.money)]}

func apply_product(id: String) -> Dictionary:
	var product: Dictionary = quote(id)
	if not bool(product.get("owned", false)) or progression() == null: return {"ok": false, "message": "Сначала получите оформление."}
	return progression().perform("equip_bundle", {"ids": product.get("styles", [])})

func payment_status() -> Dictionary:
	# A local save cannot create a verified payment or restore paid ownership.
	return {"enabled": false, "message": "Сейчас покупки только за игровые монеты. Реальная оплата и восстановление покупок будут доступны после подключения платформы и серверного учёта."}
