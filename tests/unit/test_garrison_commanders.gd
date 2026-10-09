extends "res://tests/test_base.gd"
var combat: Node
var window: Node
func before_each() -> void:
	SaveSystem.delete_save(); GameState.reset_to_defaults()
	GameState.player_state.origin_race_id="nerids"; GameState.player_state.money=50000.0
	GameState.world_state.seed=42; GameState.world_state.home_port_id="home"; GameState.ship_state.docked_port_id="home"
	GameState.port_state={"home":{"inventory":{}}}
	GameState.combat_state.units={"coast_guard":{"count":10,"level":1,"experience":0}}
	combat=preload("res://systems/combat/combat_system.gd").new(); add_child(combat); combat.initialize(); combat.set_process(false)
	window=preload("res://systems/ui/garrison_window.gd").new(); add_child(window); window.initialize(combat)
func after_each() -> void:
	window.free(); combat.free(); SaveSystem.delete_save(); GameState.reset_to_defaults()
func test_two_live_command_slots_changes_visible_army_and_save() -> void:
	window.open()
	var screen: Control = window._art_screen
	assert_eq(screen._slots.size(),2)
	assert_eq(screen._candidate_cards.size(),3)
	var base: float = combat.get_unit_command_effect("coast_guard").attack
	var power: int = combat.get_attack_power()
	assert_true(combat.hire_commander(window._commander_profile("nerids",0),0).ok)
	assert_true(combat.hire_commander(window._commander_profile("nerids",1),1).ok)
	assert_eq(combat.get_commander_bonuses().attack,9.0)
	assert_gt(combat.get_attack_power(),power)
	assert_gt(combat.get_unit_command_effect("coast_guard").attack,base)
	assert_eq(GameState.combat_state.units.coast_guard.count,10)
	screen.refresh(combat)
	assert_true(screen._groups[0].attack.text.contains("+9%"))
	assert_true(screen._slots[1].status.text.contains("Назначен"))
	assert_gt(float(screen._groups[0].attack_bar.value),30.0)
	assert_true(SaveSystem.load_game()); assert_false(combat.get_commander(1).is_empty())
	assert_false(combat.hire_commander(window._commander_profile("nerids",0),1).ok)
	assert_true(combat.dismiss_commander(1).ok); assert_eq(combat.get_commander_bonuses().attack,6.0)
func test_programmatic_layout_and_canonical_portraits_emblems() -> void:
	window.open()
	var screen: Control = window._art_screen
	assert_eq(screen.find_children("GarrisonArtScreen", "TextureRect",true,false).size(),0)
	assert_eq(screen._hero_emblem.texture,GameData.get_faction_emblem("nerids"))
	for offer in screen._candidate_offers[0]:
		assert_eq(offer.race_id,"nerids","recruiting cards are limited to the player's race")
		assert_true(offer.portrait.contains("/nerids/"),"candidate portrait comes from the player's race folder")
	assert_false(combat.hire_commander(window._commander_profile("surr",0),0).ok,"combat system rejects a different race")

func test_commander_and_deputy_offers_can_be_rerolled_with_distinct_atlas_portraits() -> void:
	window.open()
	var screen: Control = window._art_screen
	var first_order: Array = []
	for offer in screen._candidate_offers[0]: first_order.append(int(offer.portrait_variant))
	var first_id: String = str(screen._candidate_offers[0][0].id)
	assert_true(screen._hero.texture is Texture2D,"commander uses an independent portrait asset")
	assert_true(screen._hero_frame.position.x < screen._hero.position.x and screen._hero_frame.position.y < screen._hero.position.y,"gold portrait frame is visible around the complete image")
	assert_true(screen._hero_frame.position.x+screen._hero_frame.size.x >= screen._hero.position.x+screen._hero.size.x,"portrait frame covers the image's right edge")
	assert_true(screen._hero_frame.position.y+screen._hero_frame.size.y >= screen._hero_title.position.y+screen._hero_title.size.y,"portrait frame does not crop the candidate title")
	screen._candidate_cards[1].button.pressed.emit()
	assert_eq(screen._hero.texture.resource_path,screen._candidate_cards[1].portrait.texture.resource_path,"central portrait matches clicked candidate card")
	assert_eq(screen._hero_name.text,screen._candidate_cards[1].name.text,"central name matches clicked candidate card")
	screen._candidate_refresh.pressed.emit()
	assert_ne(screen._candidate_offers[0][0].id,first_id,"reroll creates a different commander offer")
	var second_order: Array = []
	for offer in screen._candidate_offers[0]: second_order.append(int(offer.portrait_variant))
	assert_ne(second_order,first_order,"reroll changes portrait order in the bottom candidate row")
	screen._role_buttons[1].pressed.emit()
	var deputy_id: String = str(screen._candidate_offers[1][0].id)
	assert_true(screen._hero.texture is Texture2D,"deputy uses an independent portrait asset")
	assert_ne(screen._candidate_offers[1][0].portrait_variant,screen._candidate_offers[0][0].portrait_variant,"commander and deputy portrait variants are independent")
	screen._candidate_refresh.pressed.emit()
	assert_ne(screen._candidate_offers[1][0].id,deputy_id,"deputy offer can be rerolled independently")

func test_every_visible_candidate_is_from_the_players_race() -> void:
	window.open()
	var screen: Control = window._art_screen
	for slot_index in [0,1]:
		screen._select_command_slot(slot_index)
		for offer in screen._candidate_offers[slot_index]:
			assert_eq(offer.race_id,"nerids","visible candidate belongs to the player's race")
			assert_true(offer.portrait.contains("/nerids/"),"candidate portrait belongs to the player's race folder")

func test_legacy_commander_remains_visible_and_can_be_dismissed() -> void:
	GameState.combat_state.commander={"name":"Сирена Вальтэра","race_id":"nerids","attack_bonus":6.0,"defense_bonus":4.0,"expenses_bonus":2.0}
	combat._normalize_state(); window.open()
	assert_eq(combat.get_commander().id,"nerids_marshal")
	assert_eq(window._art_screen._dismiss_button.text,"В РЕЗЕРВ")
	assert_false(window._art_screen._dismiss_button.disabled)
	window._art_screen._dismiss_button.pressed.emit()
	assert_true(combat.get_commander().is_empty())

func test_command_bonus_applies_to_embarked_army_without_adding_home_units() -> void:
	var troops: Dictionary = {"coast_guard":{"count":4,"level":1,"experience":0}}
	var base: int = combat.get_attack_power(troops)
	combat.hire_commander(window._commander_profile("nerids",0),0)
	assert_gt(combat.get_attack_power(troops),base)
	assert_lt(combat.get_attack_power(troops),combat.get_attack_power())

func test_owned_commander_returns_from_reserve_without_payment() -> void:
	var profile: Dictionary = window._commander_profile("nerids",0)
	profile.experience=91; profile.skills={"tactics":3}
	assert_true(combat.hire_commander(profile,0).ok)
	var money: float = GameState.player_state.money
	assert_true(combat.dismiss_commander(0).ok)
	assert_eq(combat.get_commander_reserve().size(),1)
	assert_true(SaveSystem.load_game())
	assert_true(combat.assign_reserved_commander(0,1).ok)
	assert_eq(GameState.player_state.money,money)
	assert_eq(combat.get_commander(1).experience,91)
	assert_eq(combat.get_commander(1).skills.tactics,3)
	assert_eq(combat.get_commander(1).portrait,profile.portrait)
	assert_eq(combat.get_commander_reserve().size(),0)

func test_full_reserve_allows_swap_but_blocks_destructive_dismissal() -> void:
	assert_true(combat.hire_commander(window._commander_profile("nerids",0),0).ok)
	for index in 10:
		var profile: Dictionary = window._commander_profile("nerids",1)
		profile.id="owned_"+str(index); profile.attack_bonus=1.0; profile.experience=index
		GameState.combat_state.commander_reserve.append(profile)
	var former: String = combat.get_commander().id
	var money: float = GameState.player_state.money
	assert_false(combat.dismiss_commander().ok)
	assert_eq(combat.get_commander().id,former)
	assert_true(combat.assign_reserved_commander(0,0).ok)
	assert_eq(combat.get_commander().id,"owned_0")
	assert_eq(combat.get_commander_reserve()[0].id,former)
	assert_eq(combat.get_commander_reserve().size(),10)
	assert_eq(GameState.player_state.money,money)
	assert_true(combat.buy_commander_reserve_slot().ok)
	assert_eq(combat.get_commander_reserve_capacity(),11)
	assert_eq(GameState.player_state.money,money-1000.0)
	assert_true(combat.dismiss_commander().ok)
	assert_eq(combat.get_commander_reserve().size(),11)

func test_reserve_interface_selects_owned_portrait_and_swaps() -> void:
	combat.hire_commander(window._commander_profile("nerids",0),0)
	combat.dismiss_commander(0)
	window.open()
	var screen: Control = window._art_screen
	screen._reserve_tab.pressed.emit()
	assert_eq(screen._reserve_tiles.size(),10)
	assert_true(screen._reserve_mode)
	assert_true(screen._candidate_cards[0].portrait.visible==false)
	screen._reserve_tiles[0].button.pressed.emit()
	assert_true(screen._hire.text.contains("БЕСПЛАТНО"))
	screen._hire.pressed.emit()
	assert_false(combat.get_commander().is_empty())
	assert_eq(combat.get_commander_reserve().size(),0)

func test_recruit_replacement_keeps_predecessor_and_reserve_is_home_only() -> void:
	combat.hire_commander(window._commander_profile("nerids",0),0)
	var replacement: Dictionary = window._commander_profile("nerids",1)
	assert_true(combat.hire_commander(replacement,0).ok)
	assert_eq(combat.get_commander_reserve().size(),1)
	assert_eq(combat.get_commander().id,replacement.id)
	GameState.ship_state.docked_port_id=""
	assert_false(combat.assign_reserved_commander(0,0).ok)
	assert_false(combat.buy_commander_reserve_slot().ok)
	assert_false(combat.dismiss_commander().ok)
