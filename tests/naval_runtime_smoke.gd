extends Node
var failures: int = 0
var checks: int = 0
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures+=1; push_error("NAVAL SMOKE: "+message)
func frames(count: int = 4) -> void:
	for index in count: await get_tree().process_frame
func snapshot(path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS")!="1": get_tree().quit(2); return
	SaveSystem.delete_save(); GameState.reset_to_defaults()
	GameState.player_state.origin_race_id="nerids"; GameState.player_state.origin_race_confirmed=true
	GameState.world_state.seed=42
	GameState.world_state.world_gen_version=str(int(GameData.read("res://data/world/world_gen_config.json").version))
	SaveSystem.save_game()
	var main: Node = load("res://scenes/game/main.tscn").instantiate(); add_child(main); await frames(8)
	check(main._world_ready,"whole scene initializes")
	var navy: Node = main.get_node("NavalCombatSystem")
	var military: Node = main.get_node("MilitaryTransportSystem")
	var hud: CanvasLayer = main.get_node("NavalBattleHUD")
	var combat: Node = main.get_node("CombatSystem")
	var window: CanvasLayer = main.get_node("GarrisonWindow")
	var home: String = str(main._port_system.get_all_port_ids()[0])
	GameState.world_state.home_port_id=home
	GameState.ship_state.docked_port_id=home
	main._ship.global_position=main._port_system.get_port_position(home)
	GameState.ship_state.position=main._ship.global_position
	GameState.player_state.money=50000
	GameState.combat_state.units={"coast_guard":{"count":18,"level":2,"experience":10},"crystal_mortar":{"count":3,"level":1,"experience":10},"wind_rider":{"count":4,"level":2,"experience":10}}
	window.open(); await frames()
	var screen: Control = window._art_screen
	var before: String = screen._groups[0].attack.text
	screen._hire.pressed.emit(); await frames()
	check(not combat.get_commander().is_empty(),"real hire button appoints first commander")
	check(screen._groups[0].attack.text!=before,"army attack visibly changes after appointment")
	screen._role_buttons[1].pressed.emit(); await frames()
	check(screen.slot==1 and screen.role==1,"deputy tab selects the deputy appointment slot")
	screen._hire.pressed.emit(); await frames()
	check(not combat.get_commander(1).is_empty(),"second command slot is active")
	check(screen._groups[0].attack.text.contains("%+.0f%%" % float(combat.get_commander_bonuses().attack)),"army displays actual aggregate bonus from both random officers")
	check(screen._hero_emblem.texture==GameData.get_faction_emblem("nerids"),"canonical own-race emblem")
	if OS.get_environment("SEA_TRADER_NAVAL_SCREENSHOT")!="":
		await snapshot(OS.get_environment("SEA_TRADER_NAVAL_SCREENSHOT")+"-commanders.png")
	window._close()
	var result: Dictionary = main._fleet_system.complete_ship_from_shipyard("war_nerids_1","Тестовый страж")
	check(result.ok,"own race warship enters existing shipyard fleet: "+str(result.get("message","")))
	if not result.ok: get_tree().quit(1); return
	var id: String = str(result.get("instance_id",""))
	check(navy.hire_commander(id).ok,"naval commander can be hired")
	check(navy.install_gun(id,0,"rune").ok,"naval gun installed")
	var fleet: Node = main.get_node("FleetWindow"); fleet._is_open=true; fleet._refresh(); await frames()
	check(fleet._list.get_child_count()>0,"fleet renders naval controls")
	fleet._is_open=false
	var length: float = military._length(navy.ship_by_id(id))
	var water: Vector2 = military._spawn_position(main._ship.global_position,length*8,[])
	check(water.is_finite(),"fixture finds navigable sea")
	main._ship.global_position=water; GameState.ship_state.position=water; GameState.ship_state.docked_port_id=""
	var encounter: Dictionary = navy.create_training_encounter()
	check(bool(encounter.get("ok",false)),"debug training encounter creates a guaranteed nearby enemy")
	check(not navy.nearby_enemies().is_empty(),"training encounter exposes the normal Z battle prompt")
	var ship: Dictionary = navy.ship_by_id(id)
	navy.set_process(false); military.set_process(false)
	await frames()
	check(hud._training_button != null and hud._training_button.visible,"debug build exposes the training button at sea")
	check(hud._badge.visible,"enemy within five hulls shows Z indicator")
	var key:=InputEventKey.new(); key.pressed=true; key.physical_keycode=KEY_Z
	hud._unhandled_key_input(key); await frames()
	check(navy.active(),"physical Z starts actual battle directly")
	check(hud._truce.get_theme_stylebox("normal") is StyleBoxTexture,"tactical actions use the approved brass art button")
	var approach: Node=main.get_node("Approach3DView")
	check(hud.tactical_view_open() and approach._battle_camera_requested(),"opening battle enables tactical camera framing")
	hud._collapse_panel(); hud._process(.3); approach._process(.1)
	check(navy.active(),"closing the panel keeps combat running")
	check(not hud.tactical_view_open() and not approach._battle_camera_requested(),"closing the panel releases tactical camera framing")
	var orbit_before: float=approach._camera_orbit_yaw
	var right_press:=InputEventMouseButton.new(); right_press.button_index=MOUSE_BUTTON_RIGHT; right_press.pressed=true
	approach._unhandled_input(right_press)
	var orbit_motion:=InputEventMouseMotion.new(); orbit_motion.relative=Vector2(30,0)
	approach._unhandled_input(orbit_motion)
	check(not is_equal_approx(approach._camera_orbit_yaw,orbit_before),"collapsed battle restores right-mouse camera orbit")
	var sailing_camera: Camera2D=get_viewport().get_camera_2d()
	var zoom_before: float=sailing_camera.zoom.x
	main._zoom_ship_camera(.15)
	check(sailing_camera.zoom.x>zoom_before,"collapsed battle restores sailing camera zoom")
	var reopen:=InputEventKey.new(); reopen.pressed=true; reopen.physical_keycode=KEY_Z
	hud._unhandled_key_input(reopen); hud._process(.3); approach._process(.1)
	check(hud.tactical_view_open() and approach._battle_camera_requested(),"Z restores panel and tactical camera framing")
	check(not approach._orbit_dragging,"tactical camera stops manual orbit capture")
	check(not ship.escort_enabled,"battle releases escort")
	check(str(ship.naval_order.get("kind",""))=="hold","battle starts with ships holding position")
	var player_hull: float = float(GameState.ship_state.get("hull",100))
	var battle_military: Node = navy._military
	navy._military=null
	GameState.ship_state.hull=0
	navy._step_battle(.05)
	check(navy.active(),"merchant flagship hull does not cause instant naval defeat")
	GameState.ship_state.hull=player_hull
	check(int(GameState.combat_state.naval_battle.shots)==0,"own guns do not fire without an attack order")
	var target_id: String = str(GameState.combat_state.naval_battle.enemy_ids[0])
	navy.issue_order(id,navy.get_enemy_snapshots()[0].position,target_id)
	var enemy_position: Vector2=navy.vector(navy.get_enemy_snapshots()[0].position)
	ship.escort_state.heading=navy.position(ship).direction_to(enemy_position)
	navy._step_battle(.05)
	navy._military=battle_military
	check(int(GameState.combat_state.naval_battle.shots)>0,"attack order fires on its selected enemy")
	var vfx: Node = main.get_node("NavalCombatVFX")
	EventBus.naval_shot_visual.emit(water, water + Vector2(180, 0), true, "rune", Vector2.UP, id)
	check(not vfx.get("_shots").is_empty(),"3D naval VFX creates a visible projectile")
	ship.hull=navy.hull_max(ship)*.5
	vfx._process(.05)
	var damage_root: Node3D=vfx._damage_effects.get(id) as Node3D
	check(damage_root!=null and int(damage_root.get_meta("damage_level",0))==1,"50 percent damage creates the first 2D fire")
	check(damage_root.find_child("Fire",true,false) is AnimatedSprite3D,"damage fire is a camera-facing 2D animation")
	check(damage_root.get_child_count()==2,"half-damaged ship has two separate fire sources")
	ship.hull=navy.hull_max(ship)*.3
	vfx._process(.05)
	damage_root=vfx._damage_effects.get(id) as Node3D
	check(damage_root!=null and int(damage_root.get_meta("damage_level",0))==2,"70 percent damage enlarges fire and adds smoke")
	check(damage_root.find_child("Smoke",true,false) is AnimatedSprite3D,"critical smoke is a camera-facing 2D animation")
	check(damage_root.get_child_count()==4,"critical damage adds a third large fire source")
	for viewport_size in [Vector2i(1280,720),Vector2i(1080,720),Vector2i(1080,1920)]:
		get_tree().root.size=viewport_size
		for i in 40: hud._process(.05)
		await frames()
		check(is_equal_approx(hud._panel.size.x,clampf(get_viewport().get_visible_rect().size.x*.25,290,370)),"battle panel stays compact at "+str(viewport_size))
		var treasury: Control = main.get_node("WindowCoordinator/TopResourceBar")
		var coordinator: Node=main.get_node("WindowCoordinator")
		var viewport: Vector2=get_viewport().get_visible_rect().size
		check(treasury.position.x+treasury.size.x*treasury.scale.x<=viewport.x+1,"treasury stays inside the full-width top menu")
		check(is_equal_approx(coordinator.get_node("TopMenuBackdrop").size.x,viewport.x),"battle does not cut a quarter out of the top menu")
		check(hud._panel.position.y>=coordinator._top_height,"battle panel begins below all top-menu rows")
		check(absf(hud._panel.position.y+hud._panel.size.y-viewport.y)<1,"battle panel reaches the bottom at %s: panel %s, viewport %s" % [str(viewport_size),str(hud._panel.get_global_rect()),str(viewport)])
	get_tree().root.size=Vector2i(1280,720); await frames()
	var drag_origin: Vector2=hud._map.global_position+hud._map.size*.5
	var drag_start: Vector2=hud._map.center
	var right:=InputEventMouseButton.new(); right.button_index=MOUSE_BUTTON_RIGHT; right.pressed=true; right.position=drag_origin; right.button_mask=MOUSE_BUTTON_MASK_RIGHT
	get_viewport().push_input(right,true); await frames(2)
	var drag:=InputEventMouseMotion.new(); drag.position=drag_origin+Vector2(30,20); drag.relative=Vector2(30,20); drag.button_mask=MOUSE_BUTTON_MASK_RIGHT
	get_viewport().push_input(drag,true); await frames(2)
	check(hud._map.center.distance_to(drag_start)>1,"right mouse input reaches the map and pans it")
	check(not approach._orbit_dragging,"map dragging never captures the sailing camera")
	right.pressed=false; right.position=drag.position; right.button_mask=0; get_viewport().push_input(right,true)
	check(not hud._map._dragging,"release ends the map gesture")
	hud._map.center=water
	var mouse:=InputEventMouseButton.new(); mouse.pressed=true; mouse.button_index=MOUSE_BUTTON_LEFT; mouse.position=hud._map.point(navy.position(ship))
	hud._map._gui_input(mouse)
	check(hud._map.selected==id,"tactical map selects own ship")
	var destination: Vector2 = water+Vector2(700,700)
	mouse.position=hud._map.point(destination); hud._map._gui_input(mouse)
	check(ship.naval_order.kind=="move","map click issues movement order")
	var start: Vector2 = navy.position(ship)
	# Larger hulls need several seconds to turn and accelerate from rest.
	for i in 100: military._time+=.05; military._step_ship(ship,0,.05)
	check(navy.position(ship).distance_to(start)>5,"ship actually follows tactical order")
	if OS.get_environment("SEA_TRADER_NAVAL_SCREENSHOT")!="": await snapshot(OS.get_environment("SEA_TRADER_NAVAL_SCREENSHOT")+"-battle.png")
	hud._truce.pressed.emit(); check(bool(GameState.combat_state.naval_battle.truce_pending),"truce button requests mutual consent")
	navy.respond_truce(true); await frames()
	check(not navy.active() and ship.escort_enabled,"mutual truce restores escort")
	print("NAVAL SMOKE checks=%d fail=%d" % [checks,failures])
	main.queue_free(); await frames(); SaveSystem.delete_save()
	get_tree().quit(0 if failures==0 else 1)
