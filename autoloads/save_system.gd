extends Node

## Local filesystem save/load with versioning, backup, migration.
## See ARCHITECTURE.md and SYSTEM_MAP.md.
## All file I/O goes through this autoload only.

const SAVE_DIR := "user://saves/"
const SAVE_MAIN := "save_main.json"
const SAVE_BACKUP := "save_backup.json"
const SAVE_META := "save_meta.json"
const CURRENT_SAVE_VERSION := "0.2.1"
# The released generator before versioned saves used config version 1.
const LEGACY_WORLD_GEN_VERSION := "1"

# ============================================================================
# Public API
# ============================================================================

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_DIR + SAVE_MAIN) or FileAccess.file_exists(SAVE_DIR + SAVE_BACKUP)


func save_game() -> bool:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("SaveSystem: Cannot access user://")
		return false

	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

	# Build save data
	GameState.world_state.last_session_timestamp = int(Time.get_unix_time_from_system())
	var save_data: Dictionary = _serialize_game_state()
	var meta: Dictionary = {
		"version": CURRENT_SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"checksum": ""  # TODO: implement checksum when gameplay requires integrity
	}

	# Backup existing save
	if _valid_save(_read_json(SAVE_DIR + SAVE_MAIN)):
		_copy_file(SAVE_DIR + SAVE_MAIN, SAVE_DIR + SAVE_BACKUP)
		_copy_file(SAVE_DIR + SAVE_META, SAVE_DIR + SAVE_META + ".bak")

	# Write new save
	var main_file: FileAccess = FileAccess.open(SAVE_DIR + SAVE_MAIN, FileAccess.WRITE)
	if main_file == null:
		push_error("SaveSystem: Cannot write save_main.json")
		return false
	main_file.store_string(JSON.stringify(save_data, "\t"))
	main_file.flush()
	var main_error: Error = main_file.get_error()
	main_file.close()
	if main_error != OK:
		push_error("SaveSystem: Failed writing save data.")
		return false

	# Write meta
	var meta_file: FileAccess = FileAccess.open(SAVE_DIR + SAVE_META, FileAccess.WRITE)
	if meta_file == null:
		push_error("SaveSystem: Cannot write save_meta.json")
		return false
	meta_file.store_string(JSON.stringify(meta, "\t"))
	meta_file.flush()
	var meta_error: Error = meta_file.get_error()
	meta_file.close()
	if meta_error != OK:
		push_error("SaveSystem: Failed writing save metadata.")
		return false

	EventBus.game_saved.emit()
	return true


func load_game() -> bool:
	if not has_save():
		push_warning("SaveSystem: No save file found.")
		return false

	# Try main save
	var main_data: Dictionary = _read_json(SAVE_DIR + SAVE_MAIN)
	if not _valid_save(main_data):
		push_warning("SaveSystem: Main save corrupt. Trying backup.")
		main_data = _read_json(SAVE_DIR + SAVE_BACKUP)
		if not _valid_save(main_data):
			push_error("SaveSystem: Both main and backup saves are corrupt.")
			return false

	# Read meta
	var meta: Dictionary = _read_json(SAVE_DIR + SAVE_META)
	var save_version: String = str(main_data.get("version", meta.get("version", "0.0.0")))

	# Migrate if needed
	if save_version != CURRENT_SAVE_VERSION:
		main_data = _migrate(main_data, save_version, CURRENT_SAVE_VERSION)
		if main_data.is_empty():
			push_error("SaveSystem: Migration failed.")
			return false

	_deserialize_game_state(main_data)

	# Offline progress stub
	var last_ts: int = int(GameState.world_state.get("last_session_timestamp", 0))
	var now: int = int(Time.get_unix_time_from_system())
	var delta: int = now - last_ts
	if delta > 0:
		EventBus.offline_progress_applied.emit(delta)

	EventBus.game_loaded.emit()
	return true


func delete_save() -> void:
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir:
		dir.remove(SAVE_MAIN)
		dir.remove(SAVE_BACKUP)
		dir.remove(SAVE_META)
		dir.remove(SAVE_META + ".bak")


# ============================================================================
# Serialization
# ============================================================================

func _serialize_game_state() -> Dictionary:
	return {
		"version": CURRENT_SAVE_VERSION,
		"player_state": GameState.player_state.duplicate(true),
		"world_state": _serialize_vector_dict(GameState.world_state.duplicate(true)),
		"ship_state": _serialize_vector_dict(GameState.ship_state.duplicate(true)),
		"port_state": GameState.port_state.duplicate(true),
		"known_routes_state": GameState.known_routes_state.duplicate(true),
		"voyage_state": GameState.voyage_state.duplicate(true),
		"economy_state": GameState.economy_state.duplicate(true),
		"company_state": GameState.company_state.duplicate(true),
		"employee_state": GameState.employee_state.duplicate(true),
		"fleet_state": GameState.fleet_state.duplicate(true),
		"progression_state": GameState.progression_state.duplicate(true),
		"achievement_state": GameState.achievement_state.duplicate(true),
		"settings_state": GameState.settings_state.duplicate(true),
		"monetization_state": GameState.monetization_state.duplicate(true)
	}


func _deserialize_game_state(data: Dictionary) -> void:
	GameState.reset_to_defaults()
	GameState.player_state.merge(data.get("player_state", {}).duplicate(true), true)
	GameState.world_state.merge(_deserialize_vector_dict(data.get("world_state", {})), true)
	GameState.world_state.seed = int(GameState.world_state.seed)
	GameState.ship_state.merge(_deserialize_vector_dict(data.get("ship_state", {})), true)
	GameState.port_state = data.get("port_state", {}).duplicate(true)
	GameState.known_routes_state = data.get("known_routes_state", {}).duplicate(true)
	GameState.voyage_state.merge(data.get("voyage_state", {}).duplicate(true), true)
	GameState.economy_state.merge(data.get("economy_state", {}).duplicate(true), true)
	GameState.company_state.merge(data.get("company_state", {}).duplicate(true), true)
	GameState.employee_state = data.get("employee_state", []).duplicate(true)
	GameState.fleet_state = data.get("fleet_state", []).duplicate(true)
	GameState.progression_state.merge(data.get("progression_state", {}).duplicate(true), true)
	GameState.achievement_state.merge(data.get("achievement_state", {}).duplicate(true), true)
	GameState.settings_state.merge(data.get("settings_state", {}).duplicate(true), true)
	GameState.monetization_state.merge(data.get("monetization_state", {}).duplicate(true), true)


# Vector2 helpers — JSON does not natively support Vector2
func _serialize_vector_dict(dict: Dictionary) -> Dictionary:
	var result: Dictionary = dict.duplicate(true)
	for key in result.keys():
		var value = result[key]
		if value is Vector2:
			result[key] = {"__type": "Vector2", "x": value.x, "y": value.y}
		elif value is Dictionary:
			result[key] = _serialize_vector_dict(value)
		elif value is Array:
			result[key] = _serialize_vector_array(value)
	return result


func _serialize_vector_array(arr: Array) -> Array:
	var result: Array = arr.duplicate(true)
	for i in range(result.size()):
		var value = result[i]
		if value is Vector2:
			result[i] = {"__type": "Vector2", "x": value.x, "y": value.y}
		elif value is Dictionary:
			result[i] = _serialize_vector_dict(value)
		elif value is Array:
			result[i] = _serialize_vector_array(value)
	return result


func _deserialize_vector_dict(dict: Dictionary) -> Dictionary:
	var result: Dictionary = dict.duplicate(true)
	for key in result.keys():
		var value = result[key]
		if value is Dictionary and value.get("__type") == "Vector2":
			result[key] = Vector2(value.get("x", 0.0), value.get("y", 0.0))
		elif value is Dictionary:
			result[key] = _deserialize_vector_dict(value)
		elif value is Array:
			result[key] = _deserialize_vector_array(value)
	return result


func _deserialize_vector_array(arr: Array) -> Array:
	var result: Array = arr.duplicate(true)
	for i in range(result.size()):
		var value = result[i]
		if value is Dictionary and value.get("__type") == "Vector2":
			result[i] = Vector2(value.get("x", 0.0), value.get("y", 0.0))
		elif value is Dictionary:
			result[i] = _deserialize_vector_dict(value)
		elif value is Array:
			result[i] = _deserialize_vector_array(value)
	return result


# ============================================================================
# Helpers
# ============================================================================

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _write_json(path: String, data: Dictionary) -> bool:
	# Also used by isolated tests to construct old/corrupt save fixtures.
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


func _copy_file(from: String, to: String) -> void:
	if not FileAccess.file_exists(from):
		return
	var src: FileAccess = FileAccess.open(from, FileAccess.READ)
	if src == null:
		return
	var dst: FileAccess = FileAccess.open(to, FileAccess.WRITE)
	if dst == null:
		src.close()
		return
	dst.store_string(src.get_as_text())
	src.close()
	dst.close()


# ============================================================================
# Migration
# ============================================================================

func _migrate(data: Dictionary, from_version: String, to_version: String) -> Dictionary:
	if from_version not in ["0.0.0", "0.1.0", "0.2.0"] or to_version != CURRENT_SAVE_VERSION:
		push_warning("SaveSystem: Unsupported save version %s. Save was not reset." % from_version)
		return {}
	var migrated: Dictionary = data.duplicate(true)
	if from_version == "0.2.0":
		# The additive docking field is supplied by GameState defaults on load.
		migrated["version"] = to_version
		return migrated
	var world: Dictionary = migrated["world_state"]
	if str(world.get("world_gen_version", "")) == "":
		world["world_gen_version"] = LEGACY_WORLD_GEN_VERSION
	migrated["known_routes_state"] = migrated.get("known_routes_state", {})
	migrated["voyage_state"] = migrated.get("voyage_state", GameState.default_voyage_state())
	var player: Dictionary = migrated.get("player_state", {})
	var discovered: Array = player.get("discovered_port_ids", []).duplicate()
	for port_id in migrated.get("port_state", {}):
		var port: Dictionary = migrated.port_state[port_id]
		if port.get("discovered", false) and not discovered.has(port_id):
			discovered.append(port_id)
		# Strip only generated metadata; retain all saved progression fields.
		for key in ["id", "name", "x", "y", "position", "region", "island_id", "discovery_radius"]:
			port.erase(key)
	player["discovered_port_ids"] = discovered
	migrated["player_state"] = player
	migrated["version"] = to_version
	return migrated


func _valid_save(data: Dictionary) -> bool:
	var world: Variant = data.get("world_state")
	if not world is Dictionary or not world.has("seed"):
		return false
	if not (world.seed is int or world.seed is float):
		return false
	if world.seed != int(world.seed):
		return false
	for key in ["player_state", "ship_state", "port_state", "known_routes_state", "voyage_state",
		"economy_state", "company_state", "progression_state", "achievement_state", "settings_state", "monetization_state"]:
		if data.has(key) and not data[key] is Dictionary:
			return false
	for key in ["employee_state", "fleet_state"]:
		if data.has(key) and not data[key] is Array:
			return false
	for port in data.get("port_state", {}).values():
		if not port is Dictionary:
			return false
	if not data.get("player_state", {}).get("discovered_port_ids", []) is Array:
		return false
	if not data.get("ship_state", {}).get("docked_port_id", "") is String:
		return false
	return true
