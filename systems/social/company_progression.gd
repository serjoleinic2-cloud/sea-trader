extends Node

## Local activity/collection domain. All clocks and balances remain in GameState.
signal changed
signal activity_ready(message: String)
const DATA := "res://data/social/expeditions_and_collection.json"
var clans: Node
var rules: Dictionary
var test_now: int = -1
var _elapsed: float = 0.0

func _ready() -> void:
	add_to_group("company_progression")
	rules = GameData.read(DATA)
	clans = get_tree().get_first_node_in_group("clan_system")
	if clans != null:
		clans.changed.connect(sample)
		ensure_state()
		sample()

func now() -> int:
	return test_now if test_now >= 0 else int(Time.get_unix_time_from_system())

func _root() -> Dictionary:
	return GameState.company_state.get("activity_collection", {})

func ensure_state() -> void:
	if clans == null: return
	clans.ensure_state()
	var root: Dictionary = _root()
	root.merge({"version": 1, "profiles": {}, "clan_boards": {}}, false)
	GameState.company_state["activity_collection"] = root
	var id: String = clans.local_id()
	if not root.profiles.has(id):
		root.profiles[id] = {"season_started_at": now(), "season_points": 0, "season_claims": {}, "season_premium": false, "owned_styles": {}, "equipped": {}, "weekly": {}, "activity_claims": {}, "last_stats": _stats(), "last_clan": "", "clan_stats": _stats()}

func personal() -> Dictionary:
	ensure_state()
	return _root().get("profiles", {}).get(clans.local_id(), {}) if clans != null else {}

func _stats() -> Dictionary:
	var result: Dictionary = {}
	for activity in rules.get("activities", []): result[str(activity.stat)] = maxf(0, float(GameState.player_state.get("stats", {}).get(str(activity.stat), 0)))
	return result

func week() -> int:
	return maxi(floori(now() / float(rules.week_seconds)), int(personal().get("highest_week", 0)))

func sample() -> void:
	if clans == null: return
	var person: Dictionary = personal()
	var current: Dictionary = _stats()
	var index: int = week()
	person["highest_week"] = index
	var key: String = str(index)
	if not person.weekly.has(key): person.weekly[key] = {"progress": {}, "earned": {}}
	var weekly: Dictionary = person.weekly[key]
	var entry: Dictionary = clans.clan()
	var clan_id: String = str(entry.get("id", ""))
	if str(person.last_clan) != clan_id:
		person["last_clan"] = clan_id
		person["clan_stats"] = current.duplicate()
	var board: Dictionary = _board(entry, index) if clan_id != "" else {}
	var season_active: bool = now() < int(person.season_started_at) + int(rules.season.duration_days) * 86400
	for spec in rules.activities:
		var stat: String = str(spec.stat)
		var id: String = str(spec.id)
		var delta: float = maxf(0, float(current[stat]) - float(person.last_stats.get(stat, current[stat])))
		if season_active:
			weekly.progress[id] = minf(float(spec.target), float(weekly.progress.get(id, 0)) + delta)
			if float(weekly.progress[id]) >= float(spec.target) and not weekly.earned.has(id):
				weekly.earned[id] = true
				person.season_points = int(person.season_points) + int(spec.points)
				activity_ready.emit("Экспедиция: %s · +%d очков. Награды доступны в разделе «Экспедиция сезона»." % [str(spec.name), int(spec.points)])
		if not board.is_empty():
			var contribution: float = maxf(0, float(current[stat]) - float(person.clan_stats.get(stat, current[stat])))
			var task: Dictionary = board.tasks[id]
			var accepted: float = minf(contribution, maxf(0, float(spec.target) - float(task.contributors.get(clans.local_id(), 0))))
			if accepted > 0:
				task.progress = minf(float(spec.target), float(task.progress) + accepted)
				task.contributors[clans.local_id()] = float(task.contributors.get(clans.local_id(), 0)) + accepted
	person["last_stats"] = current
	person["clan_stats"] = current.duplicate()
	# Runtime only: existing autosave and explicit commands persist this state.
	# No periodic disk writes or per-frame scene rebuilds.

func _board(entry: Dictionary, index: int) -> Dictionary:
	var key: String = str(entry.id) + ":" + str(index)
	if not _root().clan_boards.has(key):
		var tasks: Dictionary = {}
		for spec in rules.activities: tasks[str(spec.id)] = {"progress": 0.0, "contributors": {}, "clan_claimed": false}
		_root().clan_boards[key] = {"week": index, "clan_id": str(entry.id), "tasks": tasks}
	return _root().clan_boards[key]

func expeditions() -> Array[Dictionary]:
	sample()
	var result: Array[Dictionary] = []
	var entry: Dictionary = clans.clan()
	if entry.is_empty(): return result
	for board in _root().clan_boards.values():
		if str(board.clan_id) != str(entry.id): continue
		for spec in rules.activities:
			var task: Dictionary = board.tasks[str(spec.id)]
			var claim: String = "%d:%s" % [int(board.week), str(spec.id)]
			var complete: bool = float(task.progress) >= float(spec.target)
			if int(board.week) != week() and (not complete or personal().activity_claims.has(claim)): continue
			var row: Dictionary = spec.duplicate(true)
			row.merge({"week": int(board.week), "progress": float(task.progress), "contributors": task.contributors.duplicate(), "complete": complete, "claimed": personal().activity_claims.has(claim), "eligible": float(task.contributors.get(clans.local_id(), 0)) > 0}, true)
			result.append(row)
	return result

func harbor() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var base: Dictionary = clans.clan().get("base", {})
	for spec in rules.harbor_modules:
		var row: Dictionary = spec.duplicate(true)
		var level: int = clampi(int(base.get("modules", {}).get(str(spec.id), 0)), 0, spec.costs.size())
		row.merge({"level": level, "price": int(spec.costs[level]) if level < spec.costs.size() else 0, "maximum": spec.costs.size(), "resource": int(base.get("expedition_resource", 0)), "can_manage": clans.role() in ["leader", "assistant"]}, true)
		result.append(row)
	return result

func season() -> Dictionary:
	sample()
	var result: Dictionary = rules.season.duplicate(true)
	result.merge({"points": int(personal().season_points), "premium": bool(personal().season_premium), "claims": personal().season_claims.duplicate(), "expires_at": int(personal().season_started_at) + int(rules.season.duration_days) * 86400}, true)
	return result

func grant_style(id: String, source: String) -> bool:
	if not rules.styles.has(id): return false
	if not personal().owned_styles.has(id): personal().owned_styles[id] = {"source": source, "at": now()}
	return true

func collection() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in rules.styles:
		var row: Dictionary = rules.styles[id].duplicate(true)
		row.merge({"id": str(id), "owned": personal().owned_styles.has(id), "equipped": str(personal().equipped.get(str(row.slot), "")) == str(id)}, true)
		result.append(row)
	return result

func perform(action: String, args: Dictionary = {}) -> Dictionary:
	sample()
	var before_company: Dictionary = GameState.company_state.duplicate(true)
	var before_player: Dictionary = GameState.player_state.duplicate(true)
	var before_economy: Dictionary = GameState.economy_state.duplicate(true)
	var result: Dictionary = _command(action, args)
	if bool(result.get("ok", false)) and not SaveSystem.save_game(): result = {"ok": false, "message": "Не удалось сохранить. Действие отменено."}
	if not bool(result.get("ok", false)):
		GameState.company_state = before_company
		GameState.player_state = before_player
		GameState.economy_state = before_economy
	else:
		changed.emit()
		if action in ["equip", "equip_bundle", "unequip", "harbor"]: EventBus.company_appearance_changed.emit()
	return result

func _command(action: String, args: Dictionary) -> Dictionary:
	var id: String = str(args.get("id", ""))
	match action:
		"simulate_test_voyages":
			var entry: Dictionary = clans.clan()
			if entry.is_empty() or clans.role() != "leader": return _fail("Тестовый состав доступен главе клана.")
			var testers: Array = []
			for member in entry.members:
				if bool(clans.profile(str(member)).get("is_test_profile", false)): testers.append(str(member))
			if testers.is_empty(): return _fail("В этом клане нет локальных псевдоигроков.")
			var board: Dictionary = _board(entry, week())
			var earned: int = 0
			for spec in rules.activities:
				var task: Dictionary = board.tasks[str(spec.id)]
				for tester in testers:
					var part: float = minf(float(spec.target) / testers.size(), maxf(0, float(spec.target) - float(task.progress)))
					task.progress = minf(float(spec.target), float(task.progress) + part)
					task.contributors[tester] = float(task.contributors.get(tester, 0)) + part
				if float(task.progress) >= float(spec.target) - 0.001:
					task.progress = float(spec.target)
					if not task.clan_claimed:
						entry.base["expedition_resource"] = int(entry.base.get("expedition_resource", 0)) + int(spec.clan_resource)
						task.clan_claimed = true; earned += int(spec.clan_resource)
			return _ok("Тестовые капитаны завершили свои рейсы. Клану начислено %d знаков. Казна и личные очки игрока не изменены." % earned)
		"expedition":
			for row in expeditions():
				if str(row.id) != id or int(row.week) != int(args.get("week", -1)): continue
				if not row.complete or row.claimed or not row.eligible: return _fail("Нужны завершённое задание и ваш вклад; повторная выдача исключена.")
				var board: Dictionary = _board(clans.clan(), int(row.week))
				var task: Dictionary = board.tasks[id]
				var base: Dictionary = clans.clan().base
				var clan_reward: int = 0
				if not task.clan_claimed:
					base["expedition_resource"] = int(base.get("expedition_resource", 0)) + int(row.clan_resource)
					clan_reward = int(row.clan_resource)
					task.clan_claimed = true
				personal().activity_claims["%d:%s" % [int(row.week), id]] = true
				GameState.player_state.money = float(GameState.player_state.money) + int(row.personal_coins)
				return _ok("Получено %d монет. %s" % [int(row.personal_coins), "Клану начислено %d знаков экспедиции." % clan_reward if clan_reward > 0 else "Клановые знаки за эту цель уже получены ранее."])
			return _fail("Задание не найдено.")
		"harbor":
			for row in harbor():
				if str(row.id) != id: continue
				if not row.can_manage: return _fail("Развитием гавани управляют глава и помощник.")
				if int(row.level) >= int(row.maximum): return _fail("Достигнут максимальный уровень.")
				if int(row.resource) < int(row.price): return _fail("Не хватает знаков экспедиции. Их зарабатывает клан.")
				var base: Dictionary = clans.clan().base
				base["expedition_resource"] = int(row.resource) - int(row.price)
				if not base.has("modules"): base["modules"] = {}
				base.modules[id] = int(row.level) + 1
				return _ok("%s: уровень %d. Списано %d знаков. Боевые параметры не изменены." % [str(row.name), int(row.level) + 1, int(row.price)])
			return _fail("Постройка не найдена.")
		"season":
			var index: int = int(args.get("index", -1))
			if index < 0 or index >= rules.season.milestones.size(): return _fail("Награда не найдена.")
			var paid: bool = bool(args.get("premium", false))
			var key: String = "%d:%s" % [index, "premium" if paid else "free"]
			var milestone: Dictionary = rules.season.milestones[index]
			if personal().season_claims.has(key): return _fail("Награда уже получена.")
			if int(personal().season_points) < int(milestone.points): return _fail("Недостаточно очков экспедиции.")
			if paid and not bool(personal().season_premium): return _fail("Нужен комплект сезонных украшений.")
			var reward: Dictionary = milestone["premium" if paid else "free"]
			GameState.player_state.money = float(GameState.player_state.money) + int(reward.get("coins", 0))
			if reward.has("style"): grant_style(str(reward.style), "season:" + str(rules.season.id))
			if reward.has("boosts"):
				if not GameState.economy_state.has("rewards"): GameState.economy_state["rewards"] = {}
				var state: Dictionary = GameState.economy_state.rewards
				if not state.has("boosts"): state["boosts"] = {}
				for boost in reward.boosts: state.boosts[boost] = int(state.boosts.get(boost, 0)) + int(reward.boosts[boost])
			personal().season_claims[key] = true
			return _ok("Сезонная награда получена. Предметы остаются в коллекции навсегда.")
		"equip", "unequip":
			if not rules.styles.has(id) or not personal().owned_styles.has(id): return _fail("Сначала получите это оформление.")
			var slot: String = str(rules.styles[id].slot)
			if action == "equip":
				if slot == "harbor" and (clans.clan().is_empty() or clans.role() != "leader"): return _fail("Оформление клановой гавани устанавливает глава.")
				personal().equipped[slot] = id
			else: personal().equipped.erase(slot)
			if slot == "harbor" and not clans.clan().is_empty() and clans.role() == "leader": clans.clan().base["style"] = id if action == "equip" else ""
			return _ok("Оформление установлено." if action == "equip" else "Возвращено обычное оформление.")
		"equip_bundle":
			var ids: Array = args.get("ids", [])
			if ids.is_empty(): return _fail("Комплект пуст.")
			for style_id in ids:
				var result: Dictionary = _command("equip", {"id": str(style_id)})
				if not result.ok: return result
			return _ok("Комплект установлен. Характеристики кораблей не изменены.")
	return _fail("Действие недоступно.")

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 5.0:
		_elapsed = 0.0
		sample()

func _ok(message: String) -> Dictionary: return {"ok": true, "message": message}
func _fail(message: String) -> Dictionary: return {"ok": false, "message": message}
