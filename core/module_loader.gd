extends RefCounted

## Scene-owned module lifecycle. Instances are not persisted; their state lives in GameState.
var services: Dictionary = {}
var _ordered: Array = []
var _scripts: Dictionary = {}

func plan(definitions: Array, externals: Array = ["$ship", "$ports", "$main"]) -> Dictionary:
	var pending: Array = definitions.duplicate(true)
	var ids: Dictionary = {}
	var ordered: Array = []
	for entry in pending:
		if not entry is Dictionary or str(entry.get("id", "")) == "":
			return _failure("Module must have an ID")
		var id: String = str(entry.id)
		if ids.has(id) or id.begins_with("$"):
			return _failure("Duplicate or reserved module ID: " + id)
		if not entry.get("args", []) is Array or not entry.get("after", []) is Array:
			return _failure(id + ": args/after must be arrays")
		ids[id] = true
	var available: Array = externals.duplicate()
	while not pending.is_empty():
		var progressed: bool = false
		for entry in pending.duplicate():
			var ready: bool = true
			var dependencies: Array = entry.get("args", []) + entry.get("after", [])
			for dependency in dependencies:
				if not ids.has(dependency) and not externals.has(dependency):
					return _failure(str(entry.id) + ": unknown dependency " + str(dependency))
				if not available.has(dependency):
					ready = false
			if ready:
				ordered.append(entry)
				available.append(str(entry.id))
				pending.erase(entry)
				progressed = true
		if not progressed:
			return _failure("Cyclic module dependencies")
	return {"ok": true, "ordered": ordered}

func prepare(definitions: Array) -> Dictionary:
	var result: Dictionary = plan(definitions)
	if not result.ok:
		return result
	_scripts.clear()
	_ordered = result.ordered
	for entry in _ordered:
		var path: String = str(entry.get("script", ""))
		if not path.begins_with("res://systems/") or not ResourceLoader.exists(path):
			return _failure(str(entry.id) + ": script not found: " + path)
		var script: Script = load(path)
		if script == null or not script.can_instantiate() or not ClassDB.is_parent_class(script.get_instance_base_type(), "Node"):
			return _failure(str(entry.id) + ": expected valid Node script")
		var method: String = str(entry.get("initialize", ""))
		if method != "":
			var found: bool = false
			for info in script.get_script_method_list():
				if str(info.name) == method:
					var count: int = entry.get("args", []).size()
					found = count <= info.args.size() and count >= info.args.size() - info.default_args.size()
			if not found:
				return _failure(str(entry.id) + ": initialization signature does not match manifest")
		elif not entry.get("args", []).is_empty():
			return _failure(str(entry.id) + ": args require initialize method")
		_scripts[str(entry.id)] = script
	return {"ok": true}

func start(parent: Node, externals: Dictionary) -> void:
	services.clear()
	for entry in _ordered:
		var id: String = str(entry.id)
		var instance: Node = _scripts[id].new()
		instance.name = id
		if entry.has("workspace_flag"):
			instance.set_meta("workspace_flag", str(entry.workspace_flag))
		if entry.has("navigation"):
			instance.set_meta("navigation", entry.navigation)
		parent.add_child(instance)
		services[id] = instance
		if entry.has("bind"):
			parent.set(str(entry.bind), instance)
		var args: Array = []
		for dependency in entry.get("args", []):
			args.append(externals[dependency] if externals.has(dependency) else services[dependency])
		if str(entry.get("initialize", "")) != "":
			instance.callv(str(entry.initialize), args)

func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
