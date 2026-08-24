extends Node

## Local filesystem save/load with versioning, backup, migration.
## See ARCHITECTURE.md and SYSTEM_MAP.md.
## All file I/O goes through this autoload only.

const SAVE_DIR := "user://saves/"
const SAVE_MAIN := "save_main.json"
const SAVE_BACKUP := "save_backup.json"
const SAVE_META := "save_meta.json"
const CURRENT_SAVE_VERSION := "0.1.0"

# ============================================================================
# Public API
# ============================================================================

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_DIR + SAVE_MAIN)


func save_game() -> bool:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("SaveSystem: Cannot access user://")
		return false

	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

	# Build save data
	var save_data: Dictionary = _serialize_game_state()
	var meta: Dictionary = {
		"version": CURRENT_SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"checksum": ""  # TODO: implement checksum when gameplay requires integrity
	}

	# Backup existing save
	if FileAccess.file_exists(SAVE_DIR + SAVE_MAIN):
		_copy_file(SAVE_DIR + SAVE_MAIN, SAVE_DIR + SAVE_BACKUP)
		_copy_file(SAVE_DIR + SAVE_META, SAVE_DIR + SAVE_META + ".bak")

	# Write new save
	var main_file: FileAccess = FileAccess.open(SAVE_DIR + SAVE_MAIN, FileAccess.WRITE)
	if main_file == null:
		push_error("SaveSystem: Cannot write save_main.json")
		return false
	main_file.store_string(JSON.stringify(save_data, "\t"))
	main_file.close()

	# Write meta
	var meta_file: FileAccess = FileAccess.open(SAVE_DIR + SAVE_META, FileAccess.WRITE)
	if meta_file == null:
		push_error("SaveSystem: Cannot write save_meta.json")
		return false
	meta_file.store_string(JSON.stringify(meta, "\t"))
	meta_file.close()

	# Update last session timestamp in state
	GameState.world_state.last_session_timestamp = Time.get_unix_time_from_system()

	EventBus.game_saved.emit()
	return true


func load_game() -> bool:
	if not has_save():
		push_warning("SaveSystem: No save file found.")
		return false

	# Try main save
	var main_data: Dictionary = _read_json(SAVE_DIR + SAVE_MAIN)
	if main_data.is_empty():
		push_warning("SaveSystem: Main save corrupt. Trying backup.")
		main_data = _read_json(SAVE_DIR + SAVE_BACKUP)
		if main_data.is_empty():
			push_error("SaveSystem: Both main and backup saves are corrupt.")
			return false

	# Read meta
	var meta: Dictionary = _read_json(SAVE_DIR + SAVE_META)
	var save_version: String = meta.get("version", "0.0.0") as String

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
	GameState.player_state = data.get("player_state", {}).duplicate(true)
	GameState.world_state = _deserialize_vector_dict(data.get("world_state", {}))
	GameState.ship_state = _deserialize_vector_dict(data.get("ship_state", {}))
	GameState.port_state = data.get("port_state", {}).duplicate(true)
	GameState.economy_state = data.get("economy_state", {}).duplicate(true)
	GameState.company_state = data.get("company_state", {}).duplicate(true)
	GameState.employee_state = data.get("employee_state", []).duplicate(true)
	GameState.fleet_state = data.get("fleet_state", []).duplicate(true)
	GameState.progression_state = data.get("progression_state", {}).duplicate(true)
	GameState.achievement_state = data.get("achievement_state", {}).duplicate(true)
	GameState.settings_state = data.get("settings_state", {}).duplicate(true)
	GameState.monetization_state = data.get("monetization_state", {}).duplicate(true)


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
	# TODO: Implement per-version migrations as phases progress.
	# For Phase 01, fallback to defaults if versions differ.
	push_warning("SaveSystem: Migration from %s to %s not implemented. Fallback to defaults." % [from_version, to_version])
	var old_settings: Dictionary = data.get("settings_state", {})
	GameState.reset_to_defaults()
	if not old_settings.is_empty():
		GameState.settings_state = old_settings.duplicate(true)
	return _serialize_game_state()
