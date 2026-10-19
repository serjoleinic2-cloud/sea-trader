extends "res://tests/test_base.gd"

const Bonuses = preload("res://systems/social/clan_bonuses.gd")
var clans: Node
var shop: Node
var founder: String

func before_each() -> void:
	GameState.reset_to_defaults()
	SaveSystem.delete_save()
	GameState.player_state.origin_race_id = "humans"
	GameState.player_state.money = 100000.0
	GameState.world_state.home_port_id = "home"
	clans = load("res://systems/social/clan_system.gd").new()
	add_child(clans)
	clans.test_now = 1700000000
	clans.ensure_state()
	founder = clans.local_id()
	shop = load("res://systems/social/company_shop.gd").new()
	add_child(shop)

func after_each() -> void:
	clans.free()
	shop.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func create(name: String = "Морская хартия") -> Dictionary:
	return clans.perform("create", {"name": name, "rules": "Помогаем своим капитанам."})

func person(id: String, race: String = "humans") -> void:
	clans.state().profiles[id] = {"id": id, "name": id, "race_id": race, "clan_id": "", "rank": 1, "join_after": 0, "last_week": -1, "last_active_at": clans.now()}

func switch_to(id: String) -> void:
	GameState.player_state.social_id = id
	GameState.player_state.origin_race_id = str(clans.profile(id).race_id)

func join(id: String, clan_id: String) -> void:
	switch_to(id)
	clans.perform("apply", {"clan_id": clan_id})
	switch_to(founder)
	clans.perform("review", {"player_id": id, "accept": true})

func test_creation_cost_validation_and_persistence() -> void:
	assert_false(clans.perform("create", {"name": "х у й"}).ok)
	assert_false(clans.perform("create", {"name": "fuck"}).ok)
	assert_eq(float(GameState.player_state.money), 100000.0)
	assert_true(create().ok)
	assert_eq(float(GameState.player_state.money), 95000.0)
	assert_eq(clans.role(), "leader")
	assert_eq(str(clans.clan().base.owner_id), founder)
	assert_false(create("Другой клан").ok)
	assert_true(SaveSystem.load_game())
	assert_eq(str(clans.clan().name), "Морская хартия")
	assert_eq(str(GameState.player_state.social_id), founder)

func test_membership_permissions_blacklist_and_cooldown() -> void:
	assert_true(create().ok)
	var id: String = str(clans.clan().id)
	person("recruit"); person("foreign", "nerids"); person("second")
	switch_to("foreign")
	assert_false(clans.perform("apply", {"clan_id": id}).ok)
	join("recruit", id)
	assert_eq(str(clans.profile("recruit").clan_id), id)
	assert_true(clans.perform("role", {"player_id": "recruit", "role": "recruiter"}).ok)
	switch_to("recruit")
	assert_false(clans.perform("boost", {"stat": "speed"}).ok)
	assert_false(clans.perform("rules", {"text": "новые"}).ok)
	assert_false(clans.perform("role", {"player_id": founder, "role": "member"}).ok)
	switch_to(founder)
	assert_true(clans.perform("blacklist", {"player_id": "recruit"}).ok)
	switch_to("recruit")
	clans.test_now += 86401
	assert_false(clans.perform("apply", {"clan_id": id}).ok)
	assert_false(clans.perform("friend_request", {"player_id": founder}).ok)
	switch_to(founder)
	assert_true(clans.perform("unblacklist", {"player_id": "recruit"}).ok)

func test_boost_caps_expiration_and_no_join_farming() -> void:
	assert_true(create().ok)
	var entry: Dictionary = clans.clan()
	var sum_before: float = 0.0
	for amount in entry.boost_progress.values(): sum_before += float(amount)
	assert_false(clans._contribute(clans.profile(), entry))
	var sum_after: float = 0.0
	for amount in entry.boost_progress.values(): sum_after += float(amount)
	assert_true(is_equal_approx(sum_before, sum_after))
	assert_true(clans.perform("boost", {"stat": "speed"}).ok)
	assert_false(clans.perform("boost", {"stat": "speed"}).ok)
	assert_true(clans.perform("boost", {"stat": "fuel"}).ok)
	assert_false(clans.perform("boost", {"stat": "sale"}).ok)
	for stat in clans.rules.boosts:
		entry.boost_progress[stat] = 999999.0
		entry.active_boosts[stat] = clans.now() + 86400
		assert_true(Bonuses.percent(str(stat), clans.now()) <= float(clans.rules.boosts[stat].cap_percent))
		assert_eq(Bonuses.percent(str(stat), clans.now() + 86400), 0.0)
	clans.test_now += 604800
	assert_true(clans._contribute(clans.profile(), entry))
	assert_false(clans._contribute(clans.profile(), entry))

func test_diplomacy_needs_both_leaders_and_blocks_tribute() -> void:
	assert_true(create().ok)
	var first: String = str(clans.clan().id)
	person("other", "nerids"); switch_to("other")
	assert_true(create("Приливный союз").ok)
	var second: String = str(clans.clan().id)
	switch_to(founder)
	assert_false(clans.perform("peace_accept", {"clan_id": second}).ok)
	assert_true(clans.perform("peace_offer", {"clan_id": second}).ok)
	assert_false(Bonuses.peace(first, second))
	switch_to("other")
	assert_true(clans.perform("peace_accept", {"clan_id": first}).ok)
	assert_true(Bonuses.peace(first, second))
	assert_true(Bonuses.tribute_suspended({"owner_clan_id": first}))
	assert_true(clans.perform("peace_break", {"clan_id": first}).ok)
	assert_false(Bonuses.peace(first, second))
	assert_false(Bonuses.peace("", ""))

func test_friends_require_consent_and_blocks_stop_messages() -> void:
	person("friend")
	assert_false(clans.perform("message", {"player_id": "friend", "text": "Привет"}).ok)
	assert_true(clans.perform("friend_request", {"player_id": "friend"}).ok)
	switch_to("friend")
	assert_true(clans.perform("friend_accept", {"player_id": founder}).ok)
	assert_true(clans.perform("message", {"player_id": founder, "text": "Привет, капитан"}).ok)
	assert_false(clans.perform("message", {"player_id": founder, "text": "Снова"}).ok)
	assert_eq(clans.private_messages(founder).size(), 1)
	assert_true(clans.perform("block", {"player_id": founder}).ok)
	assert_eq(clans.private_messages(founder).size(), 0)
	switch_to(founder)
	assert_false(clans.perform("message", {"player_id": "friend", "text": "Привет"}).ok)

func test_real_tribute_processor_skips_allied_ports_without_backpay() -> void:
	assert_true(create().ok)
	var first: String = str(clans.clan().id)
	person("ally", "nerids"); switch_to("ally")
	assert_true(create("Союз лагуны").ok)
	var second: String = str(clans.clan().id)
	switch_to(founder); clans.perform("peace_offer", {"clan_id": second})
	switch_to("ally"); clans.perform("peace_accept", {"clan_id": first})
	GameState.port_state["tax_port"] = {"tribute_active": true, "owner_clan_id": first, "tribute_last_tick": int(Time.get_unix_time_from_system()) - 3 * 86400, "tribute_daily_amount": 100, "tribute_revolt_at": 0}
	var combat: Node = load("res://systems/combat/combat_system.gd").new(); add_child(combat); combat.initialize()
	var before: float = float(GameState.player_state.money)
	combat._process_tribute_income()
	assert_eq(float(GameState.player_state.money), before)
	assert_true(int(GameState.port_state.tax_port.tribute_last_tick) > int(Time.get_unix_time_from_system()) - 10)
	clans.perform("peace_break", {"clan_id": first})
	combat._process_tribute_income()
	assert_eq(float(GameState.player_state.money), before)
	combat.free()

func test_shop_items_have_receipts_and_do_not_stack_premium_strength() -> void:
	assert_true(shop.purchase("voyage_scrolls").ok)
	assert_eq(int(GameState.economy_state.rewards.boosts.fair_wind), 2)
	assert_eq(float(GameState.player_state.money), 98960.0)
	assert_false(shop.purchase("ship_skin").ok)
	assert_false(shop.purchase("port_wing").ok)
	assert_true(shop.purchase("officer").ok)
	assert_false(shop.purchase("officer").ok)
	assert_eq(str(GameState.employee_state[0].race_id), "humans")
	assert_eq(str(GameState.employee_state[0].assigned_to), "")
	assert_true(create().ok)
	assert_true(shop.purchase("port_wing").ok)
	assert_eq(int(clans.clan().base.wings), 1)
	clans.clan().base.wings = 4
	assert_false(shop.purchase("port_wing").ok)
	assert_true(shop.purchase("premium_day").ok)
	var end: int = int(GameState.economy_state.rewards.premium_until)
	assert_true(shop.purchase("premium_day").ok)
	assert_eq(int(GameState.economy_state.rewards.premium_until), end + 86400)

func test_debris_positions_are_shared_sparse_and_never_inside_land() -> void:
	var catalog = load("res://systems/world/drift_debris_catalog.gd")
	var world: Dictionary = {"world_size": Vector2i(4096, 4096), "islands": [{"position": Vector2(2000, 2000), "radius": 400}], "ports": {}}
	var positions: Array = catalog.generate(world, 42, "")
	assert_eq(positions, catalog.generate(world, 42, ""))
	assert_true(positions.size() <= 22 and positions.size() >= 18)
	for entry in positions:
		assert_true(Vector2(entry.position).distance_to(Vector2(2000, 2000)) >= 550)
	world.islands[0].radius = 10000
	assert_true(catalog.generate(world, 42, "").is_empty())
