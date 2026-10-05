extends Node3D

var _base: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _environment: Environment
var _yaw: float = 0.45
var _pitch: float = 0.62
var _distance: float = 240.0
var _caption: Label
var _night: bool = false
var _faction_id: String = "humans"

func _ready() -> void:
	_base = load("res://systems/rendering/home_base_3d.gd").new()
	add_child(_base)
	_base.setup("", 30)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var faction_arg: int = args.find("--faction")
	if faction_arg >= 0 and faction_arg + 1 < args.size():
		_faction_id = args[faction_arg + 1]
		_base.set_showcase_faction(_faction_id)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 48
	_camera.far = 2000
	add_child(_camera)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-48, -30, 0)
	_sun.light_energy = 0.65
	_sun.shadow_enabled = true
	add_child(_sun)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("81bbd4")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("b7d7df")
	_environment.ambient_light_energy = 0.3
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("80b7bb")
	_environment.fog_density = 0.0007
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400, 2400)
	plane.subdivide_width = 512
	plane.subdivide_depth = 512
	water.mesh = plane
	var material := ShaderMaterial.new()
	var shader: Shader = load("res://assets/world/materials/tropical_ocean.gdshader")
	material.shader = shader
	water.material_override = material
	water.position.y = -0.06
	add_child(water)
	var ship_scene: PackedScene = load("res://assets/world/ships/starter_sloop.glb")
	var ship: Node3D = ship_scene.instantiate()
	ship.name = "PlayerArrival"
	ship.position = Vector3(0, 0, -83)
	ship.rotation.y = PI
	add_child(ship)
	var renderer = load("res://systems/rendering/approach_3d_view.gd").new()
	renderer._add_ship_lanterns(ship)
	renderer.free()
	_add_visiting_ships()
	_build_controls()
	if args.has("--approach"):
		_yaw = 0.12
		_pitch = 0.23
		_distance = 185.0
	if args.has("--detail"):
		_yaw = 0.48
		_pitch = 0.50
		_distance = 95.0
	if args.has("--clean"):
		for child in get_children():
			if child is CanvasLayer:
				child.hide()
	if args.has("--night"):
		_set_night(true)
	_update_camera()
	if OS.get_cmdline_user_args().has("--capture"):
		_capture.call_deferred()

func _capture() -> void:
	for index in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--capture")
	if index >= 0 and index + 1 < args.size():
		get_viewport().get_texture().get_image().save_png(args[index + 1])
	get_tree().quit()

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.theme = load("res://systems/ui/game_ui_theme.gd").new().get_theme()
	panel.position = Vector2(18, 18)
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	_caption = Label.new()
	_caption.text = "Портовый город — максимальная застройка, уровень 30"
	stack.add_child(_caption)
	var help := Label.new()
	help.text = "Правая кнопка: обзор · Колесо: приближение\nВсе 8 зданий и 2 башни · просмотр без изменения сохранения"
	stack.add_child(help)
	var levels := HSlider.new()
	levels.min_value = 1
	levels.max_value = 30
	levels.step = 1
	levels.value = 30
	levels.custom_minimum_size.x = 420
	levels.value_changed.connect(_change_level)
	stack.add_child(levels)
	var factions := OptionButton.new()
	var faction_data: Array = GameData.get_factions()
	for faction in faction_data:
		factions.add_item(str(faction.get("name", "")))
		factions.set_item_metadata(factions.item_count - 1, str(faction.get("id", "humans")))
		if str(faction.get("id", "")) == _faction_id:
			factions.select(factions.item_count - 1)
	factions.item_selected.connect(func(index: int): _base.set_showcase_faction(str(factions.get_item_metadata(index))))
	stack.add_child(factions)
	var night := CheckButton.new()
	night.text = "Ночной вид"
	night.toggled.connect(_set_night)
	stack.add_child(night)
	var names := Label.new()
	names.text = "Причал · Склад · Мастерская · Рынок\nВерфь · Гильдия магов · Рыбацкий причал · Лесной терминал"
	stack.add_child(names)

func _change_level(value: float) -> void:
	_base.set_showcase_level(int(value))
	_caption.text = "База — все здания, уровень %d" % int(value)

func _set_night(enabled: bool) -> void:
	_night = enabled
	_base.set_night_strength(1.0 if enabled else 0.0)
	_sun.light_energy = 0.10 if enabled else 0.65
	_sun.light_color = Color("91b4e3") if enabled else Color("fff0d2")
	_environment.background_color = Color("081629") if enabled else Color("81bbd4")
	_environment.ambient_light_energy = 0.18 if enabled else 0.3
	_environment.fog_light_color = Color("152b42") if enabled else Color("80b7bb")
	var renderer = load("res://systems/rendering/approach_3d_view.gd").new()
	for ship in get_children():
		if ship is Node3D and (str(ship.name).begins_with("HarborVisitor_") or ship.name == "PlayerArrival"):
			renderer._update_lanterns_for(ship, 1.0 if enabled else 0.0)
	renderer.free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * 0.006
		_pitch = clampf(_pitch + event.relative.y * 0.005, 0.15, 1.35)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(35, _distance * 0.92)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(400, _distance / 0.92)
		_update_camera()

func _update_camera() -> void:
	_camera.position = Vector3(sin(_yaw)*cos(_pitch), sin(_pitch), -cos(_yaw)*cos(_pitch)) * _distance
	_camera.look_at(Vector3(0, 25, 0))
	if OS.get_cmdline_user_args().has("--detail"):
		_camera.look_at(Vector3(0, 4, -12))

func _add_visiting_ships() -> void:
	var ids := ["ship_barque", "ship_schooner", "premium_salvage_schooner", "premium_royal_schooner", "premium_golden_clipper"]
	var visuals: Dictionary = GameData.read("res://data/world/ship_visuals.json").ships
	var style = load("res://systems/rendering/faction_base_style.gd").new()
	var factions := ["nerids", "surr", "meridians", "aery", "humans"]
	for index in range(ids.size()):
		var visual: Dictionary = visuals[ids[index]]
		var variant: Dictionary = GameData.read("res://data/world/faction_ship_visuals.json").get("factions", {}).get(factions[index], {}).get(ids[index], {})
		var ship: Node3D = load(str(variant.get("scene", visual.scene))).instantiate()
		ship.name = "HarborVisitor_%d" % index
		ship.scale = Vector3.ONE * 7.0 / float(visual.length)
		ship.position = Vector3(-15 if index % 2 == 0 else 15, 0.1, -24 - (index / 2) * 12)
		ship.rotation.y = PI if index % 2 == 0 else 0
		add_child(ship)
		style.apply_ship(ship, factions[index])
		var flag: Node3D = style.make_flag(factions[index])
		var at: Array = visual.flag_at
		flag.position = Vector3(at[0], at[1], at[2])
		flag.scale = Vector3.ONE * 0.28
		ship.add_child(flag)
		var renderer = load("res://systems/rendering/approach_3d_view.gd").new()
		renderer._add_ship_lanterns(ship, visual.lamps, false)
		renderer.free()
