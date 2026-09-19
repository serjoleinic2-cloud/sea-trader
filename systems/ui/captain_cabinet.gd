extends CanvasLayer

## Captain's cabinet: read-only record of player knowledge.

var _port_system: Node
var _panel: PanelContainer
var _label: Label
var _open := false

func _ready() -> void:
	layer = 40
	_panel = PanelContainer.new()
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	panel_style.border_color = Color(0.22, 0.45, 0.62, 1.0)
	panel_style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.position = Vector2(12, 12)
	_panel.size = Vector2(520, 620)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_panel.add_child(margin)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 19)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_label)
	_panel.hide()

func initialize(port_system: Node) -> void:
	_port_system = port_system

func _process(_delta: float) -> void:
	if _label == null or _port_system == null:
		return
	_panel.visible = _open
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = Vector2(maxf(12.0, viewport_size.x - _panel.size.x - 12.0), 12.0)
	if not _open:
		return
	var stats: Dictionary = GameState.player_state.get("stats", {})
	var systems: Array[Node] = get_tree().get_nodes_in_group("career_system")
	var career: Dictionary = systems[0].get_command_progress() if not systems.is_empty() else {}
	var activity_score: int = int(career.get("activity", 0))
	var next_requirement: int = int(career.get("next_activity", 0))
	var lines: PackedStringArray = ["КАБИНЕТ КАПИТАНА", ""]
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


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_M or event.physical_keycode == KEY_M:
		_open = not _open
		get_viewport().set_input_as_handled()
