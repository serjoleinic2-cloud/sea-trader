extends CanvasLayer

## Captain's cabinet: read-only record of player knowledge.

var _port_system: Node
var _panel: Panel
var _left_panel: PanelContainer
var _label: Label
var _race_emblem: Control
var _race_label: Label
var _captain_portrait: TextureRect
var _brass_frame: Panel
var _backdrop_haze: TextureRect
var _close_button: Button
var _rewards_button: Button
var _replay_reward_button: Button
var _rewards_overlay: PanelContainer
var _rewards_summary: Label
var _rewards_rows: VBoxContainer
var _show_rewards: bool = false
var _displayed_race_id: String = ""
var _open := false

func _ready() -> void:
	layer = 40
	_backdrop_haze = TextureRect.new()
	_backdrop_haze.name = "CaptainCabinetSeaHaze"
	_backdrop_haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop_haze.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var haze_gradient := Gradient.new()
	haze_gradient.offsets = PackedFloat32Array([0.0, 0.68, 1.0])
	haze_gradient.colors = PackedColorArray([
		Color(0.018, 0.055, 0.072, 0.50),
		Color(0.012, 0.040, 0.055, 0.84),
		Color(0.008, 0.026, 0.038, 0.97)
	])
	var haze_texture := GradientTexture2D.new()
	haze_texture.gradient = haze_gradient
	haze_texture.fill = GradientTexture2D.FILL_RADIAL
	haze_texture.fill_from = Vector2(0.5, 0.5)
	haze_texture.fill_to = Vector2(1.0, 0.5)
	_backdrop_haze.texture = haze_texture
	add_child(_backdrop_haze)
	_panel = Panel.new()
	var clear_panel := StyleBoxFlat.new()
	clear_panel.bg_color = Color(0, 0, 0, 0)
	_panel.add_theme_stylebox_override("panel", clear_panel)
	_panel.position = Vector2(16, 16)
	_panel.size = Vector2(1180, 740)
	_panel.clip_contents = true
	add_child(_panel)
	_captain_portrait = TextureRect.new()
	_captain_portrait.name = "FullWindowCaptainCabinArt"
	_captain_portrait.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_captain_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Size the entire image ourselves and crop only its bottom/left, never its top.
	_captain_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_captain_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_captain_portrait)
	_brass_frame = Panel.new()
	_brass_frame.name = "CaptainCabinetBrassFrame"
	_brass_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_brass_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brass_frame.add_theme_stylebox_override("panel", _brass_style(22.0, 18.0))
	_panel.add_child(_brass_frame)
	_left_panel = PanelContainer.new()
	_left_panel.name = "CaptainDataScrollPanel"
	_left_panel.set_meta("preserve_art_style", true)
	var left_style := _brass_style(18.0, 13.0)
	left_style.draw_center = true
	left_style.content_margin_left = 24
	left_style.content_margin_right = 24
	left_style.content_margin_top = 20
	left_style.content_margin_bottom = 20
	_left_panel.add_theme_stylebox_override("panel", left_style)
	_panel.add_child(_left_panel)
	_panel.resized.connect(_layout_cabin)
	var content_margin := MarginContainer.new()
	_left_panel.add_child(content_margin)
	var scroll := ScrollContainer.new()
	scroll.name = "CaptainDataScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(scroll)
	var information := VBoxContainer.new()
	information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information.add_theme_constant_override("separation", 8)
	scroll.add_child(information)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 12)
	information.add_child(identity)
	_race_emblem = preload("res://systems/ui/faction_pennant.gd").new()
	_race_emblem.name = "CaptainFactionPennant"
	identity.add_child(_race_emblem)
	var identity_text := VBoxContainer.new()
	identity_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_text.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_child(identity_text)
	var title := Label.new()
	title.text = "КАБИНЕТ КАПИТАНА"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color("#e6d1a7"))
	title.add_theme_font_size_override("font_size", 18)
	identity_text.add_child(title)
	_race_label = Label.new()
	_race_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_race_label.add_theme_color_override("font_color", Color("#64d4d2"))
	_race_label.add_theme_font_size_override("font_size", 14)
	identity_text.add_child(_race_label)
	_rewards_button = Button.new()
	_rewards_button.name = "CaptainRewardsButton"
	_rewards_button.text = "НАГРАДЫ"
	_rewards_button.custom_minimum_size = Vector2(120, 36)
	_rewards_button.tooltip_text = "Ранги, медали и полученные награды"
	_rewards_button.add_theme_font_size_override("font_size", 14)
	_rewards_button.add_theme_color_override("font_color", Color("f0d18d"))
	for state_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		_rewards_button.add_theme_stylebox_override(state_name, _brass_style(14.0, 10.0))
	_rewards_button.pressed.connect(func() -> void:
		_show_rewards = not _show_rewards
		_rewards_overlay.visible = _show_rewards
		if _show_rewards:
			_refresh_rewards()
	)
	identity_text.add_child(_rewards_button)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.add_theme_font_size_override("normal_font_size", 14)
	information.add_child(_label)
	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "×"
	preload("res://systems/ui/brass_close_button.gd").apply(_close_button)
	_close_button.tooltip_text = "Закрыть кабинет"
	_close_button.custom_minimum_size = Vector2(42, 38)
	_close_button.size = Vector2(42, 38)
	_close_button.add_theme_font_size_override("font_size", 22)
	_close_button.anchor_left = 1.0
	_close_button.anchor_right = 1.0
	_close_button.offset_left = -66.0
	_close_button.offset_right = -14.0
	_close_button.offset_top = 10.0
	_close_button.offset_bottom = 58.0
	_close_button.pressed.connect(func() -> void: _open = false)
	_panel.add_child(_close_button)
	_build_rewards_overlay()
	_panel.hide()

func initialize(port_system: Node) -> void:
	_port_system = port_system

func _process(_delta: float) -> void:
	if _label == null or _port_system == null:
		return
	_panel.visible = _open
	_backdrop_haze.visible = _open
	if _rewards_overlay != null:
		_rewards_overlay.visible = _open and _show_rewards
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var coordinator: Node = get_tree().root.find_child("WindowCoordinator", true, false)
	var safe_top: float = maxf(72.0, float(coordinator.get("_top_height"))) if coordinator != null else 72.0
	_update_race_identity()
	layout_for_viewport(viewport_size, safe_top)
	if not _open:
		return
	var stats: Dictionary = GameState.player_state.get("stats", {})
	var systems: Array[Node] = get_tree().get_nodes_in_group("career_system")
	var career: Dictionary = systems[0].get_command_progress() if not systems.is_empty() else {}
	var activity_score: int = int(career.get("activity", 0))
	var next_requirement: int = int(career.get("next_activity", 0))
	var lines: PackedStringArray = [""]
	lines.append("КАРЬЕРА")
	lines.append("%s, уровень %d / 10" % [str(career.get("stage_name", "Матрос")), int(career.get("stage_level", 1))])
	lines.append("Активность: %d%s" % [activity_score, "" if next_requirement == 0 else " / %d" % next_requirement])
	if next_requirement > 0:
		lines.append("До следующего повышения: %d очков" % maxi(0, next_requirement - activity_score))
	lines.append("Допуск к экипажу: до %d ранга" % int(systems[0].get_hiring_rank_limit() if not systems.is_empty() else 1))
	lines.append("")
	lines.append("ЧТО ПОВЫШАЕТ РАНГ")
	lines.append("Продано товаров: %d | Выполнено заказов: %d" % [int(stats.get("total_sales", 0)), int(stats.get("total_deliveries", 0))])
	lines.append("Доставлено на склад: %d ед." % int(stats.get("cargo_units_moved", 0)))
	lines.append("Путь: %.0f | Рейсы: %d" % [float(stats.get("total_distance", 0.0)), int(stats.get("total_voyages", 0))])
	lines.append("Швартовки: %d | Порты: %d" % [int(stats.get("safe_dockings", 0)), int(stats.get("ports_discovered", 0))])
	lines.append("")
	lines.append("Посещённые порты — в разделе «Карта». Изученные маршруты — в разделе «Рейсы».")
	_label.text = "\n".join(lines)


func layout_for_viewport(viewport_size: Vector2, safe_top: float) -> void:
	_panel.scale = Vector2.ONE
	_panel.size = Vector2(maxf(120.0, viewport_size.x - 32.0), maxf(120.0, viewport_size.y - safe_top - 16.0))
	_panel.position = Vector2(16.0, safe_top)
	_layout_cabin()

func _layout_cabin() -> void:
	if _left_panel == null:
		return
	if _captain_portrait.texture != null:
		var art_size: Vector2 = _captain_portrait.texture.get_size()
		var cover_scale: float = maxf(_panel.size.x / maxf(1.0, art_size.x), _panel.size.y / maxf(1.0, art_size.y))
		_captain_portrait.size = art_size * cover_scale
		_captain_portrait.position = Vector2(_panel.size.x - _captain_portrait.size.x, 0.0)
	_left_panel.position = Vector2(18.0, 28.0)
	_left_panel.size = Vector2(clampf(_panel.size.x * 0.39, 260.0, 420.0), maxf(1.0, _panel.size.y - 44.0))
	if _rewards_overlay != null:
		_rewards_overlay.position = Vector2(_panel.size.x * 0.16, _panel.size.y * 0.07)
		_rewards_overlay.size = Vector2(_panel.size.x * 0.68, _panel.size.y * 0.86)

func _build_rewards_overlay() -> void:
	_rewards_overlay = PanelContainer.new()
	_rewards_overlay.name = "CaptainRewardsOverlay"
	_rewards_overlay.set_meta("preserve_art_style", true)
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("0a1721")
	surface.border_color = Color("c89b4e")
	surface.set_border_width_all(2)
	surface.set_corner_radius_all(10)
	surface.content_margin_left = 18
	surface.content_margin_right = 18
	surface.content_margin_top = 15
	surface.content_margin_bottom = 14
	_rewards_overlay.add_theme_stylebox_override("panel", surface)
	_panel.add_child(_rewards_overlay)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_rewards_overlay.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = "НАГРАДЫ ЗА РАНГИ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("f0d18d"))
	heading.add_child(title)
	var close_rewards := Button.new()
	close_rewards.name = "CloseRewardsButton"
	preload("res://systems/ui/brass_close_button.gd").apply(close_rewards)
	close_rewards.pressed.connect(func() -> void: _show_rewards = false; _rewards_overlay.hide())
	heading.add_child(close_rewards)
	_rewards_summary = Label.new()
	_rewards_summary.add_theme_font_size_override("font_size", 13)
	_rewards_summary.add_theme_color_override("font_color", Color("d7e2e5"))
	_rewards_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_rewards_summary)
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.name = "RankRewardsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroll)
	_rewards_rows = VBoxContainer.new()
	_rewards_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rewards_rows.add_theme_constant_override("separation", 3)
	scroll.add_child(_rewards_rows)
	_replay_reward_button = Button.new()
	_replay_reward_button.name = "ReplayRankCeremonyButton"
	_replay_reward_button.text = "ПОСМОТРЕТЬ ЦЕРЕМОНИЮ"
	_replay_reward_button.tooltip_text = "Показать полученный ранг и медаль ещё раз. Ранг и монеты не начисляются повторно."
	_replay_reward_button.custom_minimum_size = Vector2(220, 38)
	_replay_reward_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_replay_reward_button.add_theme_font_size_override("font_size", 14)
	_replay_reward_button.pressed.connect(func() -> void:
		var systems: Array[Node] = get_tree().get_nodes_in_group("career_system")
		if not systems.is_empty():
			systems[0].replay_rank_ceremony()
	)
	column.add_child(_replay_reward_button)
	_rewards_overlay.hide()

func _refresh_rewards() -> void:
	if _rewards_rows == null:
		return
	var systems: Array[Node] = get_tree().get_nodes_in_group("career_system")
	if systems.is_empty():
		return
	var career_system: Node = systems[0]
	_replay_reward_button.disabled = career_system.get_reward_history().is_empty()
	var progress: Dictionary = career_system.get_command_progress()
	var current_rank: int = int(progress.get("rank", 1))
	var next_activity: int = int(progress.get("next_activity", 0))
	var career_state: Dictionary = GameState.progression_state.get("career", {})
	_rewards_summary.text = "%s · ранг %d из 50\nПолучено за карьеру: %d монет · следующий ранг: %s" % [str(progress.get("stage_name", "Матрос")), current_rank, int(career_state.get("total_reward_coins", 0)), "максимум достигнут" if next_activity == 0 else "%d очков активности" % next_activity]
	for child in _rewards_rows.get_children():
		child.queue_free()
	var claimed: Dictionary = {}
	for record in career_system.get_reward_history():
		claimed[int(record.get("rank", 0))] = record
	for rank in range(1, 51):
		var stage: Dictionary = career_system.get_rank_stage(rank)
		var reward: Dictionary = career_system.get_rank_reward(rank)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 35)
		row.add_theme_constant_override("separation", 8)
		_rewards_rows.add_child(row)
		var medal := TextureRect.new()
		medal.custom_minimum_size = Vector2(30, 30)
		medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		medal.texture = _rank_medal_texture(rank)
		row.add_child(medal)
		var rank_title := Label.new()
		rank_title.text = "Ранг %02d · %s" % [rank, str(stage.get("name", "Матрос"))]
		rank_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rank_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank_title.add_theme_font_size_override("font_size", 13)
		rank_title.add_theme_color_override("font_color", Color("f0d18d") if rank <= current_rank else Color("a8b3b9"))
		row.add_child(rank_title)
		var details := Label.new()
		if claimed.has(rank):
			details.text = "+%d монет · получено" % int(claimed[rank].get("coins", 0))
		elif rank <= current_rank:
			details.text = "Звание открыто"
		elif int(reward.get("coins", 0)) <= 0:
			details.text = "Начальное звание"
		else:
			details.text = "+%d монет%s" % [int(reward.get("coins", 0)), " · рубеж" if bool(reward.get("milestone", false)) else ""]
		details.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		details.add_theme_font_size_override("font_size", 12)
		details.add_theme_color_override("font_color", Color("65d7c9") if claimed.has(rank) else Color("c2c9ca"))
		row.add_child(details)
		_rewards_rows.add_child(HSeparator.new())

func _rank_medal_texture(rank: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/ui/ranks/career_medals.png")
	var stage_index: int = clampi(int((rank - 1) / 10), 0, 4)
	var tile_width: float = float(texture.atlas.get_width()) / 5.0
	texture.region = Rect2(tile_width * stage_index, 0.0, tile_width, float(texture.atlas.get_height()))
	return texture

func _brass_style(edge_x: float, edge_y: float) -> StyleBoxTexture:
	var frame := StyleBoxTexture.new()
	frame.texture = load("res://assets/ui/styles/approved_hud/button_frame.png") as Texture2D
	frame.texture_margin_left = edge_x
	frame.texture_margin_right = edge_x
	frame.texture_margin_top = edge_y
	frame.texture_margin_bottom = edge_y
	frame.draw_center = false
	return frame

func _update_race_identity() -> void:
	var race_id: String = str(GameState.player_state.get("origin_race_id", ""))
	if race_id == _displayed_race_id:
		return
	_displayed_race_id = race_id
	var faction: Dictionary = GameData.get_faction(race_id)
	if faction.is_empty():
		_race_emblem.set_faction("sea_trader")
		_captain_portrait.texture = GameData.get_captain_cabin_art("humans")
		_race_label.text = "Морская компания"
		return
	_race_emblem.set_faction(race_id)
	_captain_portrait.texture = GameData.get_captain_cabin_art(race_id)
	_race_label.text = str(faction.get("name", race_id))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_M or event.physical_keycode == KEY_M:
		_open = not _open
		get_viewport().set_input_as_handled()
