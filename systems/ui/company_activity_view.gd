extends VBoxContainer

signal action_requested(action: String, args: Dictionary)
signal preview_requested(product: Dictionary)
var _service: Node
var _mode: String
var _summary: Label
var _grid: GridContainer
var _rows: Dictionary = {}
var _clock: float = 0
var _board_signature: String = ""

func configure(service: Node, mode: String) -> void:
	_service = service
	_mode = mode
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary = _label(self, "", 13)
	if mode == "expeditions":
		var has_testers: bool = false
		for member in service.clans.clan().get("members", {}): has_testers = has_testers or bool(service.clans.profile(str(member)).get("is_test_profile", false))
		if has_testers:
			_button(self, "Локальный тест · симулировать рейсы пяти капитанов", func() -> void: action_requested.emit("simulate_test_voyages", {}))
	var scroll := ScrollContainer.new()
	scroll.name = "ActivityCatalogScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_grid = preload("res://systems/ui/boost_tile_grid.gd").new()
	_grid.tile_width = 310; _grid.maximum_columns = 4
	scroll.add_child(_grid)
	_build()
	_update()

func _build() -> void:
	for child in _grid.get_children(): _grid.remove_child(child); child.queue_free()
	_rows.clear()
	match _mode:
		"expeditions":
			var board: Array = _service.expeditions()
			_board_signature = str(board.map(func(row): return "%s:%d" % [str(row.id), int(row.week)]))
			for row in board:
				var id: String = "%s:%d" % [str(row.id), int(row.week)]
				var card: VBoxContainer = _card(str(row.name) + (" · прошлая неделя" if int(row.week) != _service.week() else ""), str(row.art))
				_label(card, str(row.description), 12)
				var progress := ProgressBar.new(); progress.max_value = float(row.target); progress.show_percentage = true
				progress.custom_minimum_size.y = 14; card.add_child(progress)
				var status: Label = _label(card, "", 12)
				_label(card, "Клану: %d знаков · участнику: %d монет" % [int(row.clan_resource), int(row.personal_coins)], 12)
				var claim: Button = _button(card, "Забрать награду", func() -> void: action_requested.emit("expedition", {"id": str(row.id), "week": int(row.week)}))
				_rows[id] = {"bar": progress, "status": status, "action": claim}
		"harbor":
			for row in _service.harbor():
				var card: VBoxContainer = _card(str(row.name), str(row.art))
				_label(card, str(row.description), 12)
				var status: Label = _label(card, "", 13)
				var claim: Button = _button(card, "", func() -> void: action_requested.emit("harbor", {"id": str(row.id)}))
				_rows[str(row.id)] = {"status": status, "action": claim}
		"season":
			var season: Dictionary = _service.season()
			for index in season.milestones.size():
				var row: Dictionary = season.milestones[index]
				var style: Dictionary = _service.rules.styles[str(row.premium.style)]
				var card: VBoxContainer = _card("Рубеж · %d очков" % int(row.points), _art(str(style.slot)))
				_label(card, "Бесплатно: " + _reward_text(row.free), 12)
				_label(card, "Коллекция: " + _reward_text(row.premium), 12)
				var free: Button = _button(card, "Получить бесплатно", func() -> void: action_requested.emit("season", {"index": index, "premium": false}))
				var premium: Button = _button(card, "Получить украшение", func() -> void: action_requested.emit("season", {"index": index, "premium": true}))
				_button(card, "Примерить", func() -> void: preview_requested.emit({"name": str(style.name), "styles": [str(row.premium.style)], "preview": "harbor" if str(style.slot) == "harbor" else "ship"}))
				_rows[str(index)] = {"free": free, "premium": premium, "points": int(row.points)}
		"collection":
			for row in _service.collection():
				var card: VBoxContainer = _card(str(row.name), _art(str(row.slot)))
				_label(card, "%s · %s" % [{"sail": "Паруса", "hull": "Корпус", "engine": "Двигатели", "harbor": "Гавань"}.get(str(row.slot), row.slot), "Навсегда в коллекции" if row.owned else ("Магазин" if str(row.source) == "shop" else "Сезонная награда")], 12)
				_button(card, "Примерить", func() -> void: preview_requested.emit({"name": str(row.name), "styles": [str(row.id)], "preview": "harbor" if str(row.slot) == "harbor" else "ship"}))
				var action: Button = _button(card, "", func() -> void: action_requested.emit("unequip" if str(_service.personal().equipped.get(str(row.slot), "")) == str(row.id) else "equip", {"id": str(row.id)}))
				_rows[str(row.id)] = {"action": action}

func _update() -> void:
	match _mode:
		"expeditions":
			var board: Array = _service.expeditions()
			var signature: String = str(board.map(func(row): return "%s:%d" % [str(row.id), int(row.week)]))
			if signature != _board_signature: _build()
			_summary.text = "Недельная экспедиция клана. Вклад суммируется. Награды завершённых заданий остаются доступными после смены недели. Сейчас учёт локальный; общий морской мир требует сервера."
			for row in board:
				var widgets: Dictionary = _rows["%s:%d" % [str(row.id), int(row.week)]]
				widgets.bar.value = float(row.progress)
				widgets.status.text = "%.0f / %.0f · ваш вклад %.0f · участников %d%s" % [float(row.progress), float(row.target), float(row.contributors.get(_service.clans.local_id(), 0)), row.contributors.size(), "\nЛичная награда требует вашего участия." if row.complete and not row.eligible else ""]
				widgets.action.text = "Получено" if row.claimed else "Забрать награду"
				widgets.action.disabled = row.claimed or not row.complete or not row.eligible
		"harbor":
			var entry: Dictionary = _service.clans.clan()
			_summary.text = "Развитие гавани · %d знаков экспедиции. Знаки зарабатываются заданиями; постройки меняют внешний вид и престиж базы. Предварительный уровень и стоимость показаны перед подтверждением." % int(entry.get("base", {}).get("expedition_resource", 0))
			for row in _service.harbor():
				var widgets: Dictionary = _rows[str(row.id)]
				widgets.status.text = "Уровень %d / %d" % [int(row.level), int(row.maximum)]
				widgets.action.text = "Максимальный уровень" if int(row.level) >= int(row.maximum) else "Уровень %d · %d знаков" % [int(row.level) + 1, int(row.price)]
				widgets.action.disabled = not row.can_manage or int(row.level) >= int(row.maximum) or int(row.resource) < int(row.price)
		"season":
			var state: Dictionary = _service.season()
			var days: int = maxi(0, ceili((int(state.expires_at) - _service.now()) / 86400.0))
			_summary.text = "%s · %d очков · осталось %d дн.\n%s\nДополнительные украшения: %s. Полученные предметы постоянные; доступные награды можно забрать после окончания." % [str(state.name), int(state.points), days, str(state.description), "открыты" if state.premium else "комплект в магазине за монеты"]
			for key in _rows:
				var widgets: Dictionary = _rows[key]
				for track in ["free", "premium"]:
					var claimed: bool = state.claims.has(str(key) + ":" + track)
					widgets[track].text = "Получено" if claimed else ("Получить бесплатно" if track == "free" else "Получить украшение")
					widgets[track].disabled = claimed or int(state.points) < int(widgets.points) or (track == "premium" and not state.premium)
		"collection":
			_summary.text = "Коллекция компании · оформление парусов, корпуса, двигателей и гавани. Сначала примерка, затем установка. Лица капитанов, гербы рас и боевые характеристики сохраняются."
			for row in _service.collection():
				var button: Button = _rows[str(row.id)].action
				button.text = "Снять оформление" if row.equipped else ("Установить" if row.owned else "Ещё не получено")
				button.disabled = not row.owned

func _reward_text(reward: Dictionary) -> String:
	if reward.has("style"): return str(_service.rules.styles[str(reward.style)].name)
	if reward.has("coins"): return "%d монет" % int(reward.coins)
	return "Свитки попутного ветра ×2"

func _art(slot: String) -> String:
	return str({"sail": "speed", "hull": "repair", "engine": "fuel", "harbor": "sale"}.get(slot, "crew_xp"))

func _card(title: String, art: String) -> VBoxContainer:
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(310, 214)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(panel)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var heading := HBoxContainer.new(); column.add_child(heading)
	var image := TextureRect.new(); image.custom_minimum_size = Vector2(72, 72)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = preload("res://systems/ui/boost_item_art.gd").texture(art)
	heading.add_child(image)
	_label(heading, title, 15)
	return column

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.set_meta("fixed_font_size", font_size); label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = text; button.set_meta("fixed_font_size", 12)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(callback); parent.add_child(button)
	return button

func _process(delta: float) -> void:
	_clock += delta
	if _clock >= 1.0 and _service != null:
		_clock = 0
		_update()
