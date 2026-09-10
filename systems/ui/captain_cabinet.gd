extends CanvasLayer

## Captain's cabinet: read-only record of player knowledge.

var _port_system: Node
var _panel: PanelContainer
var _label: Label
var _open := false
var _progression_config: Dictionary = {}

func _ready() -> void:
	layer = 40
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.size = Vector2(520, 620)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_panel.add_child(margin)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_label)
	_panel.hide()
	_progression_config = SaveSystem._read_json("res://data/employees/captain_progression.json")

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
	var ship: Dictionary = GameState.ship_state
	var stats: Dictionary = GameState.player_state.get("stats", {})
	var activity_score: int = _calculate_activity_score(stats)
	var sailor_stage: Dictionary = _get_sailor_stage(activity_score)
	var next_requirement: int = _get_next_sailor_requirement(activity_score)
	var lines: PackedStringArray = ["CAPTAIN'S CABINET", "Press M to close", ""]
	lines.append("CAREER")
	lines.append("Rank: Sailor %d / 5" % int(sailor_stage.get("stage", 1)))
	lines.append("Activity: %d%s" % [activity_score, "" if next_requirement == 0 else " / %d" % next_requirement])
	lines.append("Distance: %.0f | Voyages: %d" % [float(stats.get("total_distance", 0.0)), int(stats.get("total_voyages", 0))])
	lines.append("Safe dockings: %d | Ports: %d" % [int(stats.get("safe_dockings", 0)), int(stats.get("ports_discovered", 0))])
	lines.append("")
	lines.append("SHIP")
	lines.append("Position: %d, %d" % [int(ship.get("position", Vector2.ZERO).x), int(ship.get("position", Vector2.ZERO).y)])
	lines.append("Fuel: %.1f / %.0f" % [float(ship.get("fuel", 0.0)), float(ship.get("fuel_max", 0.0))])
	lines.append("Hull: %.0f" % float(ship.get("hull", 0.0)))
	lines.append("Docked: " + (str(ship.get("docked_port_id", "")) if ship.get("docked_port_id", "") != "" else "at sea"))
	lines.append("")
	lines.append("DISCOVERED PORTS: %d" % GameState.player_state.discovered_port_ids.size())
	for port_id in GameState.player_state.discovered_port_ids:
		var name: String = str(_port_system.get_port_name(port_id)) if _port_system.has_method("get_port_name") else str(port_id)
		lines.append("- " + (name if name != "" else str(port_id)))
	lines.append("")
	lines.append("KNOWN ROUTES: %d" % GameState.known_routes_state.size())
	for route_key in GameState.known_routes_state:
		lines.append("- " + str(route_key))
	_label.text = "\n".join(lines)


func _calculate_activity_score(stats: Dictionary) -> int:
	var metrics: Dictionary = _progression_config.get("activity_metrics", {})
	var sales: Dictionary = metrics.get("total_sales", {})
	var deliveries: Dictionary = metrics.get("total_deliveries", {})
	var voyages: Dictionary = metrics.get("total_voyages", {})
	var cargo: Dictionary = metrics.get("cargo_units_moved", {})
	var dockings: Dictionary = metrics.get("safe_dockings", {})
	var ports: Dictionary = metrics.get("ports_discovered", {})
	var score: float = 0.0
	score += float(stats.get("total_sales", 0)) * float(sales.get("weight", 0.0))
	score += float(stats.get("total_deliveries", 0)) * float(deliveries.get("weight", 0.0))
	score += floor(float(stats.get("total_distance", 0.0)) / float(metrics.get("distance_unit", 1000.0))) * float(metrics.get("distance_weight", 0.0))
	score += float(stats.get("total_voyages", 0)) * float(voyages.get("weight", 0.0))
	score += float(stats.get("cargo_units_moved", 0)) * float(cargo.get("weight", 0.0))
	score += float(stats.get("safe_dockings", 0)) * float(dockings.get("weight", 0.0))
	score += float(stats.get("ports_discovered", 0)) * float(ports.get("weight", 0.0))
	return int(score)


func _get_sailor_stage(activity_score: int) -> Dictionary:
	var ranks: Dictionary = _progression_config.get("ranks", {})
	var sailor: Dictionary = ranks.get("sailor", {})
	var stages: Array = sailor.get("stages", [])
	var current: Dictionary = {"stage": 1, "required_activity": 0}
	for raw_stage in stages:
		var stage: Dictionary = raw_stage
		if activity_score >= int(stage.get("required_activity", 0)):
			current = stage
	return current


func _get_next_sailor_requirement(activity_score: int) -> int:
	var ranks: Dictionary = _progression_config.get("ranks", {})
	var sailor: Dictionary = ranks.get("sailor", {})
	var stages: Array = sailor.get("stages", [])
	for raw_stage in stages:
		var stage: Dictionary = raw_stage
		var requirement: int = int(stage.get("required_activity", 0))
		if requirement > activity_score:
			return requirement
	return 0

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_M or event.physical_keycode == KEY_M:
		_open = not _open
		get_viewport().set_input_as_handled()
