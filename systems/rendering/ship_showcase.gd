extends Node3D

## Read-only fleet viewer: the same assets, paints and flags as the sailing view.
var _ids: Array[String] = []
var _index: int = 0
var _faction: String = "humans"
var _ship: Node3D
var _caption: Label
var _camera: Camera3D
var _sun: DirectionalLight3D
var _night: bool = false
var _clock: float = 0.0
var _yaw: float = 0.6
var _dragging: bool = false

func _ready() -> void:
	for definition in GameData.get_ships():
		_ids.append(str(definition.id))
	var args := OS.get_cmdline_user_args()
	var selected := args.find("--ship")
	if selected >= 0 and selected + 1 < args.size():
		_index = maxi(0, _ids.find(args[selected + 1]))
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 42
	add_child(_camera)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-45, -35, 0)
	_sun.shadow_enabled = true
	_sun.light_energy = 0.8
	add_child(_sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("7faabd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c0dae2")
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	water.mesh = plane
	water.position.y = -0.16
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("155568")
	material.roughness = 0.7
	water.material_override = material
	add_child(water)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.theme = load("res://systems/ui/game_ui_theme.gd").new().get_theme()
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_caption = Label.new()
	column.add_child(_caption)
	var row := HBoxContainer.new()
	column.add_child(row)
	for value in [-1, 1]:
		var button := Button.new()
		button.text = "← Корабль" if value < 0 else "Корабль →"
		button.pressed.connect(_change.bind(value))
		row.add_child(button)
	var faction := OptionButton.new()
	for definition in GameData.get_factions():
		faction.add_item(str(definition.name))
		faction.set_item_metadata(faction.item_count - 1, str(definition.id))
		if str(definition.id) == _faction:
			faction.select(faction.item_count - 1)
	faction.item_selected.connect(func(index: int):
		_faction = str(faction.get_item_metadata(index))
		_rebuild())
	row.add_child(faction)
	var night := Button.new()
	night.text = "День / ночь"
	night.pressed.connect(func():
		_night = not _night
		_sun.light_energy = 0.12 if _night else 0.8
		environment.ambient_light_energy = 0.22 if _night else 0.6
		environment.background_color = Color("08192e") if _night else Color("7faabd")
		_rebuild())
	row.add_child(night)
	var help := Label.new()
	help.text = "Мышь: зажмите правую кнопку и вращайте · ← / →: корабль"
	column.add_child(help)
	_rebuild()
	var capture := args.find("--capture")
	if capture >= 0 and capture + 1 < args.size():
		for index in range(12):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[capture + 1])
		get_tree().quit()

func _change(step: int) -> void:
	_index = posmod(_index + step, _ids.size())
	_rebuild()

func _rebuild() -> void:
	if is_instance_valid(_ship):
		remove_child(_ship)
		_ship.queue_free()
	var id := _ids[_index]
	var visual: Dictionary = GameData.read("res://data/world/ship_visuals.json").ships[id]
	_ship = load(str(visual.scene)).instantiate()
	_ship.scale = Vector3.ONE * 6.15 / float(visual.length)
	add_child(_ship)
	var style = load("res://systems/rendering/faction_base_style.gd").new()
	style.apply_ship(_ship, _faction)
	var flag: Node3D = style.make_flag(_faction)
	var anchor: Array = visual.flag_at
	flag.position = Vector3(anchor[0], anchor[1], anchor[2])
	flag.scale = Vector3.ONE * 0.28
	_ship.add_child(flag)
	# The sailing renderer owns the lantern geometry and warm-light behavior.
	var renderer = load("res://systems/rendering/approach_3d_view.gd").new()
	renderer._add_ship_lanterns(_ship, visual.lamps)
	renderer._update_lanterns_for(_ship, 1.0 if _night else 0.0)
	renderer.free()
	_caption.text = "%02d / %02d  ·  %s" % [_index + 1, _ids.size(), str(GameData.get_ship(id).name)]

func _process(delta: float) -> void:
	_clock += delta
	_camera.position = Vector3(sin(_yaw) * 12, 7, cos(_yaw) * 12)
	_camera.look_at(Vector3(0, 1.0, 0))
	if is_instance_valid(_ship):
		_ship.position.y = sin(_clock * 1.7) * 0.045
		_ship.rotation.z = sin(_clock * 1.35) * deg_to_rad(2)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.008
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			_change(-1)
		elif event.keycode == KEY_RIGHT:
			_change(1)
