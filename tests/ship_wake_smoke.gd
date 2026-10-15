extends Node

class SailingView extends "res://systems/rendering/approach_3d_view.gd":
	func _sync_fog(_position: Vector2) -> void: pass

var checks:=0
var failed:=0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failed+=1;push_error("SHIP WAKE: "+message)

func _ready() -> void:
	if OS.get_environment("SEA_TRADER_ISOLATED_TESTS")!="1":get_tree().quit(2);return
	GameState.reset_to_defaults()
	GameState.player_state.origin_race_id="humans"
	GameState.ship_state.docked_port_id=""
	GameState.settings_state.water_quality="high"
	GameState.settings_state.ship_wake_quality="high"
	var view:=SailingView.new();add_child(view);view.set_process(false)
	view._day_clock=100.0
	view._world_data={"islands":[],"ports":{}}
	view.apply_graphics_settings()
	view._camera.fov=58
	for frame in 180:
		var t:float=frame/30.0
		var at:=Vector2(sin(t*0.30)*5.0,-t*4.0)
		GameState.ship_state.position=at/0.04
		GameState.ship_state.heading=Vector2(cos(t*0.30)*1.5,-4.0).angle()
		view._process(1.0/30.0)
		view._camera.position=Vector3(at.x+7,7.5,at.y+11)
		view._camera.look_at(Vector3(at.x,0,at.y-1.0));view._camera.fov=58
		view._wake.finish_frame()
		await get_tree().process_frame
	check(view._wake._foam.size()>0,"real sailing renderer emits a wake")
	check(view._wake._spray.size()>0,"real sailing renderer emits bow spray")
	check(view._wake._foam_mesh.multimesh.visible_instance_count>0,"foam is submitted to the renderer")
	check(view._wake.get_child_count()==2,"all effects share two fixed GPU pools")
	if OS.get_environment("SEA_TRADER_UI_CAPTURE")=="1":
		await RenderingServer.frame_post_draw
		view._subviewport.get_texture().get_image().save_png("res://sailing_wake.png")
	GameState.settings_state.ship_wake_quality="off";view.apply_graphics_settings()
	check(view._wake._foam_mesh.multimesh.visible_instance_count==0,"graphics setting immediately hides existing wakes")
	check(str(GameState.settings_state.water_quality)=="high","wake toggle leaves water quality unchanged")
	GameState.settings_state.ship_wake_quality="low";view.apply_graphics_settings()
	GameState.ship_state.docked_port_id="home";view._process(0.1)
	check(view._wake._emitters.is_empty(),"docking clears emission history")
	print("SHIP WAKE checks=%d fail=%d renderer=%s"%[checks,failed,RenderingServer.get_current_rendering_method()])
	get_tree().quit(0 if failed==0 else 1)
