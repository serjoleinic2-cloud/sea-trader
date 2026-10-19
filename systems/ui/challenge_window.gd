extends CanvasLayer

var _panel: PanelContainer
var _content: VBoxContainer
var _open: bool = false
var _system: Node
var _rewards: Node
var _notice: String = ""
var _timer: float = 0.0
var _signature: String = ""
var _countdowns: Array[Dictionary] = []

func _ready() -> void:
	layer = 60
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_panel.add_child(_content)
	_panel.hide()

func initialize(challenges: Node, rewards: Node) -> void:
	_system = challenges
	_rewards = rewards

func open() -> void:
	_open = true
	_refresh()

func _process(delta: float) -> void:
	_panel.visible = _open
	if not _open:
		return
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		_update_countdowns()
		_refresh(false)

func _refresh(force: bool = true) -> void:
	var board: Array = _system.get_board()
	var state: Dictionary = _rewards.get_state()
	var stable_board: Array = board.duplicate(true)
	for item in stable_board:
		item["renewal_locked"] = int(item.get("renewal_remaining", 0)) > 0
		item.erase("renewal_remaining")
	var stable_state: Dictionary = state.duplicate(true)
	if stable_state.has("active_boost"):
		stable_state.active_boost["seconds_remaining"] = 1 if float(stable_state.active_boost.get("seconds_remaining", 0)) > 0 else 0
	var signature: String = str([stable_board, stable_state, _notice])
	if not force and signature == _signature: return
	_signature = signature
	_countdowns.clear()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_label("ЧЕЛЛЕНДЖИ И НАГРАДЫ", 26)
	_label(_notice)
	for challenge in board:
		_label(str(challenge.name), 23)
		var status: String = str(challenge.status)
		var status_names: Dictionary = {"available": "Не начато", "active": "Выполняется", "complete": "Выполнено", "claimed": "Награда получена", "expired": "Срок истёк"}
		var hours: int = int(challenge.duration_seconds) / 3600
		_label("%s • Срок: %d ч.\nНаграда: %s" % [str(status_names.get(status, status)), hours, str(challenge.reward_text)])
		for goal in challenge.goals:
			_label("%s: %d / %d" % [str(goal.name), int(goal.progress), int(goal.target)])
		if status == "active":
			var seconds: int = maxi(0, int(challenge.expires_at) - int(Time.get_unix_time_from_system()))
			var timer: Label = _label("Осталось: %d ч. %d мин." % [seconds / 3600, (seconds % 3600) / 60])
			_countdowns.append({"label": timer, "expires_at": int(challenge.expires_at), "kind": "active"})
		elif status == "complete":
			_button("Забрать награду", _claim.bind(str(challenge.tier_id)))
		else:
			var cooldown: int = int(challenge.get("renewal_remaining", 0))
			if cooldown > 0:
				var timer: Label = _label("Следующее задание через %d мин." % int(ceil(cooldown / 60.0)))
				_countdowns.append({"label": timer, "expires_at": int(Time.get_unix_time_from_system()) + cooldown, "kind": "renewal"})
			_button("Принять задание" if status == "available" else "Начать новое задание", _accept.bind(str(challenge.tier_id)), cooldown > 0)
	var catalog: Dictionary = _rewards.get_catalog()
	_label("МОИ НАГРАДЫ", 24)
	_label("Дни премиума в запасе: %d. Активный премиум: +%.0f%% к выручке от продажи." % [int(state.get("premium_days", 0)), float(catalog.premium.sale_bonus_percent)])
	if int(state.get("premium_until", 0)) > int(Time.get_unix_time_from_system()):
		_label("Премиум действует до: " + Time.get_datetime_string_from_unix_time(int(state.premium_until)).replace("T", " ") + " UTC")
	_button("Активировать 1 день премиума", _premium, int(state.get("premium_days", 0)) < 1)
	var grid := preload("res://systems/ui/boost_tile_grid.gd").new()
	grid.name = "RewardBoostTiles"
	_content.add_child(grid)
	for id in catalog.get("boosts", {}):
		var boost: Dictionary = catalog.boosts[id]
		var tile := preload("res://systems/ui/boost_tile.gd").new()
		grid.add_child(tile)
		var percent: float = float(boost.percent) * (-1.0 if str(boost.stat) in ["fuel", "reload"] else 1.0)
		tile.configure(str(boost.name), "%+.0f%%" % percent, str(boost.description), str(boost.stat), _boost.bind(str(id)), _boost_state.bind(str(id)))
	_label("ЗНАКИ ЭКСПЕДИЦИЙ", 24)
	for id in catalog.get("expedition_tokens", {}):
		var token: Dictionary = catalog.expedition_tokens[id]
		_label("%s: %d шт.\n%s" % [str(token.name), int(state.get("expedition_tokens", {}).get(id, 0)), str(token.description)])
	_label("ИГРОВЫЕ РЕЛИКВИИ", 24)
	_label("Эти локальные реликвии привязаны к сохранению и не передаются. Официальные редкие артефакты появятся только после подключения аккаунтов и сервера.")
	for id in catalog.get("artifacts", {}):
		var artifact: Dictionary = catalog.artifacts[id]
		var parts: int = int(state.get("fragments", {}).get(id, 0))
		_label("%s • %s\nЧасти: %d / %d" % [str(artifact.name), str(artifact.description), parts, int(artifact.fragments_required)])
		_button("Собрать артефакт", _craft.bind(str(id)), parts < int(artifact.fragments_required))
	for item in state.get("artifacts", []):
		var equipped: bool = str(state.get("equipped_artifact", "")) == str(item.instance_id)
		_button(("Снять: " if equipped else "Установить: ") + str(catalog.artifacts[item.definition_id].name) + " • " + str(item.instance_id), _equip.bind("" if equipped else str(item.instance_id)))

func _label(value: String, font_size: int = 20) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	_content.add_child(label)
	return label

func _update_countdowns() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	for item in _countdowns:
		var label: Label = item.label
		if not is_instance_valid(label): continue
		var left: int = maxi(0, int(item.expires_at) - now)
		label.text = "Следующее задание через %d мин." % ceili(left / 60.0) if str(item.kind) == "renewal" else "Осталось: %d ч. %d мин." % [floori(left / 3600.0), floori(left % 3600 / 60.0)]

func _boost_state(id: String) -> Dictionary:
	var spec: Dictionary = _rewards.get_catalog().boosts[id]
	var count: int = int(_rewards.get_state().get("boosts", {}).get(id, 0))
	var slots: Array = preload("res://systems/fleet/ship_loadout.gd").boost_slots(GameState.ship_state)
	var remaining: float = 0.0
	for active in slots:
		if str(active.get("id", "")) == id: remaining = maxf(remaining, float(active.get("seconds_remaining", 0)))
	var reason: String = ""
	if count <= 0: reason = "Нет свитков в запасе."
	elif float(slots[0].get("seconds_remaining", 0)) > 0: reason = "Первая ячейка корабля занята."
	elif str(spec.stat) in ["damage", "reload", "accuracy"] and not bool(preload("res://systems/fleet/ship_loadout.gd").definition(GameState.ship_state).get("warship", false)): reason = "Только для артиллерийского корабля."
	return {"status": "%d мин · в запасе %d" % [ceili(remaining / 60.0), count] if remaining > 0 else "%d мин · в запасе %d" % [int(float(spec.duration_seconds) / 60.0), count], "action": "Действует" if remaining > 0 else "Активировать", "disabled": remaining > 0 or reason != "", "tooltip": reason}

func _button(value: String, callback: Callable, disabled: bool = false) -> void:
	var button: Button = Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 20)
	button.disabled = disabled
	button.pressed.connect(callback)
	_content.add_child(button)

func _accept(id: String) -> void:
	_result(_system.accept(id))
func _claim(id: String) -> void:
	_result(_system.claim(id))
func _premium() -> void:
	_result(_rewards.activate_premium())
func _boost(id: String) -> void:
	_result(_rewards.activate_boost(id))
func _craft(id: String) -> void:
	_result(_rewards.craft_artifact(id))
func _equip(id: String) -> void:
	_result(_rewards.equip_artifact(id))
func _result(result: Dictionary) -> void:
	_notice = str(result.get("message", ""))
	_refresh()
