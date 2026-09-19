extends CanvasLayer

var _panel: PanelContainer
var _content: VBoxContainer
var _open: bool = false
var _system: Node
var _rewards: Node
var _notice: String = ""
var _timer: float = 0.0

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
		_refresh()

func _refresh() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_label("ЧЕЛЛЕНДЖИ И НАГРАДЫ", 26)
	_label(_notice)
	for challenge in _system.get_board():
		_label(str(challenge.name), 23)
		var status: String = str(challenge.status)
		var status_names: Dictionary = {"available": "Не начато", "active": "Выполняется", "complete": "Выполнено", "claimed": "Награда получена", "expired": "Срок истёк"}
		var hours: int = int(challenge.duration_seconds) / 3600
		_label("%s • Срок: %d ч.\nНаграда: %s" % [str(status_names.get(status, status)), hours, str(challenge.reward_text)])
		for goal in challenge.goals:
			_label("%s: %d / %d" % [str(goal.name), int(goal.progress), int(goal.target)])
		if status == "active":
			var seconds: int = maxi(0, int(challenge.expires_at) - int(Time.get_unix_time_from_system()))
			_label("Осталось: %d ч. %d мин." % [seconds / 3600, (seconds % 3600) / 60])
		elif status == "complete":
			_button("Забрать награду", _claim.bind(str(challenge.tier_id)))
		else:
			var cooldown: int = int(challenge.get("renewal_remaining", 0))
			if cooldown > 0:
				_label("Следующее задание через %d мин." % int(ceil(cooldown / 60.0)))
			_button("Принять задание" if status == "available" else "Начать новое задание", _accept.bind(str(challenge.tier_id)), cooldown > 0)
	var state: Dictionary = _rewards.get_state()
	var catalog: Dictionary = _rewards.get_catalog()
	_label("МОИ НАГРАДЫ", 24)
	_label("Дни премиума в запасе: %d. Активный премиум: +%.0f%% к выручке от продажи." % [int(state.get("premium_days", 0)), float(catalog.premium.sale_bonus_percent)])
	if int(state.get("premium_until", 0)) > int(Time.get_unix_time_from_system()):
		_label("Премиум действует до: " + Time.get_datetime_string_from_unix_time(int(state.premium_until)).replace("T", " ") + " UTC")
	_button("Активировать 1 день премиума", _premium, int(state.get("premium_days", 0)) < 1)
	for id in catalog.get("boosts", {}):
		var boost: Dictionary = catalog.boosts[id]
		var quantity: int = int(state.get("boosts", {}).get(id, 0))
		_label("%s: %d шт. • %s" % [str(boost.name), quantity, str(boost.description)])
		_button("Активировать буст", _boost.bind(str(id)), quantity == 0)
	var active: Dictionary = state.get("active_boost", {})
	if float(active.get("seconds_remaining", 0)) > 0:
		_label("Буст действует ещё %d мин. игрового времени." % int(ceil(float(active.seconds_remaining) / 60.0)))
	_label("КОЛЛЕКЦИЯ АРТЕФАКТОВ", 24)
	_label("Одновременно действует один установленный артефакт.")
	for id in catalog.get("artifacts", {}):
		var artifact: Dictionary = catalog.artifacts[id]
		var parts: int = int(state.get("fragments", {}).get(id, 0))
		_label("%s • %s\nЧасти: %d / %d" % [str(artifact.name), str(artifact.description), parts, int(artifact.fragments_required)])
		_button("Собрать артефакт", _craft.bind(str(id)), parts < int(artifact.fragments_required))
	for item in state.get("artifacts", []):
		var equipped: bool = str(state.get("equipped_artifact", "")) == str(item.instance_id)
		_button(("Снять: " if equipped else "Установить: ") + str(catalog.artifacts[item.definition_id].name) + " • " + str(item.instance_id), _equip.bind("" if equipped else str(item.instance_id)))

func _label(value: String, font_size: int = 20) -> void:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	_content.add_child(label)

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
