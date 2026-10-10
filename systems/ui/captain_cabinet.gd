extends CanvasLayer

## Captain's cabinet: read-only record of player knowledge.

var _port_system: Node
var _panel: Panel
var _left_panel: PanelContainer
var _label: Label
var _race_emblem: TextureRect
var _race_label: Label
var _captain_portrait: TextureRect
var _brass_frame: Panel
var _backdrop_haze: TextureRect
var _close_button: Button
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
	_captain_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Bleed the art beneath the brass overlay so its inset ornament never leaves
	# a visible strip of the harbor between the image and the frame.
	_captain_portrait.offset_left = -16.0
	_captain_portrait.offset_top = -16.0
	_captain_portrait.offset_right = 16.0
	_captain_portrait.offset_bottom = 16.0
	_captain_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Fill right through to the inner edge of the frame on every screen ratio;
	# the source art fades to navy on that side, so slight aspect crops stay clean.
	_captain_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
	_race_emblem = TextureRect.new()
	_race_emblem.custom_minimum_size = Vector2(58, 58)
	_race_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_race_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
	_panel.hide()

func initialize(port_system: Node) -> void:
	_port_system = port_system

func _process(_delta: float) -> void:
	if _label == null or _port_system == null:
		return
	_panel.visible = _open
	_backdrop_haze.visible = _open
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var coordinator: Node = get_tree().root.find_child("WindowCoordinator", true, false)
	var safe_top: float = maxf(72.0, float(coordinator.get("_top_height"))) if coordinator != null else 72.0
	var available := Vector2(maxf(120.0, viewport_size.x - 32.0), maxf(120.0, viewport_size.y - safe_top - 16.0))
	var art_size: Vector2 = _captain_portrait.texture.get_size() if _captain_portrait.texture != null else Vector2(16.0, 9.0)
	var fit_scale: float = minf(available.x / maxf(1.0, art_size.x), available.y / maxf(1.0, art_size.y))
	_panel.size = art_size * fit_scale
	_panel.position = Vector2((viewport_size.x - _panel.size.x) * 0.5, safe_top)
	_layout_cabin()
	_update_race_identity()
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


func _layout_cabin() -> void:
	if _left_panel == null:
		return
	_left_panel.position = Vector2(18.0, 28.0)
	_left_panel.size = Vector2(clampf(_panel.size.x * 0.39, 260.0, 420.0), maxf(1.0, _panel.size.y - 44.0))

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
		_race_emblem.texture = GameData.get_faction_emblem("sea_trader")
		_captain_portrait.texture = GameData.get_captain_cabin_art("humans")
		_race_label.text = "Морская компания"
		return
	_race_emblem.texture = GameData.get_faction_emblem(race_id)
	_captain_portrait.texture = GameData.get_captain_cabin_art(race_id)
	_race_label.text = str(faction.get("name", race_id))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_M or event.physical_keycode == KEY_M:
		_open = not _open
		get_viewport().set_input_as_handled()
