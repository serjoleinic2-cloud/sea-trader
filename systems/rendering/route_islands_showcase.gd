extends Node3D

func _ready() -> void:
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(260, 200)
	ocean.mesh = plane
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("286577")
	water.roughness = 0.3
	ocean.material_override = water
	add_child(ocean)
	var low_poly = load("res://systems/rendering/low_poly_island.gd")
	for index in range(3):
		var outline: Array = []
		var radius := 25.0 + float(index % 2) * 9.0
		for segment in 24:
			var angle := TAU * float(segment) / 24.0
			var coast := 1.0 + 0.08 * sin(angle * 3.0 + float(index))
			outline.append([cos(angle) * radius * coast, sin(angle) * radius * coast])
		var model := Node3D.new()
		model.position.x = (index - 1) * 65.0
		add_child(model)
		low_poly.build(model, outline, "aery" if index == 1 else "humans", false)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.3
	add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("749da9")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("bacad1")
	world.environment.ambient_light_energy = 0.45
	add_child(world)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(65, 65, 140)
	camera.look_at(Vector3(0, 5, 0))
	camera.current = true
	for frame in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	if args.has("--capture"):
		get_viewport().get_texture().get_image().save_png(args[args.find("--capture") + 1])
		get_tree().quit()
