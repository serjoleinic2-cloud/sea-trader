extends CanvasLayer

## Compact early-game guide. It sets a course but never controls the ship.
var _ports: Node
var _contracts: Node
var _main: Node
var _panel: PanelContainer
var _text: Label
var _action: Button
var _last_phase: String = ""

func _ready() -> void:
	layer = 55
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.96)
	style.border_color = Color(0.92, 0.68, 0.25, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 19)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	_action = Button.new()
	_action.add_theme_font_size_override("font_size", 18)
	_action.custom_minimum_size.y = 42
	_action.pressed.connect(_perform_action)
	box.add_child(_action)
	_panel.hide()

func initialize(port_system: Node, contract_system: Node, main: Node) -> void:
	_ports = port_system
	_contracts = contract_system
	_main = main

func get_guide_state() -> Dictionary:
	var stats: Dictionary = GameState.player_state.get("stats", {})
	if int(stats.get("total_deliveries", 0)) > 0:
		return {"phase": "complete"}
	var visited: Array = GameState.player_state.get("visited_port_ids", [])
	if visited.size() < 2:
		return {"phase": "explore"}
	var active: Dictionary = _contracts.get_active() if _contracts != null else {}
	if active.is_empty():
		return {"phase": "accept"}
	if not bool(active.get("loaded", false)):
		return {"phase": "load"}
	if str(GameState.ship_state.get("docked_port_id", "")) == str(active.get("destination_port_id", "")):
		return {"phase": "complete_contract"}
	return {"phase": "deliver", "destination_port_id": str(active.get("destination_port_id", ""))}

func _process(_delta: float) -> void:
	if _panel == null:
		return
	var state: Dictionary = get_guide_state()
	var phase: String = str(state.phase)
	_last_phase = phase
	_panel.visible = phase != "complete"
	if not _panel.visible:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(430.0, viewport.x - 24.0), 144.0)
	_panel.position = Vector2(12.0, maxf(210.0, viewport.y - _panel.size.y - 76.0))
	match str(state.phase):
		"explore":
			var nearest_id: String = _ports.get_nearest_undiscovered_port_id() if _ports != null else ""
			var nearest_name: String = _ports.get_port_name(nearest_id) if nearest_id != "" else "неизвестному порту"
			_text.text = "ПЕРВЫЙ РЕЙС\nДержите курс на порт «%s». У его причала нажмите E, чтобы бросить якорь." % nearest_name
			_action.text = "КУРС К ПОРТУ ?"
			_action.tooltip_text = "Курс подсказывает направление. Управляйте кораблём вручную."
			_action.disabled = _ports == null or _ports.get_nearest_undiscovered_port_id() == ""
		"accept":
			var port_name: String = _ports.get_port_name(str(GameState.ship_state.get("docked_port_id", ""))) if _ports != null else ""
			_text.text = "ПОРТ «%s»\nОкно первого заказа открыто. Нажмите «ПРИНЯТЬ ЗАКАЗ»." % port_name
			_action.text = "ОТКРЫТЬ ЗАКАЗ"
			_action.disabled = str(GameState.ship_state.get("docked_port_id", "")) == ""
		"load":
			var port_name: String = _ports.get_port_name(str(GameState.ship_state.get("docked_port_id", ""))) if _ports != null else ""
			_text.text = "ЗАКАЗ ПРИНЯТ В ПОРТУ «%s»\nЗагрузите опечатанный груз в трюм." % port_name
			_action.text = "ОТКРЫТЬ ЗАКАЗ"
			_action.disabled = false
		"deliver":
			var destination_name: String = _ports.get_port_name(str(state.get("destination_port_id", ""))) if _ports != null else ""
			_text.text = "ГРУЗ В ТРЮМЕ\nВезите его в порт «%s». У причала нажмите E. Автопилот для первого заказа не используется." % destination_name
			_action.text = "УКАЗАТЬ КУРС"
			_action.disabled = false
		"complete_contract":
			var destination_name: String = _ports.get_port_name(str(GameState.ship_state.get("docked_port_id", ""))) if _ports != null else ""
			_text.text = "ВЫ В ПОРТУ «%s»\nСдайте заказ и получите награду." % destination_name
			_action.text = "СДАТЬ ЗАКАЗ"
			_action.disabled = false

func _perform_action() -> void:
	var state: Dictionary = get_guide_state()
	match str(state.phase):
		"explore":
			_ports.set_exploration_destination(_ports.get_nearest_undiscovered_port_id())
		"accept":
			_open_contract_window()
		"load", "complete_contract":
			_open_contract_window()
		"deliver":
			_ports.select_destination(str(state.get("destination_port_id", "")))

func _open_contract_window() -> void:
	var windows: Array[Node] = get_tree().get_nodes_in_group("transport_contract_window")
	if not windows.is_empty():
		windows[0].open()
