extends "res://tests/test_base.gd"

func test_outside_of_turn_is_lower_for_all_world_headings() -> void:
	for heading in [-PI, -PI * 0.5, 0.0, PI * 0.5]:
		for yaw_rate in [-1.0, 1.0]:
			var heel: float = preload("res://systems/rendering/ocean_surface.gd").outward_heel(yaw_rate)
			var basis := Basis.from_euler(Vector3(0, -heading - PI * 0.5, heel))
			var starboard_y: float = (basis * Vector3.RIGHT).y
			var port_y: float = (basis * Vector3.LEFT).y
			assert_true(port_y < starboard_y if yaw_rate > 0 else starboard_y < port_y, "outside rail is lower, independent of heading")
			assert_true(absf(heel) <= deg_to_rad(5.0), "turning heel stays gentle")
	assert_eq(preload("res://systems/rendering/ocean_surface.gd").outward_heel(0), 0.0)
