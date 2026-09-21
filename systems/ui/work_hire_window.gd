extends CanvasLayer

var _system: Node
var _panel: PanelContainer
var _label: Label
var _notice: String = ""
var _open: bool = false

func _ready() -> void:
	add_to_group("work_hire_window")
	layer = 53
	_panel = PanelContainer.new()
	_panel.size = Vector2(700, 500)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 1.0)
	style.border_color = Color(0.72, 0.78, 0.85, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_label)
	var accept_button: Button = Button.new()
	accept_button.text = "Взять работу"
	accept_button.add_theme_font_size_override("font_size", 22)
	accept_button.custom_minimum_size.y = 54
	accept_button.pressed.connect(_accept)
	box.add_child(accept_button)
	var close_button: Button = Button.new()
	close_button.text = "Закрыть"
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.custom_minimum_size.y = 46
	close_button.pressed.connect(_close)
	box.add_child(close_button)
	_panel.hide()

func initialize(system: Node) -> void:
	_system = system

func open() -> void:
	_open = true
	_notice = ""

func _process(_delta: float) -> void:
	_panel.visible = _open
	if not _open or _system == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(700.0, viewport.x - 32.0), minf(500.0, viewport.y - 32.0))
	_panel.position = (viewport - _panel.size) * 0.5
	var active: Dictionary = _system.get_contract()
	if not active.is_empty():
		_label.text = "РАБОТА В НАЙМ\n\nРейс уже принят.\nПорт назначения: %s\nНаграда: %.0f\n\nОплата после швартовки, не раньше 3 минут. Для работы у причала оставайтесь здесь.\n%s" % [
			str(active.get("target_name", "")),
			float(active.get("reward", 0.0)),
			_notice
		]
		return
	var offer: Dictionary = _system.offer()
	_label.text = "РАБОТА В НАЙМ\n\n%s\nПорт назначения: %s\nНаграда: %.0f\n\nДля курьерского рейса порт выделит топливо на маршрут и минимальный ремонт. Работа у причала доступна даже без второго порта.\n%s" % [
		str(offer.get("message", "Рейс доступен.")),
		str(offer.get("target_name", "-")),
		float(offer.get("reward", 0.0)),
		_notice
	]

func _accept() -> void:
	var result: Dictionary = _system.accept()
	_notice = str(result.get("message", ""))

func _close() -> void:
	_open = false
