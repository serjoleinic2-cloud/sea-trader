extends "res://tests/test_base.gd"

var clans: Node
var progress: Node
var shop: Node

func before_each() -> void:
	GameState.reset_to_defaults(); SaveSystem.delete_save()
	GameState.player_state.origin_race_id = "humans"
	GameState.world_state.home_port_id = "home"
	GameState.player_state.money = 100000.0
	clans = preload("res://systems/social/clan_system.gd").new()
	clans.test_now = 1700000000; add_child(clans)
	progress = preload("res://systems/social/company_progression.gd").new()
	progress.test_now = 1700000000; add_child(progress)
	shop = preload("res://systems/social/company_shop.gd").new(); add_child(shop)

func after_each() -> void:
	shop.free(); progress.free(); clans.free()
	SaveSystem.delete_save(); GameState.reset_to_defaults()

func _create() -> void:
	assert_true(clans.perform("create", {"name": "Морские странники"}).ok)

func _row(id: String) -> Dictionary:
	for row in progress.expeditions():
		if str(row.id) == id and int(row.week) == progress.week(): return row
	return {}

func _deliver(count: int = 3) -> void:
	GameState.player_state.stats.total_deliveries += count
	progress.sample()

func test_progress_starts_from_current_stats_and_claims_once() -> void:
	GameState.player_state.stats.total_deliveries = 500
	progress.personal().last_stats = progress._stats()
	_create()
	assert_eq(float(_row("caravan").progress), 0.0)
	_deliver()
	assert_true(_row("caravan").complete)
	var args: Dictionary = {"id": "caravan", "week": progress.week()}
	var before: float = float(GameState.player_state.money)
	assert_true(progress.perform("expedition", args).ok)
	assert_eq(float(GameState.player_state.money), before + 180)
	assert_eq(int(clans.clan().base.expedition_resource), 90)
	assert_false(progress.perform("expedition", args).ok)
	assert_eq(int(clans.clan().base.expedition_resource), 90)
	assert_eq(int(progress.personal().season_points), 25)
	progress.sample(); assert_eq(int(progress.personal().season_points), 25)

func test_harbor_permissions_prices_and_visible_levels() -> void:
	_create(); _deliver()
	progress.perform("expedition", {"id": "caravan", "week": progress.week()})
	assert_true(progress.perform("harbor", {"id": "beacon"}).ok)
	assert_eq(int(clans.clan().base.modules.beacon), 1)
	assert_eq(int(clans.clan().base.expedition_resource), 0)
	assert_false(progress.perform("harbor", {"id": "beacon"}).ok)
	clans.clan().base.expedition_resource = 1000
	clans.clan().members[clans.local_id()].role = "member"
	assert_false(progress.perform("harbor", {"id": "beacon"}).ok)
	clans.clan().members[clans.local_id()].role = "leader"
	assert_true(progress.perform("harbor", {"id": "beacon"}).ok)
	assert_true(progress.perform("harbor", {"id": "beacon"}).ok)
	assert_false(progress.perform("harbor", {"id": "beacon"}).ok)
	assert_eq(int(clans.clan().base.modules.beacon), 3)

func test_season_free_paid_claims_and_expiration_retain_collection() -> void:
	_deliver()
	assert_eq(int(progress.season().points), 25)
	assert_true(progress.perform("season", {"index": 0}).ok)
	assert_false(progress.perform("season", {"index": 0}).ok)
	assert_false(progress.perform("season", {"index": 0, "premium": true}).ok)
	assert_true(shop.purchase("empire_collection").ok)
	assert_false(shop.purchase("empire_collection").ok)
	assert_true(progress.perform("season", {"index": 0, "premium": true}).ok)
	assert_true(progress.personal().owned_styles.has("sail_abyss"))
	assert_false(progress.perform("season", {"index": 4, "premium": true}).ok)
	progress.test_now += 43 * 86400
	_deliver(3)
	assert_eq(int(progress.season().points), 25)
	assert_true(progress.perform("season", {"index": 1, "premium": true}).ok)
	assert_true(progress.personal().owned_styles.has("hull_abyss"))
	assert_true(progress.perform("equip", {"id": "sail_abyss"}).ok)
	assert_eq(str(progress.personal().equipped.sail), "sail_abyss")
	assert_false(progress.perform("equip", {"id": "sail_imperial"}).ok)
	assert_true(progress.perform("unequip", {"id": "sail_abyss"}).ok)
	assert_true(progress.personal().owned_styles.has("sail_abyss"))

func test_shop_partial_bundle_receipts_and_no_rare_shards() -> void:
	GameState.combat_state.magic_shards = 500
	assert_true(shop.purchase("night_sails").ok)
	assert_false(shop.purchase("night_sails").ok)
	assert_eq(float(shop.quote("voyager_style_set").price), 4000.0)
	assert_true(shop.purchase("voyager_style_set").ok)
	assert_false(shop.purchase("voyager_style_set").ok)
	assert_true(shop.apply_product("voyager_style_set").ok)
	assert_eq(str(progress.personal().equipped.sail), "sail_night")
	assert_eq(str(progress.personal().equipped.hull), "hull_copper")
	assert_eq(int(GameState.combat_state.magic_shards), 500)
	assert_eq(GameState.company_state.purchase_receipts.size(), 2)
	assert_false(shop.payment_status().enabled)
	assert_true(SaveSystem.load_game())
	assert_true(progress.personal().owned_styles.has("hull_copper"))
	assert_eq(GameState.company_state.purchase_receipts.size(), 2)

func test_week_rollover_keeps_unclaimed_rewards_and_blocks_clock_rollback() -> void:
	_create(); _deliver()
	var previous: int = progress.week()
	progress.test_now += 7 * 86400; clans.test_now = progress.test_now
	assert_false(_row("caravan").complete)
	assert_true(progress.perform("expedition", {"id": "caravan", "week": previous}).ok)
	_deliver()
	assert_eq(int(progress.season().points), 50)
	progress.test_now -= 7 * 86400
	assert_eq(progress.week(), previous + 1)
	assert_false(progress.perform("expedition", {"id": "caravan", "week": previous}).ok)

func test_visual_only_changes_restore_materials_and_keep_hero_identity() -> void:
	var root := Node3D.new(); add_child(root)
	var mesh := MeshInstance3D.new(); mesh.mesh = BoxMesh.new()
	var source := StandardMaterial3D.new(); source.resource_name = "Hull"
	source.albedo_color = Color("664422")
	mesh.mesh.material = source; root.add_child(mesh)
	var before_ship: Dictionary = GameState.ship_state.duplicate(true)
	preload("res://systems/rendering/company_appearance.gd").apply(root, ["hull_copper"])
	assert_true(mesh.get_surface_override_material(0) != null)
	assert_eq(GameState.ship_state, before_ship)
	assert_eq(source.albedo_color, Color("664422"))
	preload("res://systems/rendering/company_appearance.gd").apply(root, [])
	assert_true(mesh.get_surface_override_material(0) == null)
	root.free()

func test_five_local_players_help_the_clan_without_spending_or_faking_personal_progress() -> void:
	_create()
	assert_eq(clans.seed_test_members(5), 5)
	assert_eq(clans.seed_test_members(5), 0)
	assert_eq(clans.clan().members.size(), 6)
	for id in clans.clan().members:
		assert_eq(str(clans.profile(str(id)).race_id), "humans")
	var money: float = float(GameState.player_state.money)
	assert_true(progress.perform("simulate_test_voyages").ok)
	var resource: int = int(clans.clan().base.expedition_resource)
	assert_eq(resource, 430)
	assert_eq(float(GameState.player_state.money), money)
	assert_eq(int(progress.personal().season_points), 0)
	assert_true(progress.perform("simulate_test_voyages").ok)
	assert_eq(int(clans.clan().base.expedition_resource), resource)
	assert_false(_row("caravan").eligible)
	_deliver()
	assert_true(_row("caravan").eligible)
	assert_true(progress.perform("expedition", {"id": "caravan", "week": progress.week()}).ok)
	assert_eq(int(clans.clan().base.expedition_resource), resource)
	assert_eq(float(GameState.player_state.money), money + 180)
