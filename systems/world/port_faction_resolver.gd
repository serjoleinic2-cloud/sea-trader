extends RefCounted

## Prefer explicit ownership; legacy generated ports receive a stable visual identity.
func resolve(port: Dictionary, seed: int) -> String:
	var saved: Dictionary = GameState.port_state.get(str(port.get("id", "")), {})
	for source in [saved, port]:
		for key in ["owner_race_id", "faction_id"]:
			var identity: String = str(source.get(key, ""))
			if not GameData.get_faction(identity).is_empty():
				return identity
	var factions: Array = GameData.get_factions()
	if factions.is_empty():
		return "humans"
	var index: int = posmod(hash("%d:%s" % [seed, str(port.get("id", ""))]), factions.size())
	return str(factions[index].id)
