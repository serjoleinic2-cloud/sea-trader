extends CanvasLayer

## Rank promotions use a dismissible full-screen ceremony. Experience stays a short toast.

const MEDAL_ART := "res://assets/ui/ranks/career_medals.png"
const CELEBRATION_ART := "res://assets/ui/ranks/rank_celebration_backdrop.png"

var _toast: PanelContainer
var _toast_title: Label
var _toast_body: Label
var _toast_medal: TextureRect
var _toast_queue: Array[Dictionary] = []
var _toast_remaining := 0.0
var _toast_tween: Tween

var _ceremony: Control
var _ceremony_medal: TextureRect
var _ceremony_stage: Label
var _ceremony_rank: Label
var _ceremony_reward: Label
var _rank_queue: Array[Dictionary] = []
var _was_paused := false

func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_toast()
	_build_ceremony()
	get_viewport().size_changed.connect(_layout)

func enqueue_experience(amount: int, total: int) -> void:
	if amount <= 0:
		return
	_toast_queue.append({"amount": amount, "total": total})
	_show_next_toast()

func enqueue_rank(rank: int, stage_name: String, experience: int, coins: int, milestone: bool) -> void:
	_rank_queue.append({"rank": rank, "stage_name": stage_name, "experience": experience, "coins": coins, "milestone": milestone})
	_show_next_rank()

func _process(delta: float) -> void:
	if not _toast.visible or not _rank_queue.is_empty() or _ceremony.visible:
		return
	_toast_remaining -= delta
	if _toast_remaining <= 0.0:
		_toast.hide()
		_show_next_toast()

func _unhandled_key_input(event: InputEvent) -> void:
	if _ceremony.visible and event.is_action_pressed("ui_cancel"):
		_close_ceremony()
		get_viewport().set_input_as_handled()

func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.name = "CareerExperienceToast"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e90a1721")
	style.border_color = Color("d4ad62")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_toast.add_theme_stylebox_override("panel", style)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.hide()
	add_child(_toast)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	_toast.add_child(row)
	_toast_medal = TextureRect.new()
	_toast_medal.custom_minimum_size = Vector2(60, 60)
	_toast_medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_toast_medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_toast_medal)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	_toast_title = _label(19, Color("f3d797"), column)
	_toast_body = _label(14, Color("e5edf0"), column)
	_layout()

func _build_ceremony() -> void:
	_ceremony = Control.new()
	_ceremony.name = "RankCelebration"
	_ceremony.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ceremony.mouse_filter = Control.MOUSE_FILTER_STOP
	_ceremony.process_mode = Node.PROCESS_MODE_ALWAYS
	_ceremony.hide()
	add_child(_ceremony)
	var backdrop := TextureRect.new()
	backdrop.texture = load(CELEBRATION_ART)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ceremony.add_child(backdrop)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.30)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ceremony.add_child(shade)
	var close := Button.new()
	close.name = "CloseRankCelebration"
	close.tooltip_text = "Закрыть церемонию · Esc"
	close.anchor_left = 1.0
	close.anchor_right = 1.0
	close.offset_left = -66.0
	close.offset_top = 18.0
	close.offset_right = -18.0
	close.offset_bottom = 66.0
	close.pressed.connect(_close_ceremony)
	_ceremony.add_child(close)
	var close_style: Node = load("res://systems/ui/brass_close_button.gd").new()
	close_style.apply(close)
	var stack := VBoxContainer.new()
	stack.name = "CeremonyContent"
	stack.anchor_left = 0.5
	stack.anchor_top = 0.5
	stack.anchor_right = 0.5
	stack.anchor_bottom = 0.5
	stack.offset_left = -340.0
	stack.offset_top = -240.0
	stack.offset_right = 340.0
	stack.offset_bottom = 285.0
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 10)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ceremony.add_child(stack)
	var eyebrow := _label(19, Color("ffdda1"), stack)
	eyebrow.text = "ТОРЖЕСТВЕННОЕ ПОВЫШЕНИЕ"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ceremony_stage = _label(42, Color("fff0cd"), stack)
	_ceremony_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ceremony_stage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ceremony_rank = _label(22, Color("f7cd78"), stack)
	_ceremony_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ceremony_medal = TextureRect.new()
	_ceremony_medal.custom_minimum_size = Vector2(176, 176)
	_ceremony_medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ceremony_medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ceremony_medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ceremony_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_ceremony_medal)
	_ceremony_reward = _label(22, Color("fff3d7"), stack)
	_ceremony_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var continue_button := Button.new()
	continue_button.text = "ПРОДОЛЖИТЬ"
	continue_button.custom_minimum_size = Vector2(230, 54)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.add_theme_font_size_override("font_size", 20)
	continue_button.add_theme_color_override("font_color", Color("291a0c"))
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("e6bb64")
	button_style.border_color = Color("fff0bd")
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(8)
	button_style.content_margin_left = 22
	button_style.content_margin_right = 22
	button_style.content_margin_top = 10
	button_style.content_margin_bottom = 10
	continue_button.add_theme_stylebox_override("normal", button_style)
	var hover_style := button_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("ffda86")
	continue_button.add_theme_stylebox_override("hover", hover_style)
	continue_button.add_theme_stylebox_override("pressed", button_style)
	continue_button.pressed.connect(_close_ceremony)
	continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.add_child(continue_button)

func _label(font_size: int, color: Color, parent: Node) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.01, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _show_next_toast() -> void:
	if _toast == null or _toast.visible or _toast_queue.is_empty() or _ceremony.visible or not _rank_queue.is_empty():
		return
	var event: Dictionary = _toast_queue.pop_front()
	_toast_title.text = "ОПЫТ КАРЬЕРЫ +%d" % int(event.get("amount", 0))
	_toast_body.text = "Всего очков карьеры: %d" % int(event.get("total", 0))
	_set_medal(_toast_medal, 0)
	_toast.show()
	_toast_remaining = 5.0
	_toast.modulate.a = 0.0
	if _toast_tween != null and _toast_tween.is_running():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.22)

func _show_next_rank() -> void:
	if _ceremony == null or _ceremony.visible or _rank_queue.is_empty():
		return
	if not _toast_queue.is_empty():
		_toast.hide()
	var event: Dictionary = _rank_queue.pop_front()
	var rank := int(event.get("rank", 1))
	_ceremony_stage.text = str(event.get("stage_name", "Матрос")).to_upper()
	_ceremony_rank.text = "ЗВАНИЕ  ·  РАНГ %d" % rank
	var reward := "НАГРАДА  ·  +%d МОНЕТ" % int(event.get("coins", 0))
	if int(event.get("experience", 0)) > 0:
		reward += "\nОпыт карьеры +%d" % int(event.get("experience", 0))
	if bool(event.get("milestone", false)):
		reward += "  ·  ЮБИЛЕЙНЫЙ РУБЕЖ"
	_ceremony_reward.text = reward
	_set_medal(_ceremony_medal, rank)
	_was_paused = get_tree().paused
	get_tree().paused = true
	_ceremony.show()
	_ceremony.modulate.a = 0.0
	var stack := _ceremony.get_node("CeremonyContent") as Control
	stack.scale = Vector2(0.88, 0.88)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_ceremony, "modulate:a", 1.0, 0.35)
	tween.tween_property(stack, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_layout()

func _close_ceremony() -> void:
	if not _ceremony.visible:
		return
	_ceremony.hide()
	get_tree().paused = _was_paused
	_show_next_rank()
	_show_next_toast()

func _set_medal(target: TextureRect, rank: int) -> void:
	var atlas := load(MEDAL_ART) as Texture2D
	if atlas == null:
		return
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	var stage_index := 0 if rank <= 10 else 1 if rank <= 20 else 2 if rank <= 30 else 3 if rank <= 40 else 4
	var tile_width := float(atlas.get_width()) / 5.0
	texture.region = Rect2(tile_width * stage_index, 0.0, tile_width, float(atlas.get_height()))
	target.texture = texture

func _layout() -> void:
	if _toast == null:
		return
	var viewport := get_viewport().get_visible_rect().size
	var coordinator: Node = get_tree().root.find_child("WindowCoordinator", true, false)
	var top := float(coordinator.get("_top_height")) if coordinator != null else 76.0
	var width := minf(510.0, viewport.x - 28.0)
	_toast.position = Vector2((viewport.x - width) * 0.5, top + 10.0)
	_toast.size = Vector2(maxf(220.0, width), 82.0)
	if _ceremony != null:
		var stack := _ceremony.get_node_or_null("CeremonyContent") as Control
		if stack != null:
			var scale := minf(1.0, minf(viewport.x / 1360.0, viewport.y / 760.0))
			stack.scale = Vector2.ONE * scale
			stack.offset_left = -340.0
			stack.offset_top = -250.0
			stack.offset_right = 340.0
			stack.offset_bottom = 285.0
