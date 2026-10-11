extends CanvasLayer

## Brief, queued rank and career-experience announcements.

const MEDAL_ART := "res://assets/ui/ranks/career_medals.png"

var _panel: PanelContainer
var _medal: TextureRect
var _title: Label
var _body: Label
var _queue: Array[Dictionary] = []
var _remaining: float = 0.0
var _fade_tween: Tween

func _ready() -> void:
	layer = 150
	_panel = PanelContainer.new()
	_panel.name = "CareerAnnouncement"
	_panel.set_meta("preserve_art_style", true)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e90a1721")
	style.border_color = Color("d4ad62")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	_panel.hide()
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	_panel.add_child(row)
	_medal = TextureRect.new()
	_medal.custom_minimum_size = Vector2(60, 60)
	_medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_medal)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 3)
	row.add_child(text_column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 19)
	_title.add_theme_color_override("font_color", Color("f3d797"))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_column.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 14)
	_body.add_theme_color_override("font_color", Color("e5edf0"))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_column.add_child(_body)
	_layout()
	get_viewport().size_changed.connect(_layout)

func enqueue_experience(amount: int, total: int) -> void:
	if amount <= 0:
		return
	_queue.append({"kind": "experience", "amount": amount, "total": total})
	_show_next()

func enqueue_rank(rank: int, stage_name: String, experience: int, coins: int, milestone: bool) -> void:
	_queue.append({"kind": "rank", "rank": rank, "stage_name": stage_name, "experience": experience, "coins": coins, "milestone": milestone})
	_show_next()

func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_remaining -= delta
	if _remaining <= 0.45 and _panel.modulate.a > 0.0 and (_fade_tween == null or not _fade_tween.is_running()):
		_fade_tween = create_tween()
		_fade_tween.tween_property(_panel, "modulate:a", 0.0, 0.4)
	if _remaining <= 0.0:
		_panel.hide()
		_panel.scale = Vector2.ONE
		_show_next()

func _show_next() -> void:
	if _panel == null or _panel.visible or _queue.is_empty():
		return
	var event: Dictionary = _queue.pop_front()
	if str(event.get("kind", "")) == "rank":
		var rank: int = int(event.get("rank", 1))
		_title.text = "НОВОЕ ЗВАНИЕ · %s" % str(event.get("stage_name", "Матрос")).to_upper()
		var body := "Ранг %d" % rank
		if int(event.get("experience", 0)) > 0:
			body += "  ·  Опыт карьеры +%d" % int(event.experience)
		body += "\nНаграда: +%d монет" % int(event.get("coins", 0))
		if bool(event.get("milestone", false)):
			body += "  ·  рубежный ранг"
		_body.text = body
		_set_medal(rank)
	else:
		_title.text = "ОПЫТ КАРЬЕРЫ +%d" % int(event.get("amount", 0))
		_body.text = "Всего очков карьеры: %d" % int(event.get("total", 0))
		_set_medal(0)
	_panel.show()
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(_panel, "modulate:a", 1.0, 0.24)
	_fade_tween.tween_property(_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_remaining = 5.0
	_layout()

func _set_medal(rank: int) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = load(MEDAL_ART)
	var stage_index: int = 0 if rank <= 10 else 1 if rank <= 20 else 2 if rank <= 30 else 3 if rank <= 40 else 4
	var tile_width: float = float(texture.atlas.get_width()) / 5.0
	texture.region = Rect2(tile_width * stage_index, 0.0, tile_width, float(texture.atlas.get_height()))
	_medal.texture = texture

func _layout() -> void:
	if _panel == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var coordinator: Node = get_tree().root.find_child("WindowCoordinator", true, false)
	var top: float = float(coordinator.get("_top_height")) if coordinator != null else 76.0
	var width: float = minf(510.0, viewport.x - 28.0)
	_panel.position = Vector2((viewport.x - width) * 0.5, top + 10.0)
	_panel.size = Vector2(maxf(220.0, width), 82.0)
