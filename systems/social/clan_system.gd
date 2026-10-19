extends Node

## Offline domain model. The same commands can later run on an authoritative server.
## No fabricated players, delivery acknowledgements or global online directory.
signal changed
signal boost_activated(stat: String, expires_at: int)

const Policy = preload("res://systems/social/social_text_policy.gd")
const Bonuses = preload("res://systems/social/clan_bonuses.gd")
var rules: Dictionary = {}
var test_now: int = -1
var _weekly_clock: float = 0.0

func _ready() -> void:
	add_to_group("clan_system")
	rules = GameData.read("res://data/social/clan_rules.json")
	ensure_state()

func now() -> int:
	return test_now if test_now >= 0 else int(Time.get_unix_time_from_system())

func ensure_state() -> void:
	if str(GameState.player_state.get("social_id", "")) == "":
		GameState.player_state["social_id"] = Crypto.new().generate_random_bytes(16).hex_encode()
	var state: Dictionary = GameState.company_state.get("social", {})
	state.merge({"version": 1, "profiles": {}, "clans": {}, "friend_requests": {}, "friends": {}, "blocks": {}, "private_messages": {}, "sequence": 0}, false)
	GameState.company_state["social"] = state
	var id: String = local_id()
	if not state.profiles.has(id):
		state.profiles[id] = {"id": id, "name": str(GameState.player_state.get("nickname", "Капитан " + id.left(6))), "race_id": str(GameState.player_state.get("origin_race_id", "humans")), "clan_id": "", "rank": 1, "join_after": 0, "last_week": -1}
	var profile: Dictionary = state.profiles[id]
	profile["race_id"] = str(GameState.player_state.get("origin_race_id", "humans"))
	profile["rank"] = maxi(1, int(GameState.progression_state.get("career", {}).get("highest_rank", 1)))
	profile["last_active_at"] = now()

func local_id() -> String:
	return str(GameState.player_state.get("social_id", ""))

func state() -> Dictionary:
	return GameState.company_state.get("social", {})

func profile(id: String = "") -> Dictionary:
	return state().get("profiles", {}).get(local_id() if id == "" else id, {})

func clan(id: String = "") -> Dictionary:
	return state().get("clans", {}).get(str(profile().get("clan_id", "")) if id == "" else id, {})

func directory() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in state().get("clans", {}).values():
		var row: Dictionary = entry.duplicate(true)
		var score: int = 0
		for id in entry.get("members", {}): score += int(profile(str(id)).get("rank", 1)) * 100
		row["points"] = score
		result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.points) > int(b.points) if int(a.points) != int(b.points) else str(a.name) < str(b.name))
	return result

func search_players(query: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for row in state().get("profiles", {}).values():
		if str(row.id) != local_id() and (query.strip_edges() == "" or str(row.name).to_lower().contains(query.strip_edges().to_lower())):
			found.append(row.duplicate(true))
	return found

func role(id: String = "") -> String:
	return str(clan().get("members", {}).get(local_id() if id == "" else id, {}).get("role", ""))

func perform(action: String, args: Dictionary = {}) -> Dictionary:
	ensure_state()
	var before_company: Dictionary = GameState.company_state.duplicate(true)
	var before_player: Dictionary = GameState.player_state.duplicate(true)
	var result: Dictionary = _command(action, args)
	if bool(result.get("ok", false)) and action not in ["message", "clan_message"] and not clan().is_empty():
		var journal: Array = clan().get("journal", [])
		journal.append({"actor": local_id(), "action": action, "at": now()})
		while journal.size() > 100: journal.pop_front()
		clan()["journal"] = journal
	if bool(result.get("ok", false)) and not SaveSystem.save_game():
		result = _result(false, "Не удалось сохранить изменения.")
	if not bool(result.get("ok", false)):
		GameState.company_state = before_company
		GameState.player_state = before_player
	else:
		changed.emit()
		if action == "boost": boost_activated.emit(str(args.get("stat", "")), int(clan().get("active_boosts", {}).get(str(args.get("stat", "")), 0)))
	return result

func _command(action: String, args: Dictionary) -> Dictionary:
	var own: Dictionary = clan()
	var actor: String = local_id()
	var target: String = str(args.get("player_id", ""))
	match action:
		"create": return _create(args)
		"nickname":
			var text: String = str(args.get("name", "")).strip_edges()
			var error: String = Policy.validate(text, 24, 3)
			if error != "": return _result(false, error)
			profile()["name"] = text
			GameState.player_state["nickname"] = text
			return _result(true, "Имя капитана сохранено.")
		"apply": return _apply(str(args.get("clan_id", "")))
		"friend_request", "friend_accept", "unfriend", "block", "message": return _social_action(action, args)
	if own.is_empty(): return _result(false, "Сначала вступите в клан.")
	match action:
		"rules":
			if role() != "leader": return _denied()
			var text: String = str(args.get("text", "")).strip_edges()
			var error: String = Policy.validate(text, 500, 0)
			if error != "": return _result(false, error)
			own["rules"] = text
			return _result(true, "Правила клана сохранены.")
		"logo":
			if role() != "leader": return _denied()
			var encoded: String = str(args.get("png", ""))
			var image := Image.new()
			if encoded.length() > 300000 or image.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) != OK or image.get_size() != Vector2i(200, 200):
				return _result(false, "Нужен PNG-логотип ровно 200×200 пикселей.")
			own["logo_png"] = encoded
			own["logo_revision"] = int(own.get("logo_revision", 0)) + 1
			return _result(true, "Логотип клана обновлён.")
		"review": return _review(target, bool(args.get("accept", false)))
		"role":
			if role() != "leader" or target == actor or not own.members.has(target): return _denied()
			var requested: String = str(args.get("role", "member"))
			if not requested in ["assistant", "recruiter", "member"]: return _denied()
			own.members[target]["role"] = requested
			return _result(true, "Должность изменена.")
		"kick", "blacklist":
			if role() not in ["leader", "assistant"] or target == actor or profile(target).is_empty(): return _denied()
			var target_role: String = str(own.members.get(target, {}).get("role", "member"))
			if target_role == "leader" or (role() == "assistant" and target_role != "member"): return _denied()
			if action == "blacklist":
				if role() != "leader": return _denied()
				own.blacklist[target] = true
			own.applications.erase(target)
			if own.members.has(target):
				own.members.erase(target)
				profile(target)["clan_id"] = ""
				profile(target)["join_after"] = now() + int(rules.join_cooldown_seconds)
			return _result(true, "Игрок внесён в чёрный список клана." if action == "blacklist" else "Участник исключён.")
		"unblacklist":
			if role() != "leader": return _denied()
			own.blacklist.erase(target)
			return _result(true, "Ограничение снято.")
		"leave":
			if role() == "leader": return _result(false, "Передайте руководство или расформируйте клан.")
			own.members.erase(actor)
			profile()["clan_id"] = ""
			profile()["join_after"] = now() + int(rules.join_cooldown_seconds)
			return _result(true, "Вы вышли из клана. Следующее вступление через 24 часа.")
		"transfer":
			if role() != "leader" or target == actor or not own.members.has(target): return _denied()
			own.members[actor]["role"] = "assistant"
			own.members[target]["role"] = "leader"
			own["leader_id"] = target
			return _result(true, "Руководство передано.")
		"dissolve":
			if role() != "leader" or str(args.get("confirm_name", "")) != str(own.name): return _result(false, "Для расформирования повторите название клана.")
			for id in own.members:
				profile(str(id))["clan_id"] = ""
				profile(str(id))["join_after"] = now() + int(rules.join_cooldown_seconds)
			for other in state().clans.values():
				other.peace.erase(str(own.id))
				other.peace_requests.erase(str(own.id))
			state().clans.erase(str(own.id))
			return _result(true, "Клан расформирован; личный прогресс сохранён.")
		"boost": return _activate_boost(str(args.get("stat", "")))
		"clan_message": return _clan_message(str(args.get("text", "")))
		"peace_offer", "peace_accept", "peace_break": return _diplomacy(action, str(args.get("clan_id", "")))
	return _result(false, "Действие не найдено.")

func _create(args: Dictionary) -> Dictionary:
	if not clan().is_empty(): return _result(false, "Вы уже состоите в клане.")
	if now() < int(profile().get("join_after", 0)): return _result(false, "После выхода действует пауза на вступление: 24 часа.")
	var name_text: String = str(args.get("name", "")).strip_edges()
	var error: String = Policy.validate(name_text, 32, 3)
	if error != "": return _result(false, error)
	for entry in state().clans.values():
		if str(entry.name).to_lower() == name_text.to_lower(): return _result(false, "Название уже занято.")
	var rules_text: String = str(args.get("rules", "")).strip_edges()
	error = Policy.validate(rules_text, 500, 0)
	if error != "": return _result(false, error)
	if GameData.get_faction(str(profile().get("race_id", ""))).is_empty(): return _result(false, "Сначала выберите расу капитана.")
	var home: String = str(GameState.world_state.get("home_port_id", ""))
	if home == "": return _result(false, "Сначала нужна собственная база.")
	if float(GameState.player_state.get("money", 0)) < float(rules.creation_price): return _result(false, "Не хватает монет на право создать клан.")
	state()["sequence"] = int(state().sequence) + 1
	var id: String = "clan_%s_%d" % [local_id().left(8), int(state().sequence)]
	var created: Dictionary = {"id": id, "name": name_text, "race_id": str(profile().race_id), "rules": rules_text, "logo_png": "", "leader_id": local_id(), "members": {}, "applications": {}, "blacklist": {}, "messages": [], "boost_progress": {}, "active_boosts": {}, "peace": {}, "peace_requests": {}, "created_at": now(), "base": {"owner_id": local_id(), "port_id": home, "kind": "clan_harbor", "wings": 0}}
	created.members[local_id()] = {"role": "leader", "joined_at": now()}
	state().clans[id] = created
	profile()["clan_id"] = id
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0)) - float(rules.creation_price)
	_contribute(profile(), created)
	return _result(true, "Клан создан. База компании получила статус базы клана; постройки и ресурсы сохранены.")

func _apply(id: String) -> Dictionary:
	var target: Dictionary = clan(id)
	if target.is_empty() or not clan().is_empty(): return _result(false, "Клан не найден или вы уже состоите в клане.")
	if str(target.race_id) != str(profile().race_id): return _result(false, "Клан принимает только свою расу.")
	if bool(target.blacklist.get(local_id(), false)) or _clan_blocks_local(target): return _result(false, "Заявки в этот клан недоступны.")
	if now() < int(profile().get("join_after", 0)): return _result(false, "После выхода вступление доступно через 24 часа.")
	if target.members.size() >= int(rules.maximum_members): return _result(false, "В клане нет свободных мест.")
	if target.applications.has(local_id()): return _result(false, "Ваша заявка уже ожидает решения.")
	target.applications[local_id()] = now()
	return _result(true, "Заявка подана.")

func _review(id: String, accept: bool) -> Dictionary:
	var own: Dictionary = clan()
	if role() not in ["leader", "assistant", "recruiter"]: return _denied()
	if not own.applications.has(id): return _result(false, "Заявка уже рассмотрена.")
	if accept:
		var person: Dictionary = profile(id)
		if person.is_empty() or str(person.get("clan_id", "")) != "" or str(person.race_id) != str(own.race_id) or bool(own.blacklist.get(id, false)) or own.members.size() >= int(rules.maximum_members) or int(person.get("join_after", 0)) > now():
			return _result(false, "Заявитель сейчас не может вступить в этот клан.")
		person["clan_id"] = str(own.id)
		own.members[id] = {"role": "member", "joined_at": now()}
		_contribute(person, own)
		for entry in state().clans.values(): entry.applications.erase(id)
	else:
		own.applications.erase(id)
	return _result(true, "Участник принят." if accept else "Заявка отклонена.")

func _activate_boost(stat: String) -> Dictionary:
	if role() != "leader": return _denied()
	if not rules.boosts.has(stat): return _result(false, "Буст не найден.")
	var active: Dictionary = clan().active_boosts
	if int(active.get(stat, 0)) > now(): return _result(false, "Буст уже действует; повторная активация не тратится.")
	var count: int = 0
	for expires in active.values():
		if int(expires) > now(): count += 1
	if count >= int(rules.maximum_active_boosts): return _result(false, "Одновременно действуют не более двух клановых бустов.")
	active[stat] = now() + int(rules.boost_duration_seconds)
	return _result(true, "Буст действует для всего клана 24 часа.")

func _contribute(person: Dictionary, target: Dictionary) -> bool:
	var week: int = floori(float(now()) / float(rules.weekly_seconds))
	if int(person.get("last_week", -1)) >= week: return false
	# One contribution per account per week, even after leaving/changing a clan.
	if now() - int(person.get("last_active_at", now())) > int(rules.weekly_seconds): return false
	person["last_week"] = week
	var keys: Array = rules.boosts.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:clan_contribution" % [str(person.id), week])
	var key: String = str(keys[rng.randi_range(0, keys.size() - 1)])
	var value: float = rng.randf_range(float(rules.weekly_min_percent), float(rules.weekly_max_percent))
	var cap: float = float(rules.boosts[key].cap_percent) - float(rules.boosts[key].base_percent)
	target.boost_progress[key] = minf(cap, float(target.boost_progress.get(key, 0)) + value)
	person["last_contribution"] = {"stat": key, "percent": value, "at": now()}
	return true

func _diplomacy(action: String, id: String) -> Dictionary:
	if role() != "leader": return _denied()
	var own: Dictionary = clan()
	var other: Dictionary = clan(id)
	if other.is_empty() or id == str(own.id): return _result(false, "Выберите другой клан.")
	if action == "peace_offer":
		if Bonuses.peace(str(own.id), id): return _result(false, "Мир уже заключён.")
		other.peace_requests[str(own.id)] = now()
		return _result(true, "Предложение мира отправлено главе клана.")
	if action == "peace_accept":
		if not own.peace_requests.has(id): return _result(false, "Нет предложения от этого клана.")
		own.peace[id] = true
		other.peace[str(own.id)] = true
		own.peace_requests.erase(id)
		other.peace_requests.erase(str(own.id))
	else:
		own.peace.erase(id)
		other.peace.erase(str(own.id))
		own.peace_requests.erase(id)
		other.peace_requests.erase(str(own.id))
	return _result(true, "Заключён мир: бои и дань между кланами приостановлены." if action == "peace_accept" else "Отношения нейтральные. Взаимные обязательства сняты.")

func _blocked(a: String, b: String) -> bool:
	if bool(state().blocks.get(a, {}).get(b, false)) or bool(state().blocks.get(b, {}).get(a, false)): return true
	var ca: Dictionary = clan(str(profile(a).get("clan_id", ""))) if str(profile(a).get("clan_id", "")) != "" else {}
	var cb: Dictionary = clan(str(profile(b).get("clan_id", ""))) if str(profile(b).get("clan_id", "")) != "" else {}
	return bool(ca.get("blacklist", {}).get(b, false)) or bool(cb.get("blacklist", {}).get(a, false))

func _clan_blocks_local(other: Dictionary) -> bool:
	return _blocked(local_id(), str(other.leader_id))

func _social_action(action: String, args: Dictionary) -> Dictionary:
	var actor: String = local_id()
	var id: String = str(args.get("player_id", ""))
	if profile(id).is_empty() or id == actor or id == "": return _result(false, "Выберите другого известного игрока.")
	var key: String = actor + ":" + id
	var reverse: String = id + ":" + actor
	if action == "block":
		if not state().blocks.has(actor): state().blocks[actor] = {}
		if bool(args.get("blocked", true)): state().blocks[actor][id] = true
		else: state().blocks[actor].erase(id)
		state().friend_requests.erase(key)
		state().friend_requests.erase(reverse)
		state().friends.erase(_pair(actor, id))
		return _result(true, "Настройка блокировки сохранена.")
	if _blocked(actor, id): return _result(false, "Общение и заявки между этими игроками заблокированы.")
	match action:
		"friend_request":
			if state().friends.has(_pair(actor, id)): return _result(false, "Вы уже друзья.")
			state().friend_requests[key] = now()
			return _result(true, "Запрос дружбы отправлен.")
		"friend_accept":
			if not state().friend_requests.has(reverse): return _result(false, "Нет запроса дружбы от этого игрока.")
			state().friend_requests.erase(reverse)
			state().friend_requests.erase(key)
			state().friends[_pair(actor, id)] = true
			return _result(true, "Игрок добавлен в друзья.")
		"unfriend":
			state().friends.erase(_pair(actor, id))
			return _result(true, "Игрок удалён из друзей.")
		"message":
			if not state().friends.has(_pair(actor, id)): return _result(false, "Личные сообщения доступны после подтверждения дружбы.")
			var text: String = str(args.get("text", "")).strip_edges()
			var error: String = Policy.validate(text, 400)
			if error != "": return _result(false, error)
			var pair: String = _pair(actor, id)
			var messages: Array = state().private_messages.get(pair, [])
			if not messages.is_empty() and str(messages[-1].get("sender", "")) == actor and now() - int(messages[-1].at) < 2: return _result(false, "Подождите пару секунд перед новым сообщением.")
			messages.append({"sender": actor, "text": text, "at": now()})
			while messages.size() > int(rules.maximum_messages): messages.pop_front()
			state().private_messages[pair] = messages
			return _result(true, "Сообщение сохранено локально. Онлайн-доставка пока не подключена.")
	return _denied()

func private_messages(id: String) -> Array:
	if _blocked(local_id(), id): return []
	return state().get("private_messages", {}).get(_pair(local_id(), id), []).duplicate(true)

func clan_messages() -> Array:
	var visible_messages: Array = []
	for message in clan().get("messages", []):
		if str(message.get("sender", "")) == local_id() or not _blocked(local_id(), str(message.get("sender", ""))): visible_messages.append(message.duplicate(true))
	return visible_messages

func _clan_message(text_value: String) -> Dictionary:
	var text: String = text_value.strip_edges()
	var error: String = Policy.validate(text, 400)
	if error != "": return _result(false, error)
	var messages: Array = clan().messages
	if not messages.is_empty() and str(messages[-1].sender) == local_id() and now() - int(messages[-1].at) < 2: return _result(false, "Подождите пару секунд перед новым сообщением.")
	messages.append({"sender": local_id(), "text": text, "at": now()})
	while messages.size() > int(rules.maximum_messages): messages.pop_front()
	return _result(true, "Сообщение сохранено локально. Общий чат потребует сервера.")

func _pair(a: String, b: String) -> String:
	return a + ":" + b if a < b else b + ":" + a

func _process(delta: float) -> void:
	_weekly_clock += delta
	if _weekly_clock < 60.0: return
	_weekly_clock = 0.0
	ensure_state()
	var before: Dictionary = GameState.company_state.duplicate(true)
	if not clan().is_empty() and _contribute(profile(), clan()):
		if SaveSystem.save_game(): changed.emit()
		else: GameState.company_state = before

func _denied() -> Dictionary:
	return _result(false, "У этой должности нет полномочий для действия.")

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
