extends "res://tests/test_base.gd"

var wake: Node3D
var camera: Camera3D
var time:=0.0

func before_each() -> void:
	GameState.reset_to_defaults();GameState.settings_state.ship_wake_quality="high"
	time=0
	camera=Camera3D.new();add_child(camera)
	camera.position=Vector3(0,15,20);camera.look_at(Vector3(0,0,-8))
	wake=preload("res://systems/rendering/ship_wake.gd").new();add_child(wake)

func after_each() -> void:
	wake.free();camera.free();GameState.reset_to_defaults()

func sample(at: Vector2, enabled: bool = true) -> void:
	time+=0.1;wake.begin_frame(0.1,time,camera)
	wake.track("player",at,-PI/2,3.48,0.1,enabled);wake.finish_frame()

func test_world_anchored_trail_dissolves_after_stopping() -> void:
	for index in 20:sample(Vector2(0,-index*0.4))
	assert_gt(wake._foam.size(),0)
	assert_gt(wake._spray.size(),0)
	var anchor:Vector3=wake._foam[0].at
	sample(Vector2(0,-8))
	assert_eq(wake._foam[0].at,anchor,"old foam remains in world space")
	for index in 45:sample(Vector2(0,-8))
	assert_eq(wake._foam.size(),0)
	assert_eq(wake._spray.size(),0)
	assert_eq(wake._foam_mesh.multimesh.visible_instance_count,0)

func test_profiles_limit_particles_and_off_clears_immediately() -> void:
	for index in 120:sample(Vector2(sin(index*0.08)*4,-fmod(index*0.5,15)))
	assert_true(wake._foam.size()<=64)
	assert_true(wake._spray.size()<=20)
	GameState.settings_state.ship_wake_quality="low";wake.apply_settings()
	for index in 80:sample(Vector2(0,-fmod(index*0.5,15)))
	assert_true(wake._foam.size()<=28)
	assert_true(wake._spray.size()<=6)
	var ids:Array=[]
	for child in wake.get_children():ids.append(child.get_instance_id())
	GameState.settings_state.ship_wake_quality="off";wake.apply_settings()
	sample(Vector2(0,-1));sample(Vector2(0,-2))
	assert_eq(wake._foam.size(),0)
	assert_eq(wake._foam_mesh.multimesh.visible_instance_count,0)
	assert_eq(wake.get_child(0).get_instance_id(),ids[0],"quality changes reuse the same GPU pool")

func test_teleport_hidden_and_distant_ships_never_emit_a_burst() -> void:
	sample(Vector2.ZERO);sample(Vector2(0,-0.5),false)
	assert_eq(wake._foam.size(),0)
	sample(Vector2(0,-1));sample(Vector2(0,-1000))
	assert_eq(wake._foam.size(),0)
	sample(Vector2(0,1000));sample(Vector2(0,1001))
	assert_eq(wake._foam.size(),0)

func test_reverse_emits_behind_motion_instead_of_behind_the_bow_heading() -> void:
	sample(Vector2(0,-8));sample(Vector2(0,-7))
	assert_eq(wake._foam.size(),2)
	assert_true(float(wake._foam[0].at.z)<-7,"reverse wake is on the bow side behind actual motion")

func test_setting_migration_and_save_preserve_independent_water_quality() -> void:
	var settings=preload("res://systems/ui/game_settings.gd")
	assert_eq(str(settings.normalized({}).ship_wake_quality),"low")
	assert_eq(str(settings.normalized({"ship_wake_quality":"invalid"}).ship_wake_quality),"low")
	GameState.settings_state.ship_wake_quality="off";GameState.settings_state.water_quality="high"
	assert_true(SaveSystem.save_game());GameState.reset_to_defaults();assert_true(SaveSystem.load_game())
	assert_eq(str(GameState.settings_state.ship_wake_quality),"off")
	assert_eq(str(GameState.settings_state.water_quality),"high")
	SaveSystem.delete_save()
