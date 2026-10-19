extends CanvasLayer

var _panel: PanelContainer
var _open: bool = false
var _clans: Node
var _shop: Node
var _body: VBoxContainer
var _notice: Label
var _page: String = "clan"
var _clan_tab: String = "Обзор"
var _selected_clan: String = ""
var _selected_player: String = ""
var _search: String = ""
var _dialog: FileDialog
var _confirmation: CanvasLayer
var _shop_category: String = "all"
var _shop_product: String = ""
var _progression: Node
var _fitting: CanvasLayer

func _ready() -> void:
	set_meta("owns_workspace_scroll", true)
	layer = 60
	_panel = PanelContainer.new()
	_panel.name = "SocialWorkspace"
	_panel.theme = preload("res://systems/ui/game_ui_theme.gd").new().get_theme()
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var tabs := HFlowContainer.new()
	root.add_child(tabs)
	for entry in [["clan", "Мой клан"], ["clans", "Кланы"], ["shop", "Магазин"], ["season", "Экспедиция сезона"], ["collection", "Коллекция"], ["chat", "Друзья и чат"]]:
		_button(tabs, entry[1], show_page.bind(entry[0]))
	_notice = _label(root, "Локальный режим. Каталог игроков и кланов хранится в этом сохранении; общий сервер ещё не подключён.")
	_notice.name = "SocialNotice"
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body)
	_panel.hide()
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Изображения 200×200"])
	_dialog.use_native_dialog = true
	_dialog.file_selected.connect(_logo_selected)
	add_child(_dialog)

func initialize(clans: Node, shop: Node) -> void:
	_clans = clans
	_shop = shop
	_clans.changed.connect(_refresh)
	_shop.changed.connect(_refresh)
	_progression = get_tree().get_first_node_in_group("company_progression")
	if _progression != null: _progression.changed.connect(_refresh)

func show_page(page: String = "clan") -> void:
	_page = page
	_selected_clan = ""
	_open = true
	_clans.ensure_state()
	_refresh()

func _process(_delta: float) -> void:
	_panel.visible = _open
	if _open:
		preload("res://systems/ui/workspace_layout.gd").fill_screen(_panel, get_viewport().get_visible_rect().size, preload("res://systems/ui/workspace_layout.gd").safe_top(get_tree()))

func _refresh() -> void:
	if not _open or _body == null or _clans == null: return
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	match _page:
		"clan": _clan_page()
		"clans": _directory_page()
		"shop": _shop_page()
		"chat": _chat_page()
		"season", "collection": _activity_page(_page)

func _scroll(parent: Node = null) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(parent if parent != null else _body).add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func _label(parent: Node, text: String, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16 if heading else 12)
	label.set_meta("ui_base_font_size", 16 if heading else 12)
	label.set_meta("compact_description", true)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 12)
	button.set_meta("fixed_font_size", 12)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _act(action: String, args: Dictionary = {}) -> void:
	var result: Dictionary = _clans.perform(action, args)
	_notice.text = str(result.get("message", ""))
	_refresh()

func _confirm(text: String, callback: Callable) -> void:
	if is_instance_valid(_confirmation): return
	var dialog := preload("res://systems/ui/social_confirmation.gd").new()
	_confirmation = dialog
	add_child(dialog)
	dialog.set_message(text)
	dialog.confirmed.connect(callback)

func _clan_page() -> void:
	var entry: Dictionary = _clans.clan(_selected_clan)
	if entry.is_empty():
		_create_page()
		return
	var own: bool = str(entry.id) == str(_clans.profile().get("clan_id", ""))
	var tabs := HFlowContainer.new()
	_body.add_child(tabs)
	for title in (["Обзор", "Экспедиции", "Гавань", "Участники", "Бусты", "Чат клана", "Управление"] if own else ["Обзор", "Участники"]):
		_button(tabs, str(title), func() -> void: _clan_tab = str(title); _refresh())
	match _clan_tab:
		"Участники": _members(entry, own)
		"Бусты": _boosts(entry)
		"Чат клана": _clan_chat(entry)
		"Управление": _management(entry)
		"Экспедиции": _activity_page("expeditions")
		"Гавань": _activity_page("harbor")
		_:
			var box: VBoxContainer = _scroll()
			var header := HBoxContainer.new()
			box.add_child(header)
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(160, 160)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = _logo(entry)
			header.add_child(icon)
			var details := VBoxContainer.new()
			details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header.add_child(details)
			_label(details, str(entry.name), true)
			var ports: Node = get_tree().get_first_node_in_group("port_system")
			var base_name: String = str(ports.get_port_name(str(entry.base.get("port_id", "")))) if ports != null else "Клановая гавань"
			_label(details, "%s · участников %d/%d\nГлава: %s\nБаза клана: %s · декоративных крыльев %d/4" % [str(GameData.get_faction(str(entry.race_id)).get("name", "")), entry.members.size(), int(_clans.rules.maximum_members), str(_clans.profile(str(entry.leader_id)).get("name", "Капитан")), base_name, int(entry.base.get("wings", 0))])
			_label(box, "Правила клана", true)
			_label(box, str(entry.get("rules", "")) if str(entry.get("rules", "")) != "" else "Глава ещё не добавил правила.")
			if not own:
				_button(box, "Подать заявку", _act.bind("apply", {"clan_id": str(entry.id)}), not _clans.clan().is_empty())
				if _clans.role() == "leader":
					var own_entry: Dictionary = _clans.clan()
					_button(box, "Предложить мир", _act.bind("peace_offer", {"clan_id": str(entry.id)}))
					if own_entry.peace_requests.has(str(entry.id)): _button(box, "Принять мир", _act.bind("peace_accept", {"clan_id": str(entry.id)}))
					if preload("res://systems/social/clan_bonuses.gd").peace(str(own_entry.id), str(entry.id)):
						_button(box, "Расторгнуть мир", func() -> void: _confirm("Расторгнуть мир? Бои и дань больше не приостанавливаются.", _act.bind("peace_break", {"clan_id": str(entry.id)})))
			else:
				_label(box, "Один участник — один клан. Роли разделяют полномочия, а бусты дают небольшую общую поддержку на 24 часа. Личные корабли, ресурсы и экипаж остаются собственностью игрока.")
				_label(box, "Поддержка клана", true)
				for stat in _clans.rules.boosts:
					var spec: Dictionary = _clans.rules.boosts[stat]
					var active: bool = int(entry.active_boosts.get(stat, 0)) > _clans.now()
					_label(box, "%s · %.2f%% · %s" % [str(spec.name), minf(float(spec.cap_percent), float(spec.base_percent) + float(entry.boost_progress.get(stat, 0))), "действует" if active else "готов к активации"])

func _create_page() -> void:
	var box: VBoxContainer = _scroll()
	_label(box, "Клан — союз капитанов одной расы", true)
	_label(box, "Общие правила, помощь экипажам, чат, дипломатия и клановая гавань. До 30 участников. Бусты ограничены по силе; членство не заменяет развитие собственного флота.")
	_label(box, "Право основания: %.0f монет. Включает базовую клановую гавань. Казна: %.0f." % [float(_clans.rules.creation_price), float(GameState.player_state.get("money", 0))])
	var name_edit := LineEdit.new()
	name_edit.name = "ClanName"
	name_edit.placeholder_text = "Название клана · 3–32 символа"
	name_edit.max_length = 32
	name_edit.custom_minimum_size.x = 300
	box.add_child(name_edit)
	var rules_edit := TextEdit.new()
	rules_edit.name = "ClanRules"
	rules_edit.placeholder_text = "Правила клана · до 500 символов"
	rules_edit.custom_minimum_size.y = 110
	rules_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(rules_edit)
	_button(box, "Создать клан", func() -> void:
		var name_text: String = name_edit.text
		var rules_text: String = rules_edit.text
		_confirm("Создать клан «%s» за %.0f монет?" % [name_text, float(_clans.rules.creation_price)], _act.bind("create", {"name": name_text, "rules": rules_text})))
	_label(box, "Логотип PNG/JPG 200×200 можно загрузить после создания. Название и правила проходят словарный фильтр; для онлайна потребуется серверная модерация.")

func _directory_page() -> void:
	var box: VBoxContainer = _scroll()
	_label(box, "Кланы · рейтинг капитанов", true)
	_label(box, "Очки: сумма рангов капитанов ×100. Сверху наиболее развитые кланы. Пока показан каталог этого сохранения.")
	var entries: Array = _clans.directory()
	if entries.is_empty(): _label(box, "Кланов пока нет. Можно основать первый во вкладке «Мой клан».")
	for entry in entries:
		var row := HBoxContainer.new()
		box.add_child(row)
		var icon := TextureRect.new()
		icon.texture = _logo(entry)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(56, 56)
		row.add_child(icon)
		_label(row, "%s\n%s · %d очков · %d участников" % [str(entry.name), str(GameData.get_faction(str(entry.race_id)).get("name", "")), int(entry.points), entry.members.size()])
		_button(row, "Открыть", func() -> void: _selected_clan = str(entry.id); _clan_tab = "Обзор"; _page = "clan"; _refresh())

func _members(entry: Dictionary, own: bool) -> void:
	var box: VBoxContainer = _scroll()
	_label(box, "Участники · ранг капитана · должность", true)
	if own and _clans.role() == "leader" and _clans.local_test_count() > 0:
		_button(box, "Добавить тестовый состав · 5 капитанов", _act.bind("test_members"))
	for id in entry.members:
		var row := HBoxContainer.new()
		box.add_child(row)
		var person: Dictionary = _clans.profile(str(id))
		var member: Dictionary = entry.members[id]
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(52, 60)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = preload("res://systems/characters/character_art_catalog.gd").ship_officer_portrait(str(person.get("race_id", "humans")), "captain", int(person.get("portrait_id", 0)), load("res://assets/characters/crew/crew_portrait_atlas.png"))
		row.add_child(portrait)
		_label(row, "%s  ·  ранг %d  ·  %s" % [str(person.get("name", "Капитан")), int(person.get("rank", 1)), str(_clans.rules.roles.get(str(member.role), "Участник"))])
		if bool(person.get("is_test_profile", false)): _label(row, "Локальный псевдоигрок")
		if not own or str(id) == _clans.local_id(): continue
		if _clans.role() == "leader":
			var roles := OptionButton.new()
			for key in ["member", "recruiter", "assistant"]:
				roles.add_item(str(_clans.rules.roles[key])); roles.set_item_metadata(roles.item_count - 1, key)
				if str(member.role) == key: roles.select(roles.item_count - 1)
			roles.item_selected.connect(func(index: int) -> void: _act("role", {"player_id": str(id), "role": str(roles.get_item_metadata(index))}))
			row.add_child(roles)
			_button(row, "Передать главу", func() -> void: _confirm("Передать руководство этому участнику?", _act.bind("transfer", {"player_id": str(id)})))
		if _clans.role() in ["leader", "assistant"]:
			_button(row, "Исключить", func() -> void: _confirm("Исключить участника из клана?", _act.bind("kick", {"player_id": str(id)})))
		if _clans.role() == "leader": _button(row, "В ЧС", func() -> void: _confirm("Исключить и заблокировать обращения этого игрока к клану?", _act.bind("blacklist", {"player_id": str(id)})))

func _boosts(entry: Dictionary) -> void:
	var box: VBoxContainer = _scroll()
	_label(box, "Клановые бусты · до двух одновременно", true)
	_label(box, "Каждый действует 24 реальных часа для всех участников. Раз в неделю активный участник добавляет 0,02–0,05 процентного пункта в одно случайное направление. Есть предел силы; смена клана не даёт повторного вклада за неделю.")
	var grid := preload("res://systems/ui/boost_tile_grid.gd").new()
	grid.name = "ClanBoostTiles"
	box.add_child(grid)
	for stat in _clans.rules.boosts:
		var spec: Dictionary = _clans.rules.boosts[stat]
		var percent: float = minf(float(spec.cap_percent), float(spec.base_percent) + float(entry.boost_progress.get(stat, 0)))
		percent *= -1.0 if str(stat) in ["fuel", "repair"] else 1.0
		var tile := preload("res://systems/ui/boost_tile.gd").new()
		tile.set_meta("boost_id", str(stat))
		grid.add_child(tile)
		tile.configure(str(spec.name), "%+.2f%%" % percent, "%s. Предел %.0f%%." % [str(spec.description), float(spec.cap_percent)], str(stat), _act.bind("boost", {"stat": str(stat)}), func() -> Dictionary:
			var remaining: int = maxi(0, int(entry.active_boosts.get(stat, 0)) - _clans.now())
			return {"status": "%02d:%02d:%02d" % [floori(remaining / 3600.0), floori(remaining % 3600 / 60.0), remaining % 60] if remaining > 0 else "24 часа · весь клан", "action": "Действует" if remaining > 0 else "Активировать", "disabled": remaining > 0 or _clans.role() != "leader", "tooltip": "Активирует глава клана; одновременно до двух направлений."})

func _management(entry: Dictionary) -> void:
	var box: VBoxContainer = _scroll()
	_label(box, "Заявки и управление", true)
	_label(box, "Глава: правила, логотип, должности, бусты, дипломатия. Помощник: приём и исключение рядовых. Рекрутер: рассмотрение заявок. Участник: чат и использование общих бустов.")
	if _clans.role() in ["leader", "assistant", "recruiter"]:
		for id in entry.applications:
			var row := HBoxContainer.new(); box.add_child(row)
			_label(row, str(_clans.profile(str(id)).get("name", "Капитан")))
			_button(row, "Принять", _act.bind("review", {"player_id": str(id), "accept": true}))
			_button(row, "Отклонить", _act.bind("review", {"player_id": str(id), "accept": false}))
		if entry.applications.is_empty(): _label(box, "Новых заявок нет.")
	if _clans.role() == "leader":
		_button(box, "Загрузить логотип · 200×200", func() -> void: _dialog.popup_centered_ratio(0.7))
		var edit := TextEdit.new(); edit.text = str(entry.rules); edit.custom_minimum_size.y = 100; edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; box.add_child(edit)
		_button(box, "Сохранить правила", func() -> void: _act("rules", {"text": edit.text}))
		for id in entry.blacklist:
			_button(box, "Снять блокировку: " + str(_clans.profile(str(id)).get("name", id)), _act.bind("unblacklist", {"player_id": str(id)}))
		_label(box, "Журнал действий", true)
		var journal: Array = entry.get("journal", [])
		for event in journal.slice(maxi(0, journal.size() - 10)):
			var titles: Dictionary = {"create": "Основан клан", "rules": "Изменены правила", "logo": "Обновлён логотип", "review": "Рассмотрена заявка", "role": "Назначена должность", "kick": "Исключён участник", "blacklist": "Блокировка игрока", "unblacklist": "Снята блокировка", "boost": "Активирован буст", "peace_offer": "Предложен мир", "peace_accept": "Заключён мир", "peace_break": "Расторгнут мир", "transfer": "Передано руководство"}
			_label(box, "%s · %s" % [str(_clans.profile(str(event.actor)).get("name", "Капитан")), str(titles.get(str(event.action), "Изменение профиля"))])
		_label(box, "Для расформирования введите название клана. Цена основания не возвращается; личные здания и ресурсы сохраняются.")
		var confirm_name := LineEdit.new(); confirm_name.placeholder_text = "Название клана"; box.add_child(confirm_name)
		_button(box, "Расформировать клан", func() -> void: _confirm("Расформировать клан?", _act.bind("dissolve", {"confirm_name": confirm_name.text})))
	else:
		_button(box, "Выйти из клана", func() -> void: _confirm("Выйти? Новое вступление будет доступно через 24 часа.", _act.bind("leave")))

func _clan_chat(entry: Dictionary) -> void:
	var history: VBoxContainer = _scroll()
	_label(history, "Чат клана · локальная история", true)
	for message in _clans.clan_messages():
		_label(history, "%s: %s" % [str(_clans.profile(str(message.sender)).get("name", "Капитан")), str(message.text)])
	_message_input(_body, func(text: String) -> void: _act("clan_message", {"text": text}))

func _message_input(parent: Node, callback: Callable) -> void:
	var row := HBoxContainer.new(); parent.add_child(row)
	var edit := LineEdit.new(); edit.max_length = 400; edit.placeholder_text = "Сообщение · до 400 символов"; edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(edit)
	_button(row, "Отправить", func() -> void: callback.call(edit.text))
	edit.text_submitted.connect(callback)

func _shop_page() -> void:
	var shop_view := preload("res://systems/ui/company_shop_view.gd").new()
	_body.add_child(shop_view)
	shop_view.purchase_requested.connect(_buy)
	shop_view.preview_requested.connect(_open_fitting)
	shop_view.outfit_requested.connect(func(id: String) -> void:
		var result: Dictionary = _shop.apply_product(id)
		_notice.text = str(result.get("message", "")); _refresh())
	shop_view.selection_changed.connect(func(category: String, id: String) -> void: _shop_category = category; _shop_product = id)
	shop_view.configure(_shop, _shop_category, _shop_product)

func _activity_page(mode: String) -> void:
	if _progression == null:
		_label(_body, "Система развития пока недоступна.")
		return
	var view := preload("res://systems/ui/company_activity_view.gd").new()
	view.name = "CompanyActivity_" + mode
	_body.add_child(view)
	view.configure(_progression, mode)
	view.preview_requested.connect(_open_fitting)
	view.action_requested.connect(func(action: String, args: Dictionary) -> void:
		var callback: Callable = func() -> void:
			var result: Dictionary = _progression.perform(action, args)
			_notice.text = str(result.get("message", "")); _refresh()
		if action == "harbor":
			for spec in _progression.harbor():
				if str(spec.id) == str(args.id): _confirm("%s: уровень %d → %d. Цена: %d знаков экспедиции. Остаток: %d. Улучшение декоративное." % [str(spec.name), int(spec.level), int(spec.level) + 1, int(spec.price), int(spec.resource) - int(spec.price)], callback)
		else: callback.call())

func _open_fitting(product: Dictionary) -> void:
	if _progression == null or is_instance_valid(_fitting): return
	_fitting = preload("res://systems/ui/company_fitting_room.gd").new()
	add_child(_fitting)
	_fitting.configure(product, _progression)
	_fitting.purchase_requested.connect(_buy)
	_fitting.outfit_requested.connect(func(ids: Array) -> void:
		var result: Dictionary = _progression.perform("equip_bundle", {"ids": ids})
		_notice.text = str(result.get("message", "")); _refresh())

func _buy(id: String) -> void:
	var quote: Dictionary = _shop.quote(id)
	_confirm("%s\nЦена: %.0f монет. Казна: %.0f → %.0f.\n%s" % [str(quote.get("name", "Товар")), float(quote.get("price", 0)), float(quote.get("balance", 0)), float(quote.get("balance", 0)) - float(quote.get("price", 0)), str(quote.get("description", ""))], func() -> void:
		var result: Dictionary = _shop.purchase(id)
		_notice.text = str(result.get("message", ""))
		_refresh())

func _chat_page() -> void:
	var search_row := HBoxContainer.new(); _body.add_child(search_row)
	var search_edit := LineEdit.new(); search_edit.text = _search; search_edit.placeholder_text = "Поиск известных игроков"; search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; search_row.add_child(search_edit)
	_button(search_row, "Найти", func() -> void: _search = search_edit.text; _refresh())
	var split := HBoxContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; _body.add_child(split)
	var left := VBoxContainer.new(); left.custom_minimum_size.x = 250; split.add_child(left)
	var list: VBoxContainer = _scroll(left)
	var players: Array = _clans.search_players(_search)
	if players.is_empty(): _label(list, "Другие игроки пока не подключены. Общий поиск и доставка сообщений появятся с сервером.")
	for person in players:
		_button(list, str(person.name) + " · " + str(person.rank), func() -> void: _selected_player = str(person.id); _refresh())
	var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(right)
	if _selected_player == "":
		_label(right, "Выберите игрока для просмотра профиля и переписки.")
		var nickname := LineEdit.new(); nickname.placeholder_text = "Ваше имя для списка капитанов"; nickname.max_length = 24; right.add_child(nickname)
		_button(right, "Сохранить имя", func() -> void: _act("nickname", {"name": nickname.text}))
		return
	var person: Dictionary = _clans.profile(_selected_player)
	_label(right, "%s · ранг %d" % [str(person.get("name", "")), int(person.get("rank", 1))], true)
	var actions := HFlowContainer.new(); right.add_child(actions)
	_button(actions, "В друзья", _act.bind("friend_request", {"player_id": _selected_player}))
	_button(actions, "Принять запрос", _act.bind("friend_accept", {"player_id": _selected_player}), not _clans.state().friend_requests.has(_selected_player + ":" + _clans.local_id()))
	_button(actions, "Убрать из друзей", _act.bind("unfriend", {"player_id": _selected_player}))
	var blocked: bool = bool(_clans.state().blocks.get(_clans.local_id(), {}).get(_selected_player, false))
	_button(actions, "Разблокировать" if blocked else "Заблокировать", _act.bind("block", {"player_id": _selected_player, "blocked": not blocked}))
	var history: VBoxContainer = _scroll(right)
	for message in _clans.private_messages(_selected_player): _label(history, "%s: %s" % [str(_clans.profile(str(message.sender)).get("name", "Капитан")), str(message.text)])
	_message_input(right, func(text: String) -> void: _act("message", {"player_id": _selected_player, "text": text}))

func _logo(entry: Dictionary) -> Texture2D:
	var image := Image.new()
	var encoded: String = str(entry.get("logo_png", ""))
	if encoded != "" and image.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) == OK:
		return ImageTexture.create_from_image(image)
	return GameData.get_faction_emblem(str(entry.get("race_id", "humans")))

func _logo_selected(path: String) -> void:
	var result: Dictionary = SaveSystem.import_clan_logo(path)
	if not bool(result.get("ok", false)): _notice.text = str(result.get("message", "")); return
	_act("logo", {"png": str(result.png)})
