extends CanvasLayer

## Docked town screen: terrain, constructed buildings and upgrade additions are separate.
## All actions delegate to existing port/building systems; no economy lives in this view.
const BUILDINGS: Array[String] = ["dock", "warehouse", "workshop", "market", "shipyard", "timber_yard", "fishing_wharf", "mage_guild", "captain_house", "barracks"]
const NAMES: Array[String] = ["Причал", "Склад", "Мастерская", "Рынок", "Верфь", "Лесопилка", "Рыбный промысел", "Гильдия магов", "Дом капитанов", "Казармы"]
const BUILDING_ART_OVERRIDES: Dictionary = {
	"crystari": {"barracks": "res://assets/ui/ports/crystari/barracks_harbor.png"},
}
## Authored hotspots on the docked home-port illustration. Keep these separate
## from the 3D showcase manifest: this is the live construction screen.
# Captain's House aligns with the fishing wharf, raised 264 authored pixels.
# Barracks aligns vertically with the Mage Guild, shifted right 358 authored pixels.
const SITES: Array[Vector2] = [Vector2(.81,.79), Vector2(.40,.57), Vector2(.6327,.5448), Vector2(.20,.37), Vector2(.865,.575), Vector2(.41,.37), Vector2(.18,.745), Vector2(.61,.3425), Vector2(.18,.52), Vector2(.8344,.3425)]
var _main: Node
var _root: Control
var _art: Control
var _background: TextureRect
var _title: Label
var _hint: Label
var _footer: HBoxContainer
var _emblem: TextureRect
var _sites: Array[Dictionary] = []
var _active_port: String = ""
var _race: String = ""
var _signature: String = ""
var _construction: bool = false
var _home: bool = false
var _build_button: Button
var _refresh_time: float = 0.0
var _click_mask_cache: Dictionary = {}
var _last_layout_viewport: Vector2 = Vector2.ZERO
var _last_layout_top: float = -1.0

func initialize(main: Node) -> void:
	_main = main
	layer = 15
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.clip_contents = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color("061c25")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	_art = Control.new()
	_root.add_child(_art)
	_background = TextureRect.new()
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.add_child(_background)
	for index in range(BUILDINGS.size()):
		var container := Control.new()
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.add_child(container)
		var annex := _sprite(container)
		var tower := _sprite(container)
		var sprite := TextureButton.new()
		sprite.ignore_texture_size = true
		sprite.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sprite.pressed.connect(_activate.bind(index))
		sprite.mouse_entered.connect(_hover.bind(index, true))
		sprite.mouse_exited.connect(_hover.bind(index, false))
		container.add_child(sprite)
		var scaffold := _sprite(container)
		var plot := Button.new()
		plot.text = "+"
		plot.custom_minimum_size = Vector2(36,32)
		plot.pressed.connect(_activate.bind(index))
		plot.tooltip_text = "Построить: " + NAMES[index]
		container.add_child(plot)
		var progress := ProgressBar.new()
		progress.max_value = 100.0
		progress.show_percentage = true
		progress.custom_minimum_size = Vector2(100,18)
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress.z_index = 10
		container.add_child(progress)
		_sites.append({"container":container,"sprite":sprite,"annex":annex,"tower":tower,"scaffold":scaffold,"plot":plot,"progress":progress})
	# Foreground buildings and their upgrades share the same drawing/click order.
	for building_id in ["warehouse", "workshop"]:
		_art.move_child(_sites[BUILDINGS.find(building_id)].container, -1)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 23)
	_title.add_theme_color_override("font_outline_color", Color("092430"))
	_title.add_theme_constant_override("outline_size", 7)
	_root.add_child(_title)
	_emblem = TextureRect.new()
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_emblem)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color", Color("092430"))
	_hint.add_theme_constant_override("outline_size", 5)
	_root.add_child(_hint)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 10)
	_root.add_child(_footer)
	_build_button = _button("Строительство", func(): _construction = not _construction; _signature = "")
	_button("Управление", func(): _open_section("management"))
	_button("Торговля", func(): _open_section("market"))
	_button("Выйти в море · E", func(): _main.get_node("PortSystem").undock())
	_root.theme = load("res://systems/ui/game_ui_theme.gd").new().get_theme()
	visible = false

func _sprite(parent: Control) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sprite)
	return sprite

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 42)
	button.pressed.connect(action)
	_footer.add_child(button)
	return button

func _process(delta: float) -> void:
	if _main == null: return
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	visible = port_id != ""
	if not visible:
		_active_port = ""
		return
	if port_id != _active_port:
		_active_port = port_id
		_home = port_id == str(GameState.world_state.get("home_port_id", ""))
		var port: Dictionary = _main.get_node("PortSystem").get("_world_ports").get(port_id, {})
		_race = str(GameState.player_state.get("origin_race_id", "humans")) if _home else load("res://systems/world/port_faction_resolver.gd").new().resolve(port, int(GameState.world_state.get("seed", 0)))
		if GameData.get_faction(_race).is_empty(): _race = "humans"
		_background.texture = load("res://assets/ui/ports/buildable_landscape.png" if _home else "res://assets/ui/ports/%s/panorama.png" % _race)
		_emblem.texture = load(str(GameData.get_faction(_race).get("emblem", "res://assets/ui/emblems/humans.png")))
		_title.text = str(_main.get_node("PortSystem").get_port_name(port_id))
		_signature = ""
		_construction = false
		_refresh_sprites()
		_layout()
	else:
		var screen: Vector2 = get_viewport().get_visible_rect().size
		var coordinator: Node = _main.get_node("WindowCoordinator")
		var top: float = float(coordinator.get("_top_height")) + 5.0
		if screen != _last_layout_viewport or not is_equal_approx(top, _last_layout_top):
			_layout()
	_refresh_time += delta
	if _refresh_time > 0.2 or _signature == "":
		_refresh_time = 0.0
		_refresh_buildings()

func _layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var coordinator: Node = _main.get_node("WindowCoordinator")
	var top: float = float(coordinator.get("_top_height")) + 5
	var available := Vector2(screen.x, maxf(200, screen.y - top - 68))
	# Cover the viewport instead of letterboxing the port illustration with wide
	# empty side bands. Keep the authored hotspots in the same scaled coordinate space.
	var factor: float = maxf(available.x / 1672.0, available.y / 941.0)
	_art.size = Vector2(1672,941) * factor
	_art.position = Vector2((screen.x-_art.size.x)*.5, top+(available.y-_art.size.y)*.5)
	_title.position = Vector2(78,top+12)
	_emblem.position = Vector2(20,top+8)
	_emblem.size = Vector2(48,48)
	for index in range(_sites.size()):
		var site: Dictionary = _sites[index]
		var size := Vector2(260,238) * factor
		site.container.size = size
		site.container.position = SITES[index] * _art.size - Vector2(size.x*.5,size.y*.86)
		site.annex.position = Vector2(size.x*.53,size.y*.38)
		site.annex.size = size * .58
		site.tower.position = Vector2(-size.x*.12,-size.y*.12)
		site.tower.size = size * .67
		site.scaffold.size = size
		site.plot.position = Vector2(size.x*.5-18,size.y*.78)
		site.progress.position = Vector2(size.x*.25,size.y*.86)
		site.progress.size = Vector2(size.x*.5,18.0*factor)
	_footer.reset_size()
	_footer.scale = Vector2.ONE * minf(1.0,(screen.x-20)/maxf(1,_footer.size.x))
	_footer.position = Vector2((screen.x-_footer.size.x*_footer.scale.x)*.5,screen.y-51)
	_hint.position = Vector2(0,screen.y-81)
	_hint.size.x = screen.x
	_last_layout_viewport = screen
	_last_layout_top = top

func _refresh_sprites() -> void:
	# Foreign-port panoramas have no clickable building overlays.
	# Avoid loading every building texture while docking at those ports.
	if not _home:
		return
	for index in range(_sites.size()):
		var site: Dictionary = _sites[index]
		var building_id: String = BUILDINGS[index]
		var path: String = "res://assets/ui/ports/%s/%s.png" % [_race, building_id]
		path = str(BUILDING_ART_OVERRIDES.get(_race, {}).get(building_id, path))
		site["sprite_path"] = path
		site.sprite.texture_normal = load(path) as Texture2D
		var level_material := ShaderMaterial.new()
		level_material.shader = load("res://assets/ui/ports/building_level_progression.gdshader") as Shader
		site.sprite.material = level_material
		site.sprite.texture_click_mask = _click_mask_cache.get(path) as BitMap
		site.annex.texture = load("res://assets/ui/ports/%s/annex.png" % _race)
		site.tower.texture = load("res://assets/ui/ports/%s/tower.png" % _race)
		site.scaffold.texture = load("res://assets/ui/ports/%s/scaffold.png" % _race)


func _ensure_click_mask(site: Dictionary) -> void:
	var path: String = str(site.get("sprite_path", ""))
	if path.is_empty():
		return
	var mask: BitMap = _click_mask_cache.get(path) as BitMap
	if mask == null:
		var texture: Texture2D = site.sprite.texture_normal as Texture2D
		if texture == null:
			return
		var image: Image = texture.get_image()
		if image == null or image.is_empty():
			return
		mask = BitMap.new()
		mask.create_from_image_alpha(image, 0.12)
		_click_mask_cache[path] = mask
	site.sprite.texture_click_mask = mask

func _refresh_buildings() -> void:
	var buildings: Dictionary = GameState.port_state.get(_active_port, {}).get("buildings", {})
	var projects: Array = GameState.company_state.get("building_projects", [])
	var signature: String = str(buildings) + str(_construction) + str(projects)
	if signature == _signature: return
	_signature = signature
	_build_button.visible = _home
	_build_button.text = "Готово" if _construction else "Строительство"
	_hint.text = "Выберите здание или свободную площадку" if _construction else "Наведите на здание · нажмите, чтобы открыть"
	for index in range(_sites.size()):
		var site: Dictionary = _sites[index]
		var building_id: String = BUILDINGS[index]
		var state: Dictionary = buildings.get(building_id, {})
		var level: int = int(state.get("level", 0))
		var built: bool = level > 0
		var material: ShaderMaterial = site.sprite.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("building_level", maxf(1.0, float(level)))
			material.set_shader_parameter("faction_accent", _faction_accent())
		# Foreign ports have an authored panorama; hotspots invoke real trade/encounter pages.
		site.container.visible = _home
		site.sprite.visible = built
		# Modular silhouette changes begin at tier boundaries. Faint early overlays
		# read as an unrelated building ghost behind the base artwork.
		site.annex.visible = built and level >= 11
		site.annex.modulate = Color.WHITE
		site.tower.visible = built and level >= 21
		site.tower.modulate = Color.WHITE
		var underway: bool = false
		for project in projects:
			if str(project.get("building_id", "")) == building_id and int(project.get("started_at_unix", 0)) > 0: underway = true
		site.scaffold.visible = underway
		site.progress.visible = underway
		if underway:
			var project_system: Node = _main.get_node_or_null("BuildingProjectSystem")
			for project in projects:
				if str(project.get("building_id", "")) != building_id or int(project.get("started_at_unix", 0)) <= 0:
					continue
				var duration: float = maxf(1.0, float(project.get("duration_sec", 1)))
				var remaining: int = int(project_system.get_project_time_left(project)) if project_system != null else int(duration)
				site.progress.value = clampf((1.0 - float(remaining) / duration) * 100.0, 0.0, 100.0)
				break
		site.plot.visible = not built and _construction
		site.sprite.tooltip_text = "%s · уровень %d\n%s" % [NAMES[index],level,"Улучшить" if _construction else "Открыть"]
		if _home and site.sprite.visible:
			_ensure_click_mask(site)

func _hover(index: int, entered: bool) -> void:
	_sites[index].sprite.modulate = Color(1.14,1.10,1.01) if entered else Color.WHITE
	if entered: _hint.text = _sites[index].sprite.tooltip_text.replace("\n"," · ")
	else: _hint.text = "Выберите здание или свободную площадку" if _construction else "Наведите на здание · нажмите, чтобы открыть"

func _activate(index: int) -> void:
	var building: String = BUILDINGS[index]
	var state: Dictionary = GameState.port_state.get(_active_port, {}).get("buildings", {}).get(building, {})
	if _construction:
		_main.get_node("PortWindow")._open_building_card(building)
		return
	if building == "barracks":
		_open_special_window("GarrisonWindow")
		return
	if int(state.get("level", 0)) == 0:
		_main.get_node("PortWindow")._open_building_card(building)
		return
	if building == "captain_house":
		_open_special_window("HiringWindow")
		return
	if building == "mage_guild":
		_open_special_window("MageGuildWindow")
		return
	var actions: Dictionary = {"dock":"service","warehouse":"resources","workshop":"service","market":"market","shipyard":"shipyard","timber_yard":"resources","fishing_wharf":"resources"}
	_open_section(str(actions.get(building,"construction")))

func _open_special_window(node_name: String) -> void:
	var window: Node = _main.get_node_or_null(node_name)
	if window == null or not window.has_method("open"):
		push_warning("Harbor building target is unavailable: %s" % node_name)
		return
	var coordinator: Node = _main.get_node("WindowCoordinator")
	coordinator._close_all_workspaces()
	coordinator.set("_port_expanded", false)
	coordinator.set("_details", "")
	window.call("open")

func _open_section(section: String) -> void:
	var coordinator: Node = _main.get_node("WindowCoordinator")
	coordinator._close_all_workspaces()
	coordinator.set("_details", "")
	coordinator.set("_port_expanded", true)
	_main.get_node("PortWindow")._open_section(section)

func _faction_accent() -> Color:
	match _race:
		"nerids": return Color("4bd9d2")
		"surr": return Color("ff784b")
		"meridians": return Color("ffe08a")
		"aery": return Color("a8efff")
		"crystari": return Color("c18aff")
	return Color("65caff")
