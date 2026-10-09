extends CanvasLayer

## Read-only inspection: one isolated viewport, shared sailing models and heraldry.
var _root: Control
var _panel: PanelContainer
var _viewport: SubViewport
var _surface: SubViewportContainer
var _world: Node3D
var _camera: Camera3D
var _model: Node3D
var _selector: OptionButton
var _details: Label
var _yaw: float = .65
var _pitch: float = .30
var _zoom: float = 1.0
var _radius: float = 4.0
var _center := Vector3.ZERO
var _is_open: bool = false

static func show_ship(owner_node: Node, ship_id: String) -> void:
	var viewer: Node = owner_node.get_tree().get_first_node_in_group("ship_inspection_window")
	if viewer == null:
		viewer = load("res://systems/ui/ship_inspection_window.gd").new()
		owner_node.get_tree().root.add_child(viewer)
	viewer.open_ship(ship_id)

func _ready() -> void:
	add_to_group("ship_inspection_window")
	layer = 110
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_panel = PanelContainer.new()
	_panel.theme = preload("res://systems/ui/game_ui_theme.gd").new().get_theme()
	_root.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var row := VBoxContainer.new()
	column.add_child(row)
	_selector = OptionButton.new()
	_selector.fit_to_longest_item = false
	_selector.custom_minimum_size.x = 240
	_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ship in GameData.get_ships():
		_selector.add_item(str(ship.name))
		_selector.set_item_metadata(_selector.item_count-1,str(ship.id))
	_selector.item_selected.connect(func(index: int): _load_ship(str(_selector.get_item_metadata(index))))
	row.add_child(_selector)
	var close := Button.new()
	close.text = "Закрыть ✕"
	preload("res://systems/ui/brass_close_button.gd").apply(close)
	close.pressed.connect(_close)
	row.add_child(close)
	_surface = SubViewportContainer.new()
	_surface.custom_minimum_size = Vector2(260,220)
	_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_surface.stretch = true
	_surface.gui_input.connect(_on_input)
	column.add_child(_surface)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	_surface.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_camera = Camera3D.new()
	_camera.fov = 38
	_camera.current = true
	_world.add_child(_camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("122c3a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c0d3df")
	environment.environment.ambient_light_energy = .65
	_world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42,-35,0)
	light.light_energy = .9
	_world.add_child(light)
	_details = Label.new()
	_details.set_meta("compact_hud",true)
	_details.add_theme_font_size_override("font_size",14)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_details)
	var help := Label.new()
	help.text = "Зажмите мышь: вращение · Колесо: приближение · Двойной щелчок: исходный вид · Esc: закрыть"
	help.set_meta("compact_hud",true)
	help.add_theme_font_size_override("font_size",12)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	for control in [row,_surface,_details,help]: column.remove_child(control)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",20)
	column.add_child(body)
	var information := VBoxContainer.new()
	information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information.size_flags_stretch_ratio = .55
	information.add_theme_constant_override("separation",18)
	body.add_child(information)
	for control in [row,_details,help]: information.add_child(control)
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.size_flags_stretch_ratio = 1.3
	body.add_child(_surface)
	_close()

func open_ship(id: String) -> void:
	_is_open = true
	_root.show()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for index in _selector.item_count:
		if str(_selector.get_item_metadata(index)) == id: _selector.select(index)
	_load_ship(id)

func _load_ship(id: String) -> void:
	if is_instance_valid(_model):
		_world.remove_child(_model)
		_model.queue_free()
	var race: String = str(GameState.player_state.get("origin_race_id","humans"))
	var definition: Dictionary = GameData.get_ship(id)
	if bool(definition.get("warship", false)): race = str(definition.faction_id)
	var visual: Dictionary = GameData.read("res://data/world/ship_visuals.json").get("ships",{}).get(id,{})
	var renderer = preload("res://systems/rendering/approach_3d_view.gd").new()
	renderer._asset_catalog = GameData.read("res://data/world/world_asset_catalog.json")
	_model = renderer._attach_catalog_scene(_world,"ships",id,float(visual.get("display_length",4.0)),race)
	if _model != null:
		var style = preload("res://systems/rendering/faction_base_style.gd").new()
		style.apply_ship(_model,race)
		var flag: Node3D = style.make_flag(race)
		var anchor: Array = visual.get("flag_at",[0,1.3,2.6])
		flag.position = Vector3(anchor[0],anchor[1],anchor[2])
		flag.scale = Vector3.ONE*.28
		_model.add_child(flag)
		renderer._add_ship_lanterns(_model,visual.get("lamps",[]))
		var bounds: Array[AABB] = []
		_collect_bounds(_model,bounds)
		var box := AABB()
		for index in bounds.size(): box = bounds[index] if index == 0 else box.merge(bounds[index])
		_center = box.get_center()
		_radius = maxf(.5,box.size.length()*.5)
	renderer.free()
	_yaw = .65
	_pitch = .30
	_zoom = 1.0
	var ship: Dictionary = GameData.get_ship(id)
	var capacity: String = "Десант: 60 бойцов · 6 орудий" if id == "ship_combat_cutter" else "Трюм: %d" % int(ship.get("cargo_capacity",0))
	_details.text = "%s · %s\n%s · Скорость: %d · Корпус: %d · Экипаж: %d–%d · Ранг: %d" % [str(ship.get("name",id)),str(ship.get("role","")),capacity,int(ship.get("base_speed",0)),int(ship.get("hull_max",100)),int(ship.get("min_crew",1)),int(ship.get("max_crew",1)),int(ship.get("command_rank_required",1))]
	if _model == null: _details.text += "\nМодель этого корабля пока недоступна."
	if bool(ship.get("premium",false)): _details.text += "\nОсобый корабль: осмотр доступен, покупка определяется предложениями игры."

func _collect_bounds(node: Node, result: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh != null: result.append(node.global_transform*node.get_aabb())
	for child in node.get_children(): _collect_bounds(child,result)

func _process(_delta: float) -> void:
	if not _is_open: return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(1040,screen.x-32),minf(760,screen.y-32))
	_panel.position = (screen-_panel.size)*.5
	var aspect: float = maxf(.3,_surface.size.x/maxf(1,_surface.size.y))
	var angle: float = atan(tan(deg_to_rad(_camera.fov)*.5)*minf(1.0,aspect))
	var distance: float = _radius/sin(angle)*_zoom
	_camera.position = _center+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*distance
	_camera.look_at(_center)

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_LEFT|MOUSE_BUTTON_MASK_RIGHT)):
		_yaw -= event.relative.x*.008
		_pitch = clampf(_pitch+event.relative.y*.006,-.25,1.2)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _zoom = maxf(.6,_zoom*.9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _zoom = minf(2.0,_zoom*1.1)
		if event.double_click: _yaw=.65; _pitch=.30; _zoom=1.0
	_surface.accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	_is_open = false
	_root.hide()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
