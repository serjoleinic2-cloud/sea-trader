extends RefCounted

## Shared, side-effect-free warehouse funding for building and ship projects.
var _economy = preload("res://systems/economy/economy_model.gd").new()

func quote(project: Dictionary, inventory: Dictionary, economy_state: Dictionary) -> Dictionary:
	var required: Dictionary = project.get("required_materials", {})
	var reserved: Dictionary = project.get("materials", {})
	var rows: Dictionary = {}
	var ready: bool = not required.is_empty()
	for resource_id in required:
		var needed: int = maxi(0, int(required[resource_id]))
		var committed: int = maxi(0, int(reserved.get(resource_id, 0)))
		var warehouse: int = maxi(0, int(inventory.get(resource_id, 0)) - _economy.reserved(economy_state, str(resource_id)))
		var available: int = warehouse + committed
		var missing: int = maxi(0, needed - available)
		rows[resource_id] = {"required": needed, "reserved": committed, "warehouse": warehouse, "available": available, "missing": missing}
		ready = ready and missing == 0
	return {"ready": ready, "rows": rows}

func reserve(project: Dictionary, inventory: Dictionary, economy_state: Dictionary) -> Dictionary:
	var status: Dictionary = quote(project, inventory, economy_state)
	if not bool(status.ready):
		return {"ok": false, "message": "На складе не хватает материалов."}
	var funded: Dictionary = project.duplicate(true)
	var remaining_stock: Dictionary = inventory.duplicate(true)
	var materials: Dictionary = funded.get("materials", {}).duplicate(true)
	for resource_id in status.rows:
		var row: Dictionary = status.rows[resource_id]
		var take: int = maxi(0, int(row.required) - int(row.reserved))
		remaining_stock[resource_id] = int(remaining_stock.get(resource_id, 0)) - take
		materials[resource_id] = int(row.required)
	funded["materials"] = materials
	return {"ok": true, "project": funded, "inventory": remaining_stock}
