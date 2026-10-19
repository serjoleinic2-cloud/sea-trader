extends RefCounted

static var _rules: Dictionary = {}

static func own_clan_id() -> String:
	var social: Dictionary = GameState.company_state.get("social", {})
	return str(social.get("profiles", {}).get(str(GameState.player_state.get("social_id", "")), {}).get("clan_id", ""))

static func own_clan() -> Dictionary:
	var own: Dictionary = GameState.company_state.get("social", {}).get("clans", {}).get(own_clan_id(), {})
	return own if own.get("members", {}).has(str(GameState.player_state.get("social_id", ""))) else {}

static func percent(stat: String, now: int = -1) -> float:
	if now < 0: now = int(Time.get_unix_time_from_system())
	var clan: Dictionary = own_clan()
	if int(clan.get("active_boosts", {}).get(stat, 0)) <= now: return 0.0
	if _rules.is_empty(): _rules = GameData.read("res://data/social/clan_rules.json")
	var spec: Dictionary = _rules.get("boosts", {}).get(stat, {})
	return clampf(float(spec.get("base_percent", 0)) + float(clan.get("boost_progress", {}).get(stat, 0)), 0.0, float(spec.get("cap_percent", 0)))

static func peace(first: String, second: String) -> bool:
	if first == "" or second == "": return false
	if first == second: return true
	var clans: Dictionary = GameState.company_state.get("social", {}).get("clans", {})
	return clans.has(first) and clans.has(second) and bool(clans[first].get("peace", {}).get(second, false)) and bool(clans[second].get("peace", {}).get(first, false))

static func tribute_suspended(port: Dictionary) -> bool:
	return peace(own_clan_id(), str(port.get("owner_clan_id", "")))
