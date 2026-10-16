extends Node

var failures:=0
var checks:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("OUTFITTING: "+message)
func frames() -> void:
	for frame in 10:await get_tree().process_frame
func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS")!="1":get_tree().quit(2);return
	GameState.reset_to_defaults();GameState.world_state.seed=42
	GameState.player_state.origin_race_id="humans";GameState.player_state.origin_race_confirmed=true
	SaveSystem.save_game()
	var main:Node=preload("res://scenes/game/main.tscn").instantiate();add_child(main)
	await frames();main._career_system.set_process(false);get_tree().paused=false
	var home:String=str(main._navigation_world.ports.keys()[0])
	GameState.world_state.home_port_id=home
	GameState.ship_state.docked_port_id=home
	GameState.player_state.money=200000.0
	GameState.fleet_state=[{"instance_id":"outfit_war","ship_type_id":"war_humans_1","name":"Тест оснащения","current_port_id":home,"crew":[],"hull":280.0,"guns":[{},{}],"commander":{}}]
	var fleet:Node=main.get_node("FleetWindow")
	fleet._is_open=true;fleet._selected_ship_id="outfit_war";fleet._refresh()
	await frames()
	var view:Node=fleet._garage._outfitting
	check(view.is_visible_in_tree(),"selected owned ship opens unified outfitting")
	check(not fleet._garage._carousel.visible,"owned vessels use compact selector instead of tall carousel")
	check(fleet._panel.get_global_rect().end.y<=get_viewport().get_visible_rect().end.y+1,"fleet workspace fits viewport height")
	check(view._bars.get_global_rect().end.y<=get_viewport().get_visible_rect().end.y-20,"all ship indicators remain inside viewport")
	check(view._preview.size.y>=190,"ship preview retains useful size on compact screen")
	check(view._crew.get_parent().get_parent().position.x < view._preview.get_parent().position.x,"crew column is left of ship")
	check(view._right.get_parent().get_parent().position.x > view._preview.get_parent().position.x,"boost and weapons column is right of ship")
	check(view.find_child("BoostSlot_3",true,false)!=null,"four boost slots exist")
	var bow_gun_slot: Button = view.find_child("GunSlot_0",true,false) as Button
	check(bow_gun_slot!=null,"bow gun slot exists on military ship")
	if bow_gun_slot!=null: check(is_equal_approx(bow_gun_slot.custom_minimum_size.x,bow_gun_slot.custom_minimum_size.y),"gun art uses a square framed slot")
	if bow_gun_slot!=null: check(bow_gun_slot.find_children("*","TextureRect",true,false).is_empty(),"empty gun slot has no weapon placeholder art")
	check(view._bars.find_child("Stat_speed",true,false) is ProgressBar,"statistics use numeric horizontal bars")
	view._crew.find_child("CrewSlot_crew_0",true,false).pressed.emit()
	await frames()
	check(view._picker.visible,"crew cell opens role-filtered recruitment")
	var hiring:Node=get_tree().get_first_node_in_group("hiring_system")
	var candidates:Array=hiring.get_candidates_for_role("captain")
	var hire:Button=null
	for button in view._choices.find_children("*","Button",true,false):
		if button.text.begins_with("Нанять"):hire=button;break
	check(hire!=null,"filtered candidate has real hire action")
	if hire==null:get_tree().quit(1);return
	GameState.player_state.money=0.0
	hire.pressed.emit();await frames()
	check(view._picker.visible and view._picker_notice.visible,"failed hire explains the reason inside the open picker")
	check(GameState.fleet_state[0].crew.is_empty(),"failed hire leaves the crew unchanged")
	GameState.player_state.money=200000.0
	if hire!=null:hire.pressed.emit()
	await frames()
	check(GameState.fleet_state[0].crew.size()==1,"hiring fills the selected vessel")
	check(not view._picker.visible,"successful assignment returns to ship and indicators")
	check(not view._comparison.is_empty(),"before/after values are retained")
	check(str(GameState.fleet_state[0].commander.name)==str(candidates[0].name),"military captain is the officer who was selected")
	view._right.find_child("BoostSlot_0",true,false).pressed.emit();await frames()
	var buy:Button=null
	for button in view._choices.find_children("*","Button",true,false):
		if button.text.begins_with("Купить"):buy=button;break
	check(buy!=null,"boost cell opens matching scroll purchase")
	if buy!=null:buy.pressed.emit()
	await frames()
	check(not GameState.fleet_state[0].boost_slots[0].is_empty(),"scroll purchase really fills selected boost slot")
	check(view._timer_labels[0].text!="Свободно","boost expiry is visible below slot")
	# Older local saves can contain a partial gun entry; opening the picker must ignore it safely.
	GameState.combat_state.naval_arsenal = [{}]
	view._right.find_child("GunSlot_0",true,false).pressed.emit();await frames()
	check(view._picker.visible,"gun picker opens safely with a legacy arsenal entry missing its kind")
	var gun_frames: Array = view._choices.find_children("*", "PanelContainer", true, false).filter(func(node): return node.custom_minimum_size==Vector2(88,88))
	check(not gun_frames.is_empty(),"arsenal and shop art use larger square brass frames")
	var gun_choices: Array = view._choices.find_children("*", "Button", true, false).filter(func(button): return button.has_meta("gun_kind"))
	check(gun_choices.all(func(button): return view._navy().gun_install_status(GameState.fleet_state[0],0,str(button.get_meta("gun_kind"))).ok),"gun picker offers only weapons compatible with the selected mount")
	buy=null
	for button in view._choices.find_children("*","Button",true,false):
		if button.text.begins_with("Купить и установить") and not button.disabled:buy=button;break
	check(buy!=null,"gun cell offers compatible guns directly")
	if buy!=null:buy.pressed.emit()
	await frames()
	check(not GameState.fleet_state[0].guns[0].is_empty(),"gun purchase installs into selected mount")
	check(view._bars.find_child("Stat_damage",true,false).value>0,"installed gun changes actual displayed salvo damage")
	if OS.get_environment("SEA_TRADER_UI_CAPTURE")=="1":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://ship_outfitting.png")
	print("OUTFITTING checks=%d fail=%d"%[checks,failures])
	get_tree().quit(0 if failures==0 else 1)
