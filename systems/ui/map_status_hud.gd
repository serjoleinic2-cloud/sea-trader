extends CanvasLayer

## Read-only map knowledge summary.

var _port_system: Node
var _panel: ColorRect
var _label: Label
var _race_emblem: TextureRect
var _race_id: String = ""

func _ready() -> void:
	layer = 20
	_panel = ColorRect.new()
	_panel.position = Vector2(12, 12)
	_panel.size = Vector2(300, 180)
	_panel.color = Color(0.02, 0.03, 0.04, 1.0)
	add_child(_panel)
	_race_emblem = TextureRect.new()
	_race_emblem.position = Vector2(16, 16)
	_race_emblem.size = Vector2(48, 48)
	_race_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_race_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_race_emblem)
	_label = Label.new()
	_label.position = Vector2(76, 18)
	_label.size = Vector2(220, 154)
	_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0, 1.0))
	_label.add_theme_font_size_override("font_size", 19)
	add_child(_label)

func initialize(port_system: Node) -> void:
	_port_system = port_system

func _process(_delta: float) -> void:
	if _label == null:
		return
	_update_race_emblem()
	var nearest: String = "-"
	if _port_system != null and str(_port_system.nearest_port_name) != "":
		nearest = str(_port_system.nearest_port_name)
	var home_port: String = str(GameState.world_state.get("home_port_id", ""))
	var home_name: String = "не назначен"
	if home_port != "" and _port_system != null:
		home_name = _port_system.get_port_name(home_port)
	_label.text = (
		"КАРТА\n"
		+ "Открыто портов: %d\n"
		+ "Известно путей: %d\n"
		+ "Ближайший: %s\n"
		+ "Главный порт: %s\n"
		+ "Кабинет капитана: M"
	) % [
		GameState.player_state.get("visited_port_ids", []).size(),
		GameState.known_routes_state.size(),
		nearest,
		home_name
	]


func _update_race_emblem() -> void:
	var race_id: String = str(GameState.player_state.get("origin_race_id", ""))
	if race_id == _race_id:
		return
	_race_id = race_id
	_race_emblem.texture = GameData.get_faction_emblem(race_id)
