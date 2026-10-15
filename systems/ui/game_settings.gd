extends RefCounted

## Apply persistent settings through existing rendering, sound and input services.
static func normalized(raw: Dictionary) -> Dictionary:
	var settings: Dictionary = raw.duplicate(true)
	settings["master_volume"] = clampf(float(raw.get("master_volume", 1.0)), 0.0, 1.0)
	settings["sfx_volume"] = clampf(float(raw.get("sfx_volume", 0.8)), 0.0, 1.0)
	settings["music_volume"] = clampf(float(raw.get("music_volume", 0.8)), 0.0, 1.0)
	settings["render_scale"] = clampf(float(raw.get("render_scale", 1.0)), 0.5, 1.0)
	var quality: String = str(raw.get("water_quality", "medium"))
	quality = {"simple": "low", "detailed": "high"}.get(quality, quality)
	settings["water_quality"] = quality if quality in ["low", "medium", "high"] else "medium"
	var distance: String = str(raw.get("view_distance", "medium"))
	settings["view_distance"] = distance if distance in ["near", "medium", "far"] else "medium"
	settings["antialiasing"] = bool(raw.get("antialiasing", true))
	settings["fullscreen"] = bool(raw.get("fullscreen", false))
	settings["vsync"] = bool(raw.get("vsync", true))
	settings["fps_limit"] = int(raw.get("fps_limit", 60)) if int(raw.get("fps_limit", 60)) in [0, 30, 60, 120] else 60
	settings["control_sensitivity"] = clampf(float(raw.get("control_sensitivity", 1.0)), 0.5, 2.0)
	settings["control_inversion"] = bool(raw.get("control_inversion", false))
	return settings

static func apply(tree: SceneTree, raw: Dictionary) -> void:
	var settings: Dictionary = normalized(raw)
	GameState.settings_state.merge(settings, true)
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for pair in [["Master", "master_volume"], ["SFX", "sfx_volume"], ["Music", "music_volume"]]:
		var bus: int = AudioServer.get_bus_index(str(pair[0]))
		var volume: float = float(settings[str(pair[1])])
		AudioServer.set_bus_mute(bus, volume <= 0.0001)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	var battle_bus: int = AudioServer.get_bus_index("NavalBattle")
	if battle_bus >= 0:
		AudioServer.set_bus_send(battle_bus, "SFX")
	Engine.max_fps = int(settings.fps_limit)
	if DisplayServer.get_name() != "headless":
		var wanted_mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
		var current_mode: int = DisplayServer.window_get_mode()
		if bool(settings.fullscreen) != (current_mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]):
			DisplayServer.window_set_mode(wanted_mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings.vsync) else DisplayServer.VSYNC_DISABLED)
	var renderer: Node = tree.root.find_child("Approach3DView", true, false)
	if renderer != null:
		renderer.apply_graphics_settings()
	var sensor: Node = tree.root.find_child("SensorInput", true, false)
	if sensor != null and sensor.has_method("_load_config"):
		sensor.call("_load_config")
	for accessibility in tree.get_nodes_in_group("ui_accessibility"):
		accessibility.set_scale(float(settings.get("ui_scale", 1.25)))

static func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
